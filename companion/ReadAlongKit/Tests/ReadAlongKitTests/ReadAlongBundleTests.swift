import Foundation
import CryptoKit
import Testing
@testable import ReadAlongKit

struct ReadAlongBundleTests {
    @Test("Round trip preserves Unicode ranges, bytes and portable metadata")
    func unicodeRoundTrip() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let exported = try fixture.export()
        let imported = try ReadAlongBundleStore(rootURL: fixture.base.appendingPathComponent("phone"))
            .importBundle(at: exported.directoryURL)
        #expect(imported.text == fixture.text)
        #expect(imported.words == fixture.words)
        #expect(imported.manifest == exported.manifest)
        #expect(imported.directoryURL.lastPathComponent == "\(exported.manifest.id).readalong")
        #expect(try Data(contentsOf: imported.audioURL) == Data(contentsOf: fixture.audio))
        let expectedID = digest(Data(fixture.text.utf8) + (try Data(contentsOf: fixture.audio)))
        #expect(imported.manifest.id == expectedID)
        #expect(try fixture.store.bundles().count == 1)
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: exported.directoryURL.appendingPathComponent("manifest.json"))) as! [String: Any]
        #expect(json["schemaVersion"] as? String == "readalong.bundle.v1")
        #expect((json["createdAt"] as? String)?.hasSuffix("Z") == true)
    }

    @Test("Duplicate export returns the first immutable snapshot")
    func duplicate() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let first = try fixture.export()
        let manifestURL = first.directoryURL.appendingPathComponent("manifest.json")
        let original = try Data(contentsOf: manifestURL)
        let duplicate = try fixture.store.export(title: "A different label", text: fixture.text,
                                                 audioURL: fixture.audio, durationSeconds: 1,
                                                 words: fixture.words, timingFidelity: .estimated,
                                                 createdAt: Date(timeIntervalSince1970: 1_800_000_000))
        #expect(duplicate.manifest.title == first.manifest.title)
        #expect(duplicate.manifest.createdAt == first.manifest.createdAt)
        #expect(try Data(contentsOf: manifestURL) == original)
        #expect(try fixture.store.bundles().count == 1)
    }

    @Test("Different timings cannot silently replace an existing content ID")
    func duplicateConflict() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let first = try fixture.export()
        var changed = fixture.words
        let word = changed[0]
        changed[0] = ReadAlongWord(word: word.word, startMilliseconds: word.startMilliseconds,
                                  endMilliseconds: word.endMilliseconds + 1,
                                  utf16Start: word.utf16Start, utf16End: word.utf16End)
        #expect(throws: ReadAlongBundleError.duplicateBundleConflict(first.manifest.id)) {
            try fixture.export(words: changed)
        }
        #expect(try ReadAlongBundleStore.load(at: first.directoryURL).words == fixture.words)
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.store.rootURL.path).count == 1)
    }

    @Test("Every payload digest is checked", arguments: ["text.txt", "timing.json", "audio.wav"])
    func corruption(filename: String) throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let exported = try fixture.export()
        let payload = exported.directoryURL.appendingPathComponent(filename)
        var bytes = try Data(contentsOf: payload)
        bytes.append(0x20)
        try bytes.write(to: payload)
        #expect(throws: ReadAlongBundleError.hashMismatch(filename)) {
            try ReadAlongBundleStore.load(at: exported.directoryURL)
        }
        let phone = ReadAlongBundleStore(rootURL: fixture.base.appendingPathComponent("phone"))
        #expect(throws: (any Error).self) { try phone.importBundle(at: exported.directoryURL) }
        #expect(try phone.bundles().isEmpty)
    }

    @Test("Content ID is independently recomputed after hashing payloads")
    func identityTampering() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let exported = try fixture.export()
        let forgedID = String(repeating: "a", count: 64)
        try fixture.modifyManifest(exported) { $0["id"] = forgedID }
        let renamed = exported.directoryURL.deletingLastPathComponent().appendingPathComponent("\(forgedID).readalong")
        try FileManager.default.moveItem(at: exported.directoryURL, to: renamed)
        #expect(throws: ReadAlongBundleError.hashMismatch("content ID")) {
            try ReadAlongBundleStore.load(at: renamed)
        }
    }

    @Test("Partial packages and unknown versions never enter the library")
    func incompleteAndVersion() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let exported = try fixture.export()
        try fixture.modifyManifest(exported) { $0["schemaVersion"] = "readalong.bundle.v2" }
        #expect(throws: ReadAlongBundleError.invalidManifest("unsupported schema version readalong.bundle.v2")) {
            try ReadAlongBundleStore.load(at: exported.directoryURL)
        }
        try fixture.modifyManifest(exported) { $0["schemaVersion"] = "readalong.bundle.v1" }
        try FileManager.default.removeItem(at: exported.directoryURL.appendingPathComponent("timing.json"))
        #expect(throws: ReadAlongBundleError.incompleteBundle("expected exactly manifest, text, timings and audio")) {
            try ReadAlongBundleStore.load(at: exported.directoryURL)
        }
        let incompleteStage = fixture.store.rootURL.appendingPathComponent(".incoming-interrupted")
        try FileManager.default.createDirectory(at: incompleteStage, withIntermediateDirectories: false)
        try FileManager.default.removeItem(at: exported.directoryURL)
        #expect(try fixture.store.bundles().isEmpty)
    }

    @Test("Manifest cannot escape the package directory", arguments: ["../audio.wav", "/tmp/audio.wav", "sub/audio.wav"])
    func traversal(filename: String) throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let exported = try fixture.export()
        try fixture.modifyManifest(exported) { $0["audioFile"] = filename }
        #expect(throws: ReadAlongBundleError.unsafePath("package filenames must match the v1 schema")) {
            try ReadAlongBundleStore.load(at: exported.directoryURL)
        }
    }

    @Test("Symlink payloads and symlink package directories are rejected")
    func symlinks() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let exported = try fixture.export()
        try FileManager.default.removeItem(at: exported.audioURL)
        try FileManager.default.createSymbolicLink(at: exported.audioURL, withDestinationURL: fixture.audio)
        #expect(throws: ReadAlongBundleError.unsafePath("audio.wav must be a regular file")) {
            try ReadAlongBundleStore.load(at: exported.directoryURL)
        }
        let aliasRoot = fixture.base.appendingPathComponent("aliases")
        try FileManager.default.createDirectory(at: aliasRoot, withIntermediateDirectories: false)
        let alias = aliasRoot.appendingPathComponent(exported.directoryURL.lastPathComponent)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: exported.directoryURL)
        #expect(throws: ReadAlongBundleError.unsafePath("directories cannot be symbolic links")) {
            try ReadAlongBundleStore.load(at: alias)
        }
    }

    @Test("Timing validation rejects mismatch, omitted text, invalid ranges and duration overflow")
    func invalidTimingCases() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let first = fixture.words[0]
        let tail: [ReadAlongWord] = Array(fixture.words.dropFirst())
        let invalidSets: [[ReadAlongWord]] = [
            [ReadAlongWord(word: "wrong", startMilliseconds: 0, endMilliseconds: 100, utf16Start: 0, utf16End: 5)] + tail,
            tail,
            [ReadAlongWord(word: first.word, startMilliseconds: -1, endMilliseconds: 100, utf16Start: 0, utf16End: 5)] + tail,
            [ReadAlongWord(word: first.word, startMilliseconds: 0, endMilliseconds: 1002, utf16Start: 0, utf16End: 5)] + tail,
            [ReadAlongWord(word: first.word, startMilliseconds: 0, endMilliseconds: 0, utf16Start: 0, utf16End: 5)] + tail,
            [ReadAlongWord(word: first.word, startMilliseconds: 0, endMilliseconds: 100, utf16Start: 0, utf16End: Int.max)] + tail
        ]
        for words in invalidSets {
            #expect(throws: (any Error).self) { try fixture.export(words: words) }
        }
        #expect(try fixture.store.bundles().isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.store.rootURL.path).isEmpty)
    }

    @Test("Nondecreasing VAD word starts may overlap and a one-millisecond rounding margin is accepted")
    func overlappingMeasuredWords() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        var words = fixture.words
        let first = words[0]
        words[0] = ReadAlongWord(word: first.word, startMilliseconds: 0, endMilliseconds: 250,
                                 utf16Start: first.utf16Start, utf16End: first.utf16End)
        let last = words[words.count - 1]
        words[words.count - 1] = ReadAlongWord(word: last.word, startMilliseconds: last.startMilliseconds,
                                               endMilliseconds: 1001, utf16Start: last.utf16Start,
                                               utf16End: last.utf16End)
        let bundle = try fixture.export(words: words)
        #expect(bundle.words == words)
    }

    @Test("Fractional and whole-second ISO timestamps are both accepted")
    func timestampCompatibility() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let exported = try fixture.export()
        try fixture.modifyManifest(exported) { $0["createdAt"] = "2026-10-07T12:00:00Z" }
        #expect(try ReadAlongBundleStore.load(at: exported.directoryURL).manifest.createdAt.timeIntervalSince1970 == 1_791_374_400)
        try fixture.modifyManifest(exported) { $0["createdAt"] = "2026-10-07T12:00:00.123Z" }
        #expect(abs(try ReadAlongBundleStore.load(at: exported.directoryURL).manifest.createdAt.timeIntervalSince1970 - 1_791_374_400.123) < 0.001)
    }

    @Test("A malformed UTF-16 surrogate range cannot be imported")
    func malformedUnicodeRange() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let exported = try fixture.export()
        var words = fixture.words
        let emoji = words[2]
        words[2] = ReadAlongWord(word: emoji.word, startMilliseconds: emoji.startMilliseconds,
                                 endMilliseconds: emoji.endMilliseconds,
                                 utf16Start: emoji.utf16Start, utf16End: emoji.utf16Start + 1)
        let bytes = try JSONEncoder().encode(words)
        try bytes.write(to: exported.directoryURL.appendingPathComponent("timing.json"))
        try fixture.modifyManifest(exported) {
            var hashes = $0["hashes"] as! [String: Any]
            hashes["timing"] = digest(bytes)
            $0["hashes"] = hashes
        }
        #expect(throws: ReadAlongBundleError.invalidTimings("word 2 does not match its source UTF-16 range")) {
            try ReadAlongBundleStore.load(at: exported.directoryURL)
        }
    }

    @Test("Canonically equivalent spelling still must match the exact source UTF-16 units")
    func exactUnicodeSpelling() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        var words = fixture.words
        let accent = words[1]
        words[1] = ReadAlongWord(word: "cafe\u{301}", startMilliseconds: accent.startMilliseconds,
                                 endMilliseconds: accent.endMilliseconds,
                                 utf16Start: accent.utf16Start, utf16End: accent.utf16End)
        #expect(throws: ReadAlongBundleError.invalidTimings("word 1 does not match its source UTF-16 range")) {
            try fixture.export(words: words)
        }
    }

    @Test("Unplayable audio and false duration cannot become completed bundles")
    func playableMediaValidation() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let exported = try fixture.export()
        for duration in [0.1, 3.0] {
            try fixture.modifyManifest(exported) { $0["durationSeconds"] = duration }
            #expect(throws: ReadAlongBundleError.invalidManifest("declared duration does not match playable audio")) {
                try ReadAlongBundleStore.load(at: exported.directoryURL)
            }
        }
        try Data("this is not audio".utf8).write(to: fixture.audio)
        #expect(throws: ReadAlongBundleError.invalidManifest("audio is not a readable WAV or MP3")) {
            try fixture.export()
        }
    }

    @Test("Equivalent timing JSON from another publisher reuses existing immutable bytes")
    func semanticTimingDuplicate() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let original = try fixture.export()
        let manifestBytes = try Data(contentsOf: original.directoryURL.appendingPathComponent("manifest.json"))
        let otherStore = ReadAlongBundleStore(rootURL: fixture.base.appendingPathComponent("otherPublisher"))
        let other = try otherStore.importBundle(at: original.directoryURL)
        let alternate = try JSONEncoder().encode(fixture.words) + Data("\n".utf8)
        try alternate.write(to: other.directoryURL.appendingPathComponent("timing.json"))
        try fixture.modifyManifest(other) {
            var hashes = $0["hashes"] as! [String: Any]
            hashes["timing"] = digest(alternate)
            $0["hashes"] = hashes
        }
        let reused = try fixture.store.importBundle(at: other.directoryURL)
        #expect(reused.directoryURL == original.directoryURL)
        #expect(try Data(contentsOf: original.directoryURL.appendingPathComponent("manifest.json")) == manifestBytes)
        #expect(reused.manifest.hashes.timing != digest(alternate))
    }

    @Test("Independent synthetic Python and TypeScript fixtures cross the Swift boundary",
          .enabled(if: ProcessInfo.processInfo.environment["READALONG_CONTRACT_FIXTURES"] != nil))
    func publisherContractFixtures() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let fixtureRoot = URL(fileURLWithPath: ProcessInfo.processInfo.environment["READALONG_CONTRACT_FIXTURES"]!)
        var count = 0
        for publisher in ["python", "typescript"] {
            let packages = try FileManager.default.contentsOfDirectory(at: fixtureRoot.appendingPathComponent(publisher),
                                                                       includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "readalong" }
            #expect(!packages.isEmpty)
            for package in packages {
                let external = try ReadAlongBundleStore.load(at: package)
                let imported = try fixture.store.importBundle(at: package)
                let reexported = try fixture.store.export(title: external.manifest.title,
                                                          text: external.text, audioURL: external.audioURL,
                                                          durationSeconds: external.manifest.durationSeconds,
                                                          words: external.words,
                                                          timingFidelity: external.manifest.timingFidelity,
                                                          createdAt: external.manifest.createdAt)
                #expect(imported.manifest.id == external.manifest.id)
                #expect(reexported.directoryURL == imported.directoryURL)
                #expect(imported.text == "😀 Hello café world.")
                #expect(imported.words.first?.utf16Start == 3)
                count += 1
            }
        }
        #expect(count >= 2)
    }
}

