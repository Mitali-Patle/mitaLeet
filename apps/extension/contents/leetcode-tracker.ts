/**
 * mitaLeet Content Script
 * Injected into https://leetcode.com/problems/* pages.
 * Detects problem open, code runs, and accepted submissions.
 */

import type { PlasmoCSConfig } from 'plasmo';
import { sendToBackground } from '@plasmohq/messaging';

export const config: PlasmoCSConfig = {
  matches: ['https://leetcode.com/problems/*'],
  run_at: 'document_idle',
};

interface SolveEvent {
  type: 'PROBLEM_OPENED' | 'CODE_RUN' | 'PROBLEM_SOLVED';
  problemSlug: string;
  language?: string;
  timestamp: number;
  durationMs?: number;
}

// ── State ────────────────────────────────────────────────────────────

let problemSlug = '';
let sessionStart = 0;
let lastLanguage = 'unknown';
let submitted = false;
let observerAttached = false;

// ── Helpers ───────────────────────────────────────────────────────────

function extractSlug(): string {
  const parts = window.location.pathname.split('/');
  return parts[2] ?? '';
}

function extractLanguage(): string {
  // LeetCode puts the active language in the Monaco editor mode
  const langSelector = document.querySelector<HTMLElement>(
    '[data-mode-id], .CodeMirror',
  );
  return (
    langSelector?.getAttribute('data-mode-id') ??
    document.querySelector<HTMLElement>('.ant-select-selection-item')?.innerText.toLowerCase() ??
    'unknown'
  );
}

async function emit(event: SolveEvent) {
  await sendToBackground({ name: 'solve-event', body: event });
}

// ── Problem detection ─────────────────────────────────────────────────

function onProblemLoad() {
  const slug = extractSlug();
  if (!slug || slug === problemSlug) return;
  problemSlug = slug;
  sessionStart = Date.now();
  submitted = false;
  lastLanguage = extractLanguage();
  emit({ type: 'PROBLEM_OPENED', problemSlug: slug, language: lastLanguage, timestamp: Date.now() });
}

// ── Submission detection ──────────────────────────────────────────────

function observeSubmissions() {
  if (observerAttached) return;
  observerAttached = true;

  const observer = new MutationObserver(() => {
    // Accepted submission banner
    const accepted = document.querySelector('[data-e2e-locator="submission-result"]');
    if (accepted?.textContent?.includes('Accepted') && !submitted) {
      submitted = true;
      const duration = Date.now() - sessionStart;
      const lang = extractLanguage();
      emit({
        type: 'PROBLEM_SOLVED',
        problemSlug,
        language: lang,
        timestamp: Date.now(),
        durationMs: duration,
      });
    }
  });

  observer.observe(document.body, { childList: true, subtree: true });
}

// ── Run button detection ──────────────────────────────────────────────

function listenRunButton() {
  document.addEventListener('click', (e) => {
    const target = e.target as HTMLElement;
    const isRun = target.closest('button')?.textContent?.trim().toLowerCase() === 'run';
    const isSubmit = target.closest('button')?.textContent?.trim().toLowerCase() === 'submit';
    if (isRun || isSubmit) {
      lastLanguage = extractLanguage();
      emit({ type: 'CODE_RUN', problemSlug, language: lastLanguage, timestamp: Date.now() });
    }
  }, true);
}

// ── Init ─────────────────────────────────────────────────────────────

onProblemLoad();
observeSubmissions();
listenRunButton();

// Handle SPA navigation on LeetCode
let lastPath = window.location.pathname;
new MutationObserver(() => {
  if (window.location.pathname !== lastPath) {
    lastPath = window.location.pathname;
    observerAttached = false;
    setTimeout(() => {
      onProblemLoad();
      observeSubmissions();
    }, 1000);
  }
}).observe(document.head, { childList: true });
