# Doc tooling

Node utilities for the Markdown docs — kept separate from the Flutter app so
they don't touch `pubspec.yaml` or the Dart toolchain.

## Verify diagrams render on GitHub

`verify_diagrams.mjs` checks every `.md` file under `docs/` (plus the top-level
`README.md`) for:

- **Balanced code fences** — an unterminated ` ``` ` breaks the whole rendered
  page on GitHub.
- **Valid Mermaid** — each ` ```mermaid ` block is parsed with
  [`mermaid`](https://www.npmjs.com/package/mermaid), the same engine GitHub
  uses to render diagrams client-side. No browser/Chromium is downloaded; a
  lightweight `jsdom` provides the DOM the parser needs.

```bash
cd tool
npm install     # one-time
npm run verify
```

Exits non-zero if any fence is unbalanced or any diagram is invalid, so it can
be wired into CI.