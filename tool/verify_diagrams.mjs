#!/usr/bin/env node
// Verifies that the Markdown docs render cleanly on GitHub:
//   1. Code fences are balanced (an unterminated ``` breaks the whole page).
//   2. Every ```mermaid block parses against the same engine GitHub uses.
//
// Usage (from this tool/ directory):
//   npm install          # one-time: pulls mermaid + jsdom (no browser)
//   npm run verify
//
// Exits non-zero if any file has an unbalanced fence or an invalid diagram,
// so it can be dropped straight into CI.

import { readFileSync, readdirSync, statSync } from 'fs';
import { dirname, join, relative } from 'path';
import { fileURLToPath } from 'url';
import { JSDOM } from 'jsdom';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..');

// Files to check: everything under docs/ plus the top-level README.
function markdownFiles() {
  const out = [];
  const readme = join(repoRoot, 'README.md');
  try {
    if (statSync(readme).isFile()) out.push(readme);
  } catch (_) {
    /* no README — fine */
  }
  const walk = (dir) => {
    for (const name of readdirSync(dir)) {
      const p = join(dir, name);
      const s = statSync(p);
      if (s.isDirectory()) walk(p);
      else if (name.endsWith('.md')) out.push(p);
    }
  };
  try {
    walk(join(repoRoot, 'docs'));
  } catch (_) {
    /* no docs/ — fine */
  }
  return out;
}

// Pull ```mermaid ... ``` blocks out of a Markdown string and, along the way,
// confirm no code fence was left open.
function extract(md) {
  const lines = md.split('\n');
  const blocks = [];
  let fenceOpen = false;
  let fenceLang = '';
  let openLine = 0;
  let buf = null;
  lines.forEach((line, i) => {
    const m = line.match(/^```(\w*)\s*$/);
    if (m) {
      if (!fenceOpen) {
        fenceOpen = true;
        fenceLang = m[1];
        openLine = i + 1;
        if (fenceLang === 'mermaid') buf = [];
      } else {
        if (buf !== null) blocks.push(buf.join('\n'));
        fenceOpen = false;
        fenceLang = '';
        buf = null;
      }
      return;
    }
    if (buf !== null) buf.push(line);
  });
  return { blocks, unterminated: fenceOpen ? openLine : 0 };
}

// A DOM is enough for mermaid's parser — no browser/Chromium needed.
const dom = new JSDOM('<!DOCTYPE html><body></body>', { pretendToBeVisual: true });
globalThis.window = dom.window;
globalThis.document = dom.window.document;

const mermaid = (await import('mermaid')).default;
mermaid.initialize({ startOnLoad: false });

let failures = 0;
let diagrams = 0;

for (const file of markdownFiles()) {
  const rel = relative(repoRoot, file);
  const { blocks, unterminated } = extract(readFileSync(file, 'utf8'));
  if (unterminated) {
    console.log(`✗ ${rel}: unterminated code fence opened at line ${unterminated}`);
    failures++;
  }
  for (let i = 0; i < blocks.length; i++) {
    diagrams++;
    const type = blocks[i].trim().split(/\s+/)[0];
    try {
      await mermaid.parse(blocks[i]);
      console.log(`✓ ${rel}: diagram ${i + 1} (${type})`);
    } catch (e) {
      const msg = String(e && e.message ? e.message : e).split('\n')[0];
      console.log(`✗ ${rel}: diagram ${i + 1} (${type}) INVALID — ${msg}`);
      failures++;
    }
  }
}

console.log(
  `\n${diagrams} diagram(s) checked, ${failures} problem(s) found.`,
);
process.exit(failures ? 1 : 0);