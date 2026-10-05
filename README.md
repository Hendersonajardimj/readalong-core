# Readalong Core

A small, runnable piece of Read Along: find the word playing at an audio position, and normalize narration text while keeping a map to the original script.

[Read Along story and demo](https://hendeaux.dev/projects/read-along)

## Run it

Use Node.js 22.18 or newer. There are no external dependencies, provider keys, or audio downloads.

```sh
npm run demo
npm test
```

The demo uses two synthetic timed words. It prints which word is active at several audio positions and shows a normalized script with its source map.

## Start reading here

| File | Question it answers |
| --- | --- |
| [src/lookup.ts](src/lookup.ts) | Which word contains the current audio time? |
| [src/normalize.ts](src/normalize.ts) | How can whitespace change while text offsets remain traceable? |
| [src/types.ts](src/types.ts) | What timing and text ranges does a token carry? |
| [demo.ts](demo.ts) | What happens at a word’s start, its end, and a gap? |
| [test/core.test.ts](test/core.test.ts) | Which boundary and text-mapping cases are checked? |

## How lookup works

The token list is ordered by start time. A binary search finds the last token that starts at or before the audio position, then checks whether the position is before its end. Intervals include the start and exclude the end; a gap has no active word.

This core assumes valid, ordered, non-overlapping timing intervals. It does not generate speech or validate a provider response.

## How text mapping works

Normalization reduces horizontal whitespace and repeated blank lines. Alongside the resulting text, it returns the original script index for each output UTF-16 code unit. This is a code-unit map, not a grapheme or spoken-word alignment.

In the complete app, measured provider timings and estimated native timings have different origins. They should be identified accurately; this sample invents neither.

## Scope and provenance

The two core algorithms come from the existing agent-assisted Readalong web project. Codex prepared this standalone extraction, its synthetic demo, the dependency-free test adaptation, and the documentation on October 5, 2026. [Provenance](PROVENANCE.md).

This repository is a core sample. It contains no speech engine, client work, private reading material, or full-app distribution.

MIT licence; see [LICENSE](LICENSE).
