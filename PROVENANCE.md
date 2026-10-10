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

## Native contract extraction — October 10, 2026

Source: private `Hendersonajardimj/read-along`, commit `04b4edc788693c7e4ad91d536f50167075829fea`. The source reference identifies lineage; the private repository is not needed to run this sample.

- `companion/ReadAlongKit/Package.swift` and `Sources/ReadAlongKit/ReadAlongBundle.swift`: copied unchanged. Apple system frameworks only; no third-party component source.
- `ReadAlongBundleTests.swift`: copied existing synthetic tests; only the optional cross-publisher test's display name was changed to identify the public fixtures accurately.
- `companion/FORMAT.md`: source format guide, with public paths and fixture wording corrected.
- Public fixture writers, interoperability check, CI, README and sanitized device summary: prepared with Codex. They contain invented text and silent PCM audio. They do not distribute the private generation tools or native app.
- Source-file SHA-256 digests before extraction:

  - `shared/ReadAlongKit/Package.swift`: `cdae97f590ae3360ec07252b2e6ac4a5d6206f34fdb2c38fd090ef01fde45825`
  - `shared/ReadAlongKit/Sources/ReadAlongKit/ReadAlongBundle.swift`: `15989a3712d46113c8c9c2da03603b3ff6ceeb129059324ee52dd8a91fc6c8a2`
  - `shared/ReadAlongKit/Tests/ReadAlongKitTests/ReadAlongBundleTests.swift`: `223ae208f19cbb0cb158e240c27801eed97a2dcb6fa408f2590f6b4100baa512`

The existing MIT license is unchanged and covers this published subset. No private source history, personal paths, reading libraries, media recordings, account records or licensed UI assets were copied.
