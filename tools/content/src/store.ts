// The object-store calls publishing needs, behind an interface so
// tests can swap in a fake. The real one talks to R2's S3 API, signed with
// aws4fetch.
import { AwsClient } from 'aws4fetch';
import type { Credentials } from './config.ts';

export type PutOptions = {
  contentType: string;
  cacheControl: string;
  /// Custom metadata, sent as x-amz-meta-<name> (names lower case).
  metadata?: Record<string, string>;
};

/// What HEAD says about an object: its custom metadata (lower-case names).
export type ObjectInfo = { metadata: Record<string, string> };

export interface Store {
  /// Whether the object exists.
  head(bucket: string, key: string): Promise<boolean>;
  /// The object's custom metadata, or null if there is no object.
  stat(bucket: string, key: string): Promise<ObjectInfo | null>;
  /// The object's bytes, or null if there is none.
  get(bucket: string, key: string): Promise<Uint8Array | null>;
  put(bucket: string, key: string, body: Uint8Array, opts: PutOptions): Promise<void>;
  /// Removes the object; no error if it isn't there.
  delete(bucket: string, key: string): Promise<void>;
}

export function objectUrl(endpoint: string, bucket: string, key: string): string {
  const path = key.split('/').map(encodeURIComponent).join('/');
  return `${endpoint}/${encodeURIComponent(bucket)}/${path}`;
}

export function r2Store(endpoint: string, creds: Credentials): Store {
  const aws = new AwsClient({ ...creds, service: 's3', region: 'auto' });
  const fail = async (what: string, res: Response): Promise<never> => {
    const text = await res.text().catch(() => '');
    throw new Error(`${what} failed: HTTP ${res.status} ${text.slice(0, 300)}`.trim());
  };
  return {
    async head(bucket, key) {
      const res = await aws.fetch(objectUrl(endpoint, bucket, key), { method: 'HEAD' });
      if (res.status === 404) return false;
      if (!res.ok) return fail(`HEAD ${bucket}/${key}`, res);
      return true;
    },
    async stat(bucket, key) {
      const res = await aws.fetch(objectUrl(endpoint, bucket, key), { method: 'HEAD' });
      if (res.status === 404) return null;
      if (!res.ok) return fail(`HEAD ${bucket}/${key}`, res);
      const metadata: Record<string, string> = {};
      res.headers.forEach((v, k) => {
        if (k.toLowerCase().startsWith('x-amz-meta-')) metadata[k.toLowerCase().slice('x-amz-meta-'.length)] = v;
      });
      return { metadata };
    },
    async get(bucket, key) {
      const res = await aws.fetch(objectUrl(endpoint, bucket, key));
      if (res.status === 404) {
        await res.body?.cancel();
        return null;
      }
      if (!res.ok) return fail(`GET ${bucket}/${key}`, res);
      return new Uint8Array(await res.arrayBuffer());
    },
    async put(bucket, key, body, opts) {
      const res = await aws.fetch(objectUrl(endpoint, bucket, key), {
        method: 'PUT',
        body,
        headers: {
          'content-type': opts.contentType,
          'cache-control': opts.cacheControl,
          ...Object.fromEntries(
            Object.entries(opts.metadata ?? {}).map(([k, v]) => [`x-amz-meta-${k.toLowerCase()}`, v]),
          ),
        },
      });
      if (!res.ok) return fail(`PUT ${bucket}/${key}`, res);
      await res.body?.cancel();
    },
    async delete(bucket, key) {
      const res = await aws.fetch(objectUrl(endpoint, bucket, key), { method: 'DELETE' });
      if (!res.ok && res.status !== 404) return fail(`DELETE ${bucket}/${key}`, res);
      await res.body?.cancel();
    },
  };
}

/// An in-memory store that records every call, for tests.
export class MemoryStore implements Store {
  objects = new Map<string, { body: Uint8Array } & PutOptions>();
  calls: { op: 'head' | 'stat' | 'get' | 'put' | 'delete'; bucket: string; key: string }[] = [];

  async head(bucket: string, key: string) {
    this.calls.push({ op: 'head', bucket, key });
    return this.objects.has(`${bucket}/${key}`);
  }
  async stat(bucket: string, key: string) {
    this.calls.push({ op: 'stat', bucket, key });
    const o = this.objects.get(`${bucket}/${key}`);
    return o ? { metadata: { ...(o.metadata ?? {}) } } : null;
  }
  async delete(bucket: string, key: string) {
    this.calls.push({ op: 'delete', bucket, key });
    this.objects.delete(`${bucket}/${key}`);
  }
  async get(bucket: string, key: string) {
    this.calls.push({ op: 'get', bucket, key });
    return this.objects.get(`${bucket}/${key}`)?.body ?? null;
  }
  async put(bucket: string, key: string, body: Uint8Array, opts: PutOptions) {
    this.calls.push({ op: 'put', bucket, key });
    this.objects.set(`${bucket}/${key}`, { body, ...opts });
  }
  puts() {
    return this.calls.filter((c) => c.op === 'put');
  }
  deletes() {
    return this.calls.filter((c) => c.op === 'delete');
  }
}