private struct Fixture {
    let base: URL
    let store: ReadAlongBundleStore
    let audio: URL
    let text = "Hello café 👩🏽‍💻 世界.\nAgain!"
    let words: [ReadAlongWord]

    init() throws {
        base = FileManager.default.temporaryDirectory.appendingPathComponent("ReadAlongKitTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: false)
        store = ReadAlongBundleStore(rootURL: base.appendingPathComponent("mac"))
        audio = base.appendingPathComponent("original.wav")
        // Valid mono 16-bit PCM WAV, one second at 8kHz.
        var wav = Data("RIFF".utf8)
        wav.append(littleEndian(UInt32(16_036)))
        wav.append(Data("WAVEfmt ".utf8))
        wav.append(littleEndian(UInt32(16)))
        wav.append(littleEndian(UInt16(1)))
        wav.append(littleEndian(UInt16(1)))
        wav.append(littleEndian(UInt32(8_000)))
        wav.append(littleEndian(UInt32(16_000)))
        wav.append(littleEndian(UInt16(2)))
        wav.append(littleEndian(UInt16(16)))
        wav.append(Data("data".utf8))
        wav.append(littleEndian(UInt32(16_000)))
        wav.append(Data(repeating: 0, count: 16_000))
        try wav.write(to: audio)
        let source = text as NSString
        var offset = 0
        words = ["Hello", "café", "👩🏽‍💻", "世界", "Again"].enumerated().map { index, word in
            let range = source.range(of: word, range: NSRange(location: offset, length: source.length - offset))
            offset = range.location + range.length
            return ReadAlongWord(word: word, startMilliseconds: index * 160,
                                 endMilliseconds: (index + 1) * 160,
                                 utf16Start: range.location, utf16End: range.location + range.length)
        }
    }

    func export(words: [ReadAlongWord]? = nil) throws -> ReadAlongBundle {
        try store.export(title: "Morning train", text: text, audioURL: audio, durationSeconds: 1,
                         words: words ?? self.words, timingFidelity: .estimated,
                         createdAt: Date(timeIntervalSince1970: 1_791_374_400))
    }

    func modifyManifest(_ bundle: ReadAlongBundle, mutation: (inout [String: Any]) -> Void) throws {
        let url = bundle.directoryURL.appendingPathComponent("manifest.json")
        var json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        mutation(&json)
        try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]).write(to: url)
    }

    func remove() { try? FileManager.default.removeItem(at: base) }
}

private func digest(_ bytes: Data) -> String {
    SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
}

private func littleEndian<T: FixedWidthInteger>(_ value: T) -> Data {
    var value = value.littleEndian
    return withUnsafeBytes(of: &value) { Data($0) }
}
