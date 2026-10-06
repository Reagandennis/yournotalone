// Paystack, shared by paystack-payment and paystack-webhook.
//
// A checkout is one Paystack transaction opened for one therapy session
// (public.paystack_checkouts, migration 0021). It counts as paying for the
// session only once Paystack itself says the transaction succeeded for the
// amount and currency the checkout was opened with.

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
  user_id: string;
  amount: number;
  currency: string;
};

export type SettleResult = 'paid' | 'not_paid' | 'refund_needed';

/// Attaches a successful transaction to its session.
///
/// `transaction` is Paystack's record (from verify, or a webhook whose
/// signature has been checked). Returns `paid` when the session is now paid
/// with this checkout, `not_paid` when the transaction hasn't succeeded, and
/// `refund_needed` when it succeeded but the session can't take it — the
/// care team has then been emailed to refund it.
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

  const ref = `paystack:${checkout.reference}`;
  const paidAt = typeof transaction.paid_at === 'string'
    ? transaction.paid_at
    : new Date().toISOString();

  await admin.from('paystack_checkouts')
    .update({ paid_at: paidAt })
    .eq('reference', checkout.reference)
    .is('paid_at', null);

  if (checkout.request_id) {
    const { data: updated, error } = await admin
      .from('therapy_requests')
      .update({ payment_status: 'paid', payment_ref: ref, paid_at: new Date().toISOString() })
      .eq('id', checkout.request_id)
      .eq('user_id', checkout.user_id)
      .eq('payment_status', 'unpaid')
      .in('status', ['awaiting_payment', 'pending', 'confirmed'])
      .select('id');
    // 23505: payment_ref is unique, so this checkout already paid for it.
    if (error && error.code !== '23505') throw error;
    if (updated && updated.length > 0) return 'paid';

    const { data: session, error: lookupError } = await admin
      .from('therapy_requests')
      .select('payment_ref')
      .eq('id', checkout.request_id)
      .maybeSingle();
    if (lookupError) throw lookupError;
    // Already attached (the webhook and the app raced each other).
    if (session?.payment_ref === ref) return 'paid';
  }

  // The session was cancelled, or was already paid some other way: the
  // money isn't paying for anything.
  const { error: notifyError } = await admin.rpc('paystack_payment_needs_refund', {
    p_reference: checkout.reference,
  });
  if (notifyError) console.error('paystack: refund-needed email failed', notifyError);
  return 'refund_needed';
}
