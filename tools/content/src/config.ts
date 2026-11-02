// Where `npm run publish` sends things (docs/backend-design.md §4, §8).
// Credentials aren't here: they come from the environment, and only when
// something is really uploaded.

export const accountId = 'f7e65097ea4facdba994ee51d751705a';
export const s3Endpoint = `https://${accountId}.r2.cloudflarestorage.com`;

/// The oldest app that can read what we publish. Written into latest.json;
/// older apps keep the catalogue they have.
export const minApp = '1.1.0';

export const envNames = ['staging', 'production'] as const;
export type EnvName = (typeof envNames)[number];

export type EnvConfig = {
  name: EnvName;
  /// Catalogue, latest.json and free media. Served through the CDN.
  publicBucket: string;
  /// Premium media. Only reachable through URLs the Worker signs.
  privateBucket: string;
};

export const envs: Record<EnvName, EnvConfig> = {
  production: {
    name: 'production',
    publicBucket: 'yournotalone',
    privateBucket: 'yournotalone-private',
  },
  staging: {
    name: 'staging',
    publicBucket: 'yournotalone-staging',
    privateBucket: 'yournotalone-staging-private',
  },
};

export type Credentials = { accessKeyId: string; secretAccessKey: string };

/// The R2 token, from R2_ACCESS_KEY_ID and R2_SECRET_ACCESS_KEY. Call it
/// only when uploading for real; a dry run never needs it.
export function credentialsFromEnv(env: Record<string, string | undefined> = process.env): Credentials {
  const accessKeyId = env.R2_ACCESS_KEY_ID?.trim();
  const secretAccessKey = env.R2_SECRET_ACCESS_KEY?.trim();
  const missing = [
    !accessKeyId && 'R2_ACCESS_KEY_ID',
    !secretAccessKey && 'R2_SECRET_ACCESS_KEY',
  ].filter(Boolean);
  if (missing.length) {
    throw new Error(
      `${missing.join(' and ')} ${missing.length > 1 ? 'are' : 'is'} not set. ` +
        'Publishing needs an R2 API token with Object Read & Write on the four ' +
        'buckets (see tools/content/README.md), or use --dry-run.',
    );
  }
  return { accessKeyId: accessKeyId!, secretAccessKey: secretAccessKey! };
}
