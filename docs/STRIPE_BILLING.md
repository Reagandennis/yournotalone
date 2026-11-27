# Company billing (Stripe)

MindPillars for Work companies (migration `0040_organizations.sql`) pay per seat
through Stripe. Two Edge Functions do it:

- **`org-billing`** (JWT on) — called by the HR portal at
  `https://sso.mindpillars.app/portal` with `{action, org_id, …}`: `checkout`
  (Stripe Checkout for a subscription, returns `{url}`), `portal` (Stripe billing
  portal, `{url}`) and `seats` (`{seats}`, returns the `org_overview`). Only the
  company's HR admins (or the care team) can call it. Until `STRIPE_SECRET_KEY` is set
  it answers `503 {error: 'billing_not_configured'}` and companies run on their trial,
  or on a contract set in the admin page.
- **`stripe-webhook`** (JWT off) — Stripe tells it about subscriptions; it checks the
  signature and updates the company through `org_billing_apply`.

Price: one line item, `pepm_minor` per seat per month, or for yearly billing
`round(pepm_minor × 12 × (1 − annual_discount))` per seat per year, in USD, quantity =
seats. A trial more than 48 hours from its end continues in Stripe, so the card is
first charged when the 14 days are up.

Code: `supabase/functions/org-billing`, `supabase/functions/stripe-webhook`,
`supabase/functions/_shared/stripe.ts` (tests: `deno test --allow-env
supabase/functions/_shared/stripe_test.ts`).

## Setting it up

1. Create the Stripe account (business details, bank account for payouts). Do the steps
   below in **test mode** first, then again in live mode.
2. *Settings → Billing → Customer portal*: turn the portal on; allow updating payment
   methods, viewing invoices and cancelling. Leave "change quantity" **off** — seats are
   changed in the HR portal so the joined count is checked.
3. *Developers → Webhooks → Add endpoint*:
   `https://<project-ref>.supabase.co/functions/v1/stripe-webhook`
   with the events
   `checkout.session.completed`, `customer.subscription.created`,
   `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.paid`,
   `invoice.payment_failed`. Copy its signing secret (`whsec_…`).
4. Set the secrets (API key from *Developers → API keys*):

   ```sh
   supabase secrets set STRIPE_SECRET_KEY=sk_test_... STRIPE_WEBHOOK_SECRET=whsec_...
   ```

5. Deploy (the webhook must not require a Supabase JWT — Stripe doesn't send one):

   ```sh
   supabase functions deploy org-billing
   supabase functions deploy stripe-webhook --no-verify-jwt
   ```

6. Test: start a company on the site, *Billing → Subscribe*, pay with `4242 4242 4242
   4242`; the admin page should show it billing-linked and the status follow Stripe
   (*Developers → Webhooks → the endpoint* shows each delivery).

Status mapping (`org_billing_apply`): `trialing` → trial, `active` → active,
`past_due`/`unpaid` → past_due, `paused` → paused, `canceled`/`incomplete_expired` →
ended (premium goes; members keep their accounts). Events about a subscription the
company has since replaced are ignored.
