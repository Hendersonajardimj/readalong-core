# Native companion journey observed October 7, 2026

This is a sanitized summary of the private app's dated acceptance record at source commit `04b4edc788693c7e4ad91d536f50167075829fea`. These checks were recorded on October 7; publishing this sample did not repeat them. The code here is the bundle contract, not the complete app or a device release.

The Mac generated a new narration and published its completed package into a selected iCloud Drive folder. The physical iPhone discovered it through Files, downloaded it into app-owned storage and played it with word highlighting. Reading the four downloaded files back showed byte identity with the Mac package.

The phone also responded to speed changes, backward skipping and word seeking, advanced while backgrounded, and restored its saved position after the process was closed and reopened. Disconnecting the source folder left downloaded experiences playable. Now Playing pause and backward-skip controls were exercised through Dynamic Island. An iPad simulator separately passed drag scrubbing, playback with its source disconnected, removal of only its local copy, and re-download with progress restored.

**Limits:** source disconnection verifies a local copy while the device network remained available. Physical airplane-mode playback and lock-screen controls remain unverified. No physical iPad was tested. Raw accessibility slider setting did not dispatch the same action as an ordinary pointer drag; actual VoiceOver adjustment was not checked. These were development builds, with no TestFlight or App Store release claimed. These observations do not assess narration quality.

## Why the package is a completed snapshot

The scanner can discover small manifests without hashing large cloud audio. Import then validates the entire package, copies it into a staging directory, validates that copy and commits it with one rename. An incomplete cloud transfer never becomes a ready local experience. Playback uses app-owned bytes rather than depending on the source folder remaining reachable.

An earlier Mac cache did not retain enough metadata to prove which audio belonged to every text version. The current flow does not guess and pair those entries in bulk: reopening a matching generation can archive it into the explicit contract. Content identity uses exact text plus audio, while semantic timing differences are rejected rather than overwriting a completed bundle. The tradeoff is extra copying and validation work in exchange for a stable local playback snapshot.

The small browser lookup sample assumes ordered, nonoverlapping timing intervals. The companion contract can accept overlapping starts from native timing estimates; these are separate consumers with different contracts, not interchangeable algorithms.

[Read Along portfolio story and web demonstration](https://hendeaux.dev/projects/read-along)
