import { createRemoteJWKSet, jwtVerify, errors, type JWTPayload } from 'jose';
import type { MiddlewareHandler } from 'hono';
import type { AppEnv } from './env';
import { jsonError } from './http';

// One JWKS fetcher per Supabase URL, kept for the life of the isolate. jose
// caches the keys (10 min, design §5) and refetches when it sees an unknown kid.
const jwksBySupabase = new Map<string, ReturnType<typeof createRemoteJWKSet>>();

function jwksFor(supabaseUrl: string) {
  let jwks = jwksBySupabase.get(supabaseUrl);
  if (!jwks) {
    jwks = createRemoteJWKSet(new URL(`${supabaseUrl}/auth/v1/.well-known/jwks.json`), {
      cacheMaxAge: 10 * 60 * 1000,
      cooldownDuration: 30 * 1000,
      timeoutDuration: 5000,
    });
    jwksBySupabase.set(supabaseUrl, jwks);
  }
  return jwks;
}

/** Test hook: forget cached JWKS fetchers. */
export function resetAuthState(): void {
  jwksBySupabase.clear();
}

interface SupabaseClaims extends JWTPayload {
  app_metadata?: { premium_comp?: unknown; content_admin?: unknown };
  user_metadata?: { goals?: unknown };
}

/** Requires `Authorization: Bearer <Supabase access token>`; sets c.var.user. */
export const requireAuth: MiddlewareHandler<AppEnv> = async (c, next) => {
  const header = c.req.header('Authorization') ?? '';
  const match = /^Bearer\s+(\S+)$/i.exec(header);
  if (!match) return jsonError(c, 401, 'missing_token');

  const supabaseUrl = c.env.SUPABASE_URL.replace(/\/+$/, '');
  let payload: SupabaseClaims;
  try {
    ({ payload } = await jwtVerify<SupabaseClaims>(match[1], jwksFor(supabaseUrl), {
      issuer: `${supabaseUrl}/auth/v1`,
      audience: 'authenticated',
      // Supabase signs with asymmetric keys; never accept HS* or "none".
      algorithms: ['ES256', 'RS256', 'EdDSA'],
      requiredClaims: ['exp', 'sub'],
    }));
  } catch (error) {
    if (error instanceof errors.JWTExpired) return jsonError(c, 401, 'token_expired');
    if (error instanceof errors.JOSEError) return jsonError(c, 401, 'invalid_token');
    // Anything else (JWKS unreachable, etc.) is still a refusal, never a pass.
    return jsonError(c, 401, 'invalid_token');
  }
  if (typeof payload.sub !== 'string' || payload.sub.length === 0) {
    return jsonError(c, 401, 'invalid_token');
  }

  const goals = payload.user_metadata?.goals;
  c.set('user', {
    id: payload.sub,
    premiumComp: payload.app_metadata?.premium_comp === true,
    contentAdmin: payload.app_metadata?.content_admin === true,
    goals: Array.isArray(goals) ? goals.filter((g): g is string => typeof g === 'string').slice(0, 20) : [],
    token: match[1],
  });

  // Per-user rate limit (design §5). Optional binding; see wrangler.toml.
  if (c.env.RATE_LIMITER) {
    const { success } = await c.env.RATE_LIMITER.limit({ key: payload.sub });
    if (!success) return jsonError(c, 429, 'rate_limited');
  }

  await next();
};
