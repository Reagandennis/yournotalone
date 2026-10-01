// Talking to Apple's Sign in with Apple REST API on the app's behalf.
//
// Every call needs a client secret: a short-lived ES256 JWT signed with a
// Sign in with Apple key (.p8) from Certificates, IDs & Profiles → Keys.
// Shared by apple-token (swaps an authorization code for a refresh token)
// and delete-account (revokes that token).
//
// Secrets: APPLE_TEAM_ID      J564F672ZL
//          APPLE_KEY_ID       the 10-character ID of the .p8 key
//          APPLE_PRIVATE_KEY  the .p8 file's contents, BEGIN/END lines included
//          APPLE_CLIENT_ID    com.techgetafrica.yournotalone (optional; the default)

const APPLE_TEAM_ID = Deno.env.get('APPLE_TEAM_ID');
const APPLE_KEY_ID = Deno.env.get('APPLE_KEY_ID');
const APPLE_PRIVATE_KEY = Deno.env.get('APPLE_PRIVATE_KEY');
const APPLE_CLIENT_ID =
  Deno.env.get('APPLE_CLIENT_ID') ?? 'com.techgetafrica.yournotalone';

const APPLE_AUTH = 'https://appleid.apple.com';

export function appleConfigured(): boolean {
  return Boolean(APPLE_TEAM_ID && APPLE_KEY_ID && APPLE_PRIVATE_KEY);
}

function base64url(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64urlJson(value: unknown): string {
  return base64url(new TextEncoder().encode(JSON.stringify(value)));
}

async function clientSecret(): Promise<string> {
  if (!appleConfigured()) throw new Error('apple_not_configured');

  // Secrets pasted through the dashboard sometimes arrive with literal "\n".
  const pem = APPLE_PRIVATE_KEY!.replace(/\\n/g, '\n');
  const der = Uint8Array.from(
    atob(pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '')),
    (c) => c.charCodeAt(0),
  );
  const key = await crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  );

  const now = Math.floor(Date.now() / 1000);
  const signingInput = [
    base64urlJson({ alg: 'ES256', kid: APPLE_KEY_ID }),
    base64urlJson({
      iss: APPLE_TEAM_ID,
      iat: now,
      exp: now + 5 * 60,
      aud: APPLE_AUTH,
      sub: APPLE_CLIENT_ID,
    }),
  ].join('.');

  // WebCrypto's ECDSA signature is already r‖s, which is what JWS expects.
  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${base64url(new Uint8Array(signature))}`;
}

// Swaps the authorization code from a native sign-in for a refresh token.
export async function exchangeAuthorizationCode(code: string): Promise<string> {
  const response = await fetch(`${APPLE_AUTH}/auth/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: APPLE_CLIENT_ID,
      client_secret: await clientSecret(),
      code,
      grant_type: 'authorization_code',
    }),
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok || typeof body.refresh_token !== 'string') {
    throw new Error(`apple_token_failed ${response.status} ${body.error ?? ''}`);
  }
  return body.refresh_token;
}

// Revokes a refresh token, ending the app's access to the user's Apple
// Account. Apple answers 200 for a token that is already invalid too.
export async function revokeRefreshToken(token: string): Promise<void> {
  const response = await fetch(`${APPLE_AUTH}/auth/revoke`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: APPLE_CLIENT_ID,
      client_secret: await clientSecret(),
      token,
      token_type_hint: 'refresh_token',
    }),
  });
  if (!response.ok) {
    const text = await response.text().catch(() => '');
    throw new Error(`apple_revoke_failed ${response.status} ${text}`);
  }
}
