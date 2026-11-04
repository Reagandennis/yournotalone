/** Bindings, vars and secrets. See wrangler.toml and README.md. */
export interface Env {
  // vars
  SUPABASE_URL: string;
  /** The project's publishable (anon) key: public, sent as `apikey` with the user's JWT. */
  SUPABASE_ANON_KEY: string;
  PUBLIC_BASE_URL: string;
  R2_ACCOUNT_ID: string;
  /** The one R2 bucket; premium media is under `${KEY_PREFIX}private/`. */
  BUCKET: string;
  /** '' for production, 'staging/' for staging. Catalogue keys are relative to it. */
  KEY_PREFIX: string;
  /** RevenueCat's internal entitlement id (entl…). Preferred over the lookup key. */
  PRO_ENTITLEMENT_ID?: string;
  /** Entitlement identifier as the app knows it ("Techgetafrica Pro"). */
  PRO_ENTITLEMENT_LOOKUP_KEY?: string;
  /** `owner/repo` the admin page saves content to. */
  GITHUB_REPO?: string;

  // secrets
  R2_ACCESS_KEY_ID: string;
  R2_SECRET_ACCESS_KEY: string;
  REVENUECAT_SECRET_KEY: string;
  REVENUECAT_PROJECT_ID: string;
  SENTRY_DSN?: string;
  /** Only the daily cron uses it, for the content_popularity RPC. */
  SUPABASE_SERVICE_ROLE_KEY?: string;
  /**
   * Fine-grained GitHub token for the admin page: this repository only,
   * Contents and Actions read & write. Without it the admin page is off.
   */
  ADMIN_GITHUB_TOKEN?: string;

  // bindings (optional: the code skips rate limiting if absent)
  RATE_LIMITER?: RateLimit;
  /** The `yournotalone` bucket, read-write; the cron writes stats/ into it. */
  CONTENT_BUCKET?: R2Bucket;
}

/** Hono context variables set by the auth middleware. */
export interface Vars {
  user: AuthUser;
}

export interface AuthUser {
  id: string;
  premiumComp: boolean;
  /** `app_metadata.content_admin`: may use the admin page. Only the service role can set it. */
  contentAdmin: boolean;
  /** `user_metadata.goals`: the needs picked at onboarding or in Settings. */
  goals: string[];
  /** The verified access token, for Supabase reads under the user's own RLS. Never log it. */
  token: string;
}

export type AppEnv = { Bindings: Env; Variables: Vars };
