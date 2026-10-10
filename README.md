# Readalong Core

Two runnable pieces of Read Along: a small browser timing/text sample, and the actual Swift bundle contract used to take completed Mac narration to iPhone and iPad.

[Read Along story and web demonstration](https://hendeaux.dev/projects/read-along) · [Device journey and limits](docs/device-acceptance.md) · [Provenance](PROVENANCE.md)

## Run the browser example

Use Node.js 22.18 or newer and Python 3. There are no npm dependencies or provider credentials.

```sh
npm run demo
npm test
```

The demo uses two synthetic timed words. Tests cover start/end boundaries, gaps, text normalization and the independently generated portable fixtures.

## Run the native contract

Use Swift 6 on macOS 14 or newer. This is a shared library, not the full native app.

```sh
npm run fixtures
READALONG_CONTRACT_FIXTURES="$PWD/.tmp/contract-fixtures" swift test --package-path companion/ReadAlongKit
```

The tests create valid silent WAVs and verify hashes, forged IDs/durations, incomplete packages, unknown formats, unsafe paths, symlinks, exact UTF-16 text ranges and immutable duplicates. Generated Python/TypeScript packages also pass through the Swift loader and importer. [Format and failure handling](companion/FORMAT.md).

## Start reading here

| File | Question it answers |
| --- | --- |
| [src/lookup.ts](src/lookup.ts) | Which word contains the current audio time? |
| [src/normalize.ts](src/normalize.ts) | How can whitespace change while text offsets remain traceable? |
| [test/core.test.ts](test/core.test.ts) | What happens at starts, ends, gaps and mapped text? |
| [ReadAlongBundle.swift](companion/ReadAlongKit/Sources/ReadAlongKit/ReadAlongBundle.swift) | When is a downloaded package complete, valid and safe to play? |
| [ReadAlongBundleTests.swift](companion/ReadAlongKit/Tests/ReadAlongKitTests/ReadAlongBundleTests.swift) | Which corruption, Unicode and filesystem failures are rejected? |
| [Fixture interoperability test](test/fixtures.test.ts) | Do independent publishers agree on the content identity and source ranges? |

## Two contracts, different responsibilities

Browser lookup uses binary search over valid, ordered, nonoverlapping intervals. Starts are included, ends excluded, and gaps have no active word. Normalization returns an original-script index for each output UTF-16 code unit; that is not spoken-word alignment or a grapheme map.

The native package owns a completed playback snapshot: exact text, playable audio, word timings and public metadata. It checks content and payload hashes, validates source ranges, and commits a copied package atomically. It allows overlapping native timing estimates under its documented rules. Timing fidelity remains explicitly estimated or measured; these synthetic fixtures do not measure speech.

## Scope and provenance

The browser sample was extracted October 5, 2026. The Swift package and existing failure tests were extracted October 10 from private Read Along source commit `04b4edc788693c7e4ad91d536f50167075829fea`. See [provenance](PROVENANCE.md) for unchanged files and the small public adaptations.

Read Along was built with coding-agent assistance. This subset exposes inspectable code and tests without claiming unaided authorship, the entire application, or broad user acceptance. The [dated acceptance summary](docs/device-acceptance.md) distinguishes a physical iPhone journey, simulator checks and remaining device work.

No speech engine, client source, private reading material, credentials or original private Git history is included. MIT license; see [LICENSE](LICENSE).
