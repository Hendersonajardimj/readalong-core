# Provenance

Prepared October 5, 2026 as a standalone extraction of the existing Readalong web project.

- `src/normalize.ts`: copied unchanged from the existing core module.
- `src/lookup.ts`: copied with one import-path adjustment to the standalone token type; algorithm unchanged.
- `src/types.ts`: plain TypeScript structure adapted from the existing token timing schema; runtime schema validation excluded.
- `test/core.test.ts`: existing core boundary/normalization cases adapted to Node’s built-in test runner.
- `demo.ts`, package metadata, and documentation: prepared with Codex for this extraction.
- `LICENSE`: retained from Readalong.

Readalong was developed with coding-agent assistance. This export does not claim unaided or sole personal authorship of every line. A discussion of the code should identify the developer’s own decisions, agent contributions, and understanding.

The export uses synthetic words and text. It carries no private client source, credentials, private fixtures, speech-provider configuration, or original Git history.
