import type { Context } from 'hono';
import type { ContentfulStatusCode } from 'hono/utils/http-status';

/** Uniform JSON error body: { "error": "<code>", "message"?: "…" }. */
export function jsonError(c: Context, status: ContentfulStatusCode, error: string, message?: string) {
  return c.json(message ? { error, message } : { error }, status);
}

export class HttpError extends Error {
  constructor(
    readonly status: ContentfulStatusCode,
    readonly code: string,
    message?: string,
  ) {
    super(message ?? code);
  }
}

export async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(input));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
}
