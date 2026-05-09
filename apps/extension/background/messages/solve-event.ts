/**
 * Background Service Worker
 * Handles API calls and WebSocket connection to mitaLeet backend.
 */

import type { PlasmoMessaging } from '@plasmohq/messaging';

const API_BASE = process.env.PLASMO_PUBLIC_API_URL ?? 'http://localhost:3000';

interface StoredAuth {
  token: string;
  userId: string;
}

// ── Auth helpers ──────────────────────────────────────────────────────

async function getAuth(): Promise<StoredAuth | null> {
  const data = await chrome.storage.local.get(['lc_token', 'lc_userId']);
  if (!data.lc_token) return null;
  return { token: data.lc_token, userId: data.lc_userId };
}

// ── API call ─────────────────────────────────────────────────────────

async function apiPost(path: string, body: unknown, token: string): Promise<boolean> {
  try {
    const res = await fetch(`${API_BASE}${path}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify(body),
    });
    return res.ok;
  } catch {
    return false;
  }
}

// ── Message handler ───────────────────────────────────────────────────

export const handler: PlasmoMessaging.MessageHandler = async (req, res) => {
  const auth = await getAuth();
  if (!auth) {
    res.send({ ok: false, reason: 'not_authenticated' });
    return;
  }

  const event = req.body as {
    type: 'PROBLEM_OPENED' | 'CODE_RUN' | 'PROBLEM_SOLVED';
    problemSlug: string;
    language?: string;
    timestamp: number;
    durationMs?: number;
  };

  switch (event.type) {
    case 'PROBLEM_OPENED':
      // Start a solve session on the backend
      await apiPost('/api/v1/leetcode/sessions', {
        problemSlug: event.problemSlug,
        language: event.language ?? 'unknown',
        startedAt: new Date(event.timestamp).toISOString(),
      }, auth.token);
      break;

    case 'CODE_RUN':
      // Could track run attempts — no-op for now, extend here
      break;

    case 'PROBLEM_SOLVED':
      // Complete solve session
      await apiPost('/api/v1/leetcode/extension-solve', {
        problemSlug: event.problemSlug,
        language: event.language ?? 'unknown',
        durationMs: event.durationMs ?? 0,
        solvedAt: new Date(event.timestamp).toISOString(),
      }, auth.token);
      break;
  }

  res.send({ ok: true });
};
