// Paystack, shared by paystack-payment and paystack-webhook.
//
// A checkout is one Paystack transaction opened for one therapy session
// (public.paystack_checkouts, migration 0021). It counts as paying for the
// session only once Paystack itself says the transaction succeeded for the
// amount and currency the checkout was opened with, and only while the
// money is still with us: a checkout Paystack has refunded (refunded_at,
// migration 0036, or a session whose refunded_payment_ref names it) never
// pays for anything again, even if Paystack's verify still says 'success'
// (it does after a partial refund, and can for a while after a full one).

import type { SupabaseClient } from 'jsr:@supabase/supabase-js@2';

export const PAYSTACK_SECRET_KEY = Deno.env.get('PAYSTACK_SECRET_KEY');

const PAYSTACK_API = 'https://api.paystack.co';

// deno-lint-ignore no-explicit-any
export type Item = Record<string, any>;

export class PaystackError extends Error {
  constructor(readonly status: number, body: string) {
    super(`Paystack ${status}: ${body}`);
  }
}

export async function paystack(path: string, init: RequestInit = {}): Promise<Item> {
  const response = await fetch(`${PAYSTACK_API}${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
  });
  const text = await response.text();
  if (!response.ok) throw new PaystackError(response.status, text);
  const body = JSON.parse(text);
  if (body?.status !== true) throw new PaystackError(response.status, text);
  return body.data ?? {};
}

/// Paystack's own record of a transaction, or null if it has none.
export async function verifyTransaction(reference: string): Promise<Item | null> {
  try {
    return await paystack(`/transaction/verify/${encodeURIComponent(reference)}`);
  } catch (error) {
    // An opened checkout nobody paid on can come back as not found.
    if (error instanceof PaystackError && (error.status === 400 || error.status === 404)) {
      return null;
    }
    throw error;
  }
}

export type Checkout = {
  reference: string;
  request_id: string | null;
  // Null once the client's account is deleted (0035).
  user_id: string | null;
  amount: number;
  currency: string;
  created_at?: string;
  refunded_at?: string | null;
};

/// Transaction statuses that mean the customer is still paying: an M-Pesa
/// prompt waiting on their phone ('ongoing' — Paystack is waiting on the
/// customer, e.g. a PIN, OTP or STK push), or a charge Paystack has taken
/// but not finished ('pending', 'processing', 'queued'). Not 'abandoned'
/// (opened, never paid on — safe to start again), 'failed', 'reversed' or
/// 'success'.
export const IN_PROGRESS_STATUSES = ['ongoing', 'pending', 'processing', 'queued'];

/// Keeps the country of the card a checkout was paid with
/// (paystack_checkouts.card_country, migration 0036), so a price picked for
/// a country the client doesn't pay from can be spotted. Best-effort: a
/// failure is logged and never undoes or fails the payment. Mobile money
/// has no card country, so nothing is recorded for it.
export async function recordCardCountry(
  admin: SupabaseClient,
  reference: string,
  transaction: Item,
): Promise<void> {
  const country = transaction?.authorization?.country_code;
  if (typeof country !== 'string' || !/^[A-Za-z]{2}$/.test(country)) return;
  try {
    const { error } = await admin.rpc('paystack_record_card_country', {
      p_reference: reference,
      p_card_country: country.toUpperCase(),
    });
    if (error) console.error('paystack: card country not recorded', reference, error);
  } catch (error) {
    console.error('paystack: card country not recorded', reference, error);
  }
}

export type SettleResult = 'paid' | 'not_paid' | 'refund_needed';

/// Attaches a successful transaction to its session.
///
/// `transaction` is Paystack's record (from verify, or a webhook whose
/// signature has been checked). Returns `paid` when the session is now paid
/// with this checkout, `not_paid` when the transaction hasn't succeeded or
/// has been refunded (the checkout's refunded_at is set, or a session's
/// refunded_payment_ref names it — both read fresh, under the checkout's
/// lock, by paystack_settle_checkout), and `refund_needed` when it
/// succeeded but the session can't take it — the care team has then been
/// emailed to refund it.
export async function settleCheckout(
  admin: SupabaseClient,
  checkout: Checkout,
  transaction: Item,
): Promise<SettleResult> {
  if (transaction.status !== 'success') return 'not_paid';
  if (
    Number(transaction.amount) !== checkout.amount ||
    String(transaction.currency).toUpperCase() !== checkout.currency.toUpperCase()
  ) {
    console.error('paystack: amount mismatch', checkout.reference, transaction.amount,
      transaction.currency);
    return 'not_paid';
  }

  const paidAt = typeof transaction.paid_at === 'string'
    ? transaction.paid_at
    : new Date().toISOString();

  // Refunded already (the checkout's refunded_at, or a session's
  // refunded_payment_ref): the money went back, so it pays for nothing —
  // and there's nothing for the care team to refund either. Checked and
  // attached in one transaction, under a lock on the checkout row that a
  // refund takes too (migration 0038), so a refund can't land between the
  // check and the attach.
  const { data: settled, error: settleError } = await admin.rpc('paystack_settle_checkout', {
    p_reference: checkout.reference,
    p_paid_at: paidAt,
  });
  if (settleError) throw settleError;
  if (settled === 'paid' || settled === 'not_paid') return settled;

  // The session was cancelled, or was already paid some other way: the
  // money isn't paying for anything.
  const { error: notifyError } = await admin.rpc('paystack_payment_needs_refund', {
    p_reference: checkout.reference,
  });
  if (notifyError) console.error('paystack: refund-needed email failed', notifyError);
  return 'refund_needed';
}

/// What Paystack has refunded on a transaction so far, in its minor unit:
/// the processed refunds Paystack lists for it, each counted once however
/// often its webhook comes. Throws when Paystack can't be asked.
export async function refundedSoFar(transactionId: unknown): Promise<number> {
  if (transactionId === undefined || transactionId === null || transactionId === '') return 0;
  const refunds = await paystack(
    `/refund?transaction=${encodeURIComponent(String(transactionId))}&perPage=100`,
  );
  const list: Item[] = Array.isArray(refunds) ? refunds : [];
  return list
    .filter((r) => String(r?.status ?? '').toLowerCase() === 'processed')
    .reduce((sum, r) => sum + (Number(r?.amount) || 0), 0);
}
