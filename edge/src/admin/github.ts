// The little of GitHub's API the admin page needs: read the content
// folder, commit files to main in one commit, and start or list runs of
// the content workflow. Git stays the record of every content change, so
// anything saved here can be seen, reviewed and reverted like any commit.

import type { Env } from '../env';
import { HttpError } from '../http';

const API = 'https://api.github.com';
export const BRANCH = 'main';
export const WORKFLOW = 'content.yml';

export interface RepoFile {
  path: string;
  text: string;
}

function repo(env: Env): string {
  if (!env.ADMIN_GITHUB_TOKEN || !env.GITHUB_REPO) throw new HttpError(503, 'admin_not_configured');
  return env.GITHUB_REPO;
}

async function gh<T>(env: Env, path: string, init: RequestInit = {}): Promise<T> {
  const res = await fetch(`${API}${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${env.ADMIN_GITHUB_TOKEN}`,
      Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'yournotalone-admin',
      ...(init.body ? { 'Content-Type': 'application/json' } : {}),
    },
  });
  if (!res.ok) {
    const detail = await res.text().catch(() => '');
    throw new HttpError(res.status === 409 || res.status === 422 ? 409 : 502, 'github_failed', `${path} -> ${res.status} ${detail.slice(0, 200)}`);
  }
  return (res.status === 204 ? undefined : await res.json()) as T;
}

/** Every file under [dir] on main, with its text, in one GraphQL call. */
export async function readTree(env: Env, dir: string): Promise<RepoFile[]> {
  const [owner, name] = repo(env).split('/');
  // Two levels: content/items/<kind>/<file>.yaml.
  const query = `query($owner: String!, $name: String!, $expr: String!) {
    repository(owner: $owner, name: $name) {
      object(expression: $expr) {
        ... on Tree { entries { path type object {
          ... on Blob { text }
          ... on Tree { entries { path type object { ... on Blob { text } } } }
        } } }
      }
    }
  }`;
  type Entry = { path: string; type: string; object: { text?: string; entries?: Entry[] } | null };
  const body = await gh<{ data?: { repository?: { object?: { entries?: Entry[] } | null } }; errors?: unknown }>(
    env,
    '/graphql',
    { method: 'POST', body: JSON.stringify({ query, variables: { owner, name, expr: `${BRANCH}:${dir}` } }) },
  );
  if (body.errors) throw new HttpError(502, 'github_failed', JSON.stringify(body.errors).slice(0, 200));
  const out: RepoFile[] = [];
  const walk = (entries: Entry[] = []) => {
    for (const e of entries) {
      if (e.type === 'blob' && typeof e.object?.text === 'string') out.push({ path: e.path, text: e.object.text });
      else if (e.type === 'tree') walk(e.object?.entries);
    }
  };
  walk(body.data?.repository?.object?.entries);
  return out;
}

/** One file on main, or null if it isn't there. */
export async function readFile(env: Env, path: string): Promise<string | null> {
  try {
    const file = await gh<{ content: string; encoding: string }>(
      env,
      `/repos/${repo(env)}/contents/${path.split('/').map(encodeURIComponent).join('/')}?ref=${BRANCH}`,
    );
    const bytes = Uint8Array.from(atob(file.content.replace(/\n/g, '')), (ch) => ch.charCodeAt(0));
    return new TextDecoder().decode(bytes);
  } catch (error) {
    if (error instanceof HttpError && error.message.includes('-> 404')) return null;
    throw error;
  }
}

/**
 * Commits [files] to main as one commit. Built on the commit main points
 * at now; if someone pushed in between, it tries once more on top.
 */
export async function commitFiles(env: Env, files: RepoFile[], message: string): Promise<string> {
  const r = repo(env);
  for (let attempt = 0; ; attempt++) {
    const ref = await gh<{ object: { sha: string } }>(env, `/repos/${r}/git/ref/heads/${BRANCH}`);
    const parent = await gh<{ tree: { sha: string } }>(env, `/repos/${r}/git/commits/${ref.object.sha}`);
    const tree = await gh<{ sha: string }>(env, `/repos/${r}/git/trees`, {
      method: 'POST',
      body: JSON.stringify({
        base_tree: parent.tree.sha,
        tree: files.map((f) => ({ path: f.path, mode: '100644', type: 'blob', content: f.text })),
      }),
    });
    const commit = await gh<{ sha: string }>(env, `/repos/${r}/git/commits`, {
      method: 'POST',
      body: JSON.stringify({ message, tree: tree.sha, parents: [ref.object.sha] }),
    });
    try {
      await gh(env, `/repos/${r}/git/refs/heads/${BRANCH}`, {
        method: 'PATCH',
        body: JSON.stringify({ sha: commit.sha, force: false }),
      });
      return commit.sha;
    } catch (error) {
      if (attempt === 0 && error instanceof HttpError && error.status === 409) continue;
      throw error;
    }
  }
}

/** Starts the content workflow on main for [target]. */
export async function startPublish(env: Env, target: 'staging' | 'production'): Promise<void> {
  await gh(env, `/repos/${repo(env)}/actions/workflows/${WORKFLOW}/dispatches`, {
    method: 'POST',
    body: JSON.stringify({ ref: BRANCH, inputs: { env: target } }),
  });
}

export interface Run {
  id: number;
  status: string;
  conclusion: string | null;
  event: string;
  title: string;
  target: string;
  createdAt: string;
  url: string;
}

/** The content workflow's latest runs, newest first. */
export async function recentRuns(env: Env, count = 8): Promise<Run[]> {
  const body = await gh<{ workflow_runs: any[] }>(
    env,
    `/repos/${repo(env)}/actions/workflows/${WORKFLOW}/runs?branch=${BRANCH}&per_page=${count}`,
  );
  return body.workflow_runs.map((w) => ({
    id: w.id,
    status: w.status,
    conclusion: w.conclusion,
    event: w.event,
    title: w.display_title,
    // The run name says which environment (see content.yml run-name).
    target: /production/i.test(w.name ?? '') || /production/i.test(w.display_title ?? '') ? 'production' : 'staging',
    createdAt: w.created_at,
    url: w.html_url,
  }));
}
