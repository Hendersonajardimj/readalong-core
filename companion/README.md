# ReadAlongKit companion contract

This is the actual shared Swift package used by the native Mac producer and iPhone/iPad companion, extracted from private Read Along commit `04b4edc788693c7e4ad91d536f50167075829fea` on October 10, 2026. The app interfaces and speech engines are outside this public sample.

It needs **Swift 6 and macOS 14 or newer** to run its tests because it validates playable media with AVFoundation and uses CryptoKit. Its declared iOS minimum is 17. It has no third-party dependencies. Linux cannot run this package.

```sh
npm run fixtures
READALONG_CONTRACT_FIXTURES="$PWD/.tmp/contract-fixtures" swift test --package-path companion/ReadAlongKit
```

The tests create synthetic PCM WAVs and temporary directories. The extra Python and TypeScript publishers generate one second of silence and invented text; they require no speech provider, account or private library. They exercise interoperability with the real Swift loader. They are minimal public fixture writers, not the complete private exporters.

Read [the portable format](FORMAT.md), [the implementation](ReadAlongKit/Sources/ReadAlongKit/ReadAlongBundle.swift), [the tests](ReadAlongKit/Tests/ReadAlongKitTests/ReadAlongBundleTests.swift), and [the dated device journey](../docs/device-acceptance.md). The root [MIT license](../LICENSE) covers this published subset.
