# Read Along shared contract

`ReadAlongKit` is the Swift package used by the Mac producer and the iPhone/iPad companion. It owns completed experience storage and validation. Generation stays on the Mac; importing a completed package copies its audio, text and word timings into the companion's local library for offline use.

Requires Swift 6, macOS 14 or iOS/iPadOS 17. Uses Foundation, CryptoKit and AVFoundation without third-party dependencies.

## Portable package v1

A completed experience is a directory named `<id>.readalong`, containing exactly:

| File | Contents |
| --- | --- |
| `manifest.json` | The metadata and SHA-256 hashes below |
| `text.txt` | Exact nonempty UTF-8 source text |
| `timing.json` | A JSON array of word records |
| `audio.wav` or `audio.mp3` | Completed playable audio; exactly one audio file |

The ID is the lowercase hexadecimal SHA-256 digest of the raw `text.txt` bytes followed by the raw audio bytes. It identifies the generated content, independent of title, creation time or JSON formatting. Each payload also has its own SHA-256 digest. UTF-8 text must be preserved as generated; line endings and Unicode normalization affect the hashes.

`manifest.json` fields:

| Field | Value |
| --- | --- |
| `schemaVersion` | `readalong.bundle.v1` |
| `id` | 64 lowercase hexadecimal characters |
| `title` | Nonblank display title |
| `createdAt` | ISO 8601 timestamp with timezone; fractional seconds supported |
| `audioFile` | `audio.wav` or `audio.mp3` |
| `durationSeconds` | Positive finite number |
| `timingFidelity` | `estimated` or `measured` |
| `textFile` | `text.txt` |
| `timingFile` | `timing.json` |
| `hashes` | Object with `text`, `audio`, `timing`: lowercase SHA-256 digests of each file's exact bytes |

Each `timing.json` array element contains:

```json
{
  "word": "Hello",
  "startMilliseconds": 0,
  "endMilliseconds": 220,
  "utf16Start": 0,
  "utf16End": 5
}
```

Source offsets count UTF-16 code units, and the end is exclusive. Each word must exactly match the source range, including its Unicode code units. Ranges must be ordered, nonoverlapping and within the text. Gaps may contain whitespace, punctuation and symbols; they cannot omit letters or decimal digits. At least one word is required.

Timing starts must be nonnegative and nondecreasing; word ends must exceed their starts. Adjacent VAD estimates may overlap in time. Word ends cannot exceed `ceil(durationSeconds * 1000) + 1`, allowing integer rounding. `AVAudioFile` must open the audio and report a positive finite duration. The manifest duration must be within 0.25 seconds of decoded audio, and word ends must also lie within 0.25 seconds of decoded audio. This small tolerance accommodates MP3 encoder padding and decoder-duration differences.

Loading rejects missing or extra files, unknown schema versions, unsafe filenames, symlink package directories or payloads, invalid hashes/IDs, invalid UTF-8, unreadable audio and invalid timings. Text is limited to 32 MiB, timings to 64 MiB and the manifest to 64 KiB. Audio hashing streams in 1 MiB chunks.

## Swift API

```swift
import ReadAlongKit

let store = ReadAlongBundleStore(rootURL: libraryDirectory)
let completed = try store.export(
    title: title,
    text: synthesizedText,
    audioURL: generatedAudio,
    durationSeconds: duration,
    words: mappedWords,
    timingFidelity: .estimated
)

// A Files/iCloud source is validated, copied and validated again locally.
let downloaded = try store.importBundle(at: sourcePackageURL)
let availableOffline = try store.bundles()
let inspected = try ReadAlongBundleStore.load(at: completed.directoryURL)
```

`ReadAlongBundle` exposes `directoryURL`, `manifest`, `text`, `words` and `audioURL`. `ReadAlongManifest.createdAt` is a `Date`; it serializes as an ISO 8601 string. `ReadAlongWord` exposes the five timing-record fields. The types are `Sendable`, and validation failures expose `ReadAlongBundleError` with a readable error description.

Exports and imports use a temporary `.incoming-<UUID>` directory beneath the destination root. The package is validated before one rename commits it. Failed work is removed, and directory enumeration ignores incomplete staging directories. Existing packages are never overwritten.

A duplicate ID reuses the first immutable package when validated text/audio hashes, decoded word records, audio filename, timing fidelity and duration agree (duration tolerance 0.25 seconds). Differences in JSON key ordering, indentation or trailing newline are allowed. A changed title or creation time preserves the original metadata. Different semantic timings produce `duplicateBundleConflict`; they cannot silently overwrite an existing experience. A corrupt existing package causes validation to fail.

`bundles()` reports validation errors rather than treating corrupt files as playable. A UI may enumerate package directories and call `load(at:)` separately to display an error for one item while loading the other valid items.

## Verification

```sh
cd companion/ReadAlongKit
swift test
```

Tests cover real PCM WAV round trips and imports, Unicode/surrogate ranges, corruption of every payload, forged IDs/durations, unreadable audio, incomplete packages, future schema versions, path traversal, symlinks, immutable duplicates, semantic JSON duplicates, timestamp compatibility, VAD overlap and duration rounding.

An optional cross-publisher test consumes the synthetic WAV packages generated by the public Python and TypeScript fixture writers, then imports and re-exports them through Swift. These minimal writers are separate from the private production exporters:

```sh
READALONG_CONTRACT_FIXTURES=/absolute/path/to/bridge-contract-fixtures swift test
```

That fixture directory has `python/` and `typescript/` subdirectories containing completed packages. It is optional; the core tests create their own valid WAV audio.
