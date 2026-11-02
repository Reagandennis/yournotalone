/** Bindings, vars and secrets. See wrangler.toml and README.md. */
export interface Env {
  // vars
  SUPABASE_URL: string;
  PUBLIC_BASE_URL: string;
  R2_ACCOUNT_ID: string;
  PRIVATE_BUCKET: string;
  /** RevenueCat's internal entitlement id (entl…). Preferred over the lookup key. */
  PRO_ENTITLEMENT_ID?: string;
  /** Entitlement identifier as the app knows it ("Techgetafrica Pro"). */
  PRO_ENTITLEMENT_LOOKUP_KEY?: string;

  // secrets
  R2_ACCESS_KEY_ID: string;
  R2_SECRET_ACCESS_KEY: string;
  REVENUECAT_SECRET_KEY: string;
  REVENUECAT_PROJECT_ID: string;
  SENTRY_DSN?: string;

  // bindings (optional: the code skips rate limiting if absent)
  RATE_LIMITER?: RateLimit;
}

/** Hono context variables set by the auth middleware. */
export interface Vars {
  user: AuthUser;
}

export interface AuthUser {
  id: string;
  premiumComp: boolean;
}

export type AppEnv = { Bindings: Env; Variables: Vars };
