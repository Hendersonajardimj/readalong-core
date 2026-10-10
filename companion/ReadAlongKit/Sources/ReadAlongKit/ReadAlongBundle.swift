import Foundation
import CryptoKit
import Darwin
import AVFoundation

public enum ReadAlongTimingFidelity: String, Codable, Sendable {
    case estimated
    case measured
}

/// A word's source-text range uses UTF-16 offsets, with an exclusive end.
public struct ReadAlongWord: Codable, Equatable, Sendable {
    public let word: String
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let utf16Start: Int
    public let utf16End: Int

    public init(word: String, startMilliseconds: Int, endMilliseconds: Int,
                utf16Start: Int, utf16End: Int) {
        self.word = word
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = endMilliseconds
        self.utf16Start = utf16Start
        self.utf16End = utf16End
    }
}

public struct ReadAlongHashes: Codable, Equatable, Sendable {
    public let text: String
    public let audio: String
    public let timing: String

    public init(text: String, audio: String, timing: String) {
        self.text = text
        self.audio = audio
        self.timing = timing
    }
}

public struct ReadAlongManifest: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = "readalong.bundle.v1"
    public let schemaVersion: String
    public let id: String
    public let title: String
    public let createdAt: Date
    public let audioFile: String
    public let durationSeconds: Double
    public let timingFidelity: ReadAlongTimingFidelity
    public let textFile: String
    public let timingFile: String
    public let hashes: ReadAlongHashes

    public init(schemaVersion: String = Self.currentSchemaVersion, id: String, title: String,
                createdAt: Date, audioFile: String, durationSeconds: Double,
                timingFidelity: ReadAlongTimingFidelity, textFile: String = "text.txt",
                timingFile: String = "timing.json", hashes: ReadAlongHashes) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.audioFile = audioFile
        self.durationSeconds = durationSeconds
        self.timingFidelity = timingFidelity
        self.textFile = textFile
        self.timingFile = timingFile
        self.hashes = hashes
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, title, createdAt, audioFile, durationSeconds
        case timingFidelity, textFile, timingFile, hashes
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(String.self, forKey: .schemaVersion)
        id = try values.decode(String.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        let timestamp = try values.decode(String.self, forKey: .createdAt)
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = fractional.date(from: timestamp) ?? ISO8601DateFormatter().date(from: timestamp) else {
            throw ReadAlongBundleError.invalidManifest("createdAt must be an ISO 8601 timestamp")
        }
        createdAt = date
        audioFile = try values.decode(String.self, forKey: .audioFile)
        durationSeconds = try values.decode(Double.self, forKey: .durationSeconds)
        timingFidelity = try values.decode(ReadAlongTimingFidelity.self, forKey: .timingFidelity)
        textFile = try values.decode(String.self, forKey: .textFile)
        timingFile = try values.decode(String.self, forKey: .timingFile)
        hashes = try values.decode(ReadAlongHashes.self, forKey: .hashes)
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(schemaVersion, forKey: .schemaVersion)
        try values.encode(id, forKey: .id)
        try values.encode(title, forKey: .title)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try values.encode(formatter.string(from: createdAt), forKey: .createdAt)
        try values.encode(audioFile, forKey: .audioFile)
        try values.encode(durationSeconds, forKey: .durationSeconds)
        try values.encode(timingFidelity, forKey: .timingFidelity)
        try values.encode(textFile, forKey: .textFile)
        try values.encode(timingFile, forKey: .timingFile)
        try values.encode(hashes, forKey: .hashes)
    }
}

/// A validated snapshot. Playback always uses the audio inside this directory.
public struct ReadAlongBundle: Sendable {
    public let directoryURL: URL
    public let manifest: ReadAlongManifest
    public let text: String
    public let words: [ReadAlongWord]
    public var audioURL: URL { directoryURL.appendingPathComponent(manifest.audioFile) }
}

public enum ReadAlongBundleError: LocalizedError, Equatable, Sendable {
    case invalidManifest(String)
    case unsafePath(String)
    case incompleteBundle(String)
    case hashMismatch(String)
    case invalidTimings(String)
    case duplicateBundleConflict(String)

    public var errorDescription: String? {
        switch self {
        case .invalidManifest(let detail): "Invalid Read Along manifest: \(detail)."
        case .unsafePath(let detail): "Unsafe Read Along package path: \(detail)."
        case .incompleteBundle(let detail): "Incomplete Read Along package: \(detail)."
        case .hashMismatch(let detail): "Read Along package failed its integrity check: \(detail)."
        case .invalidTimings(let detail): "Invalid Read Along word timings: \(detail)."
        case .duplicateBundleConflict(let id): "An immutable Read Along package already exists with different timings: \(id)."
        }
    }
}

/// Exports and imports completed experiences by committing a validated staging
/// directory with one rename. Existing packages are never overwritten.
public struct ReadAlongBundleStore: Sendable {
    public let rootURL: URL

    public init(rootURL: URL) {
        self.rootURL = rootURL.standardizedFileURL
    }

    public func export(title: String, text: String, audioURL: URL, durationSeconds: Double,
                       words: [ReadAlongWord], timingFidelity: ReadAlongTimingFidelity,
                       createdAt: Date = Date()) throws -> ReadAlongBundle {
        try Self.checkDirectory(rootURL, create: true)
        let fileExtension = audioURL.pathExtension.lowercased()
        guard ["wav", "mp3"].contains(fileExtension) else {
            throw ReadAlongBundleError.invalidManifest("audio must be WAV or MP3")
        }
        try Self.checkRegularFile(audioURL)
        let stage = rootURL.appendingPathComponent(".incoming-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: stage) }
        let textBytes = Data(text.utf8)
        let timingBytes = try Self.encoder().encode(words)
        try textBytes.write(to: stage.appendingPathComponent("text.txt"), options: .atomic)
        try timingBytes.write(to: stage.appendingPathComponent("timing.json"), options: .atomic)
        let audioFile = "audio.\(fileExtension)"
        let stagedAudio = stage.appendingPathComponent(audioFile)
        try FileManager.default.copyItem(at: audioURL, to: stagedAudio)
        let audioDigests = try Self.audioDigests(at: stagedAudio, textBytes: textBytes)
        let manifest = ReadAlongManifest(id: audioDigests.id, title: title, createdAt: createdAt,
                                         audioFile: audioFile, durationSeconds: durationSeconds,
                                         timingFidelity: timingFidelity,
                                         hashes: .init(text: Self.sha256(textBytes),
                                                       audio: audioDigests.audio,
                                                       timing: Self.sha256(timingBytes)))
        try Self.encoder().encode(manifest).write(to: stage.appendingPathComponent("manifest.json"), options: .atomic)
        let validated = try Self.load(at: stage, requireCanonicalName: false)
        return try commit(stage: stage, validated: validated)
    }

    /// Copies to local storage before returning. It never plays an iCloud or
    /// Files-provider source in place; an interrupted copy stays invisible.
    public func importBundle(at sourceURL: URL) throws -> ReadAlongBundle {
        let source = try Self.load(at: sourceURL)
        try Self.checkDirectory(rootURL, create: true)
        let destination = rootURL.appendingPathComponent("\(source.manifest.id).readalong", isDirectory: true)
        if source.directoryURL.standardizedFileURL == destination.standardizedFileURL { return source }
        let stage = rootURL.appendingPathComponent(".incoming-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: stage) }
        for name in ["manifest.json", "text.txt", "timing.json", source.manifest.audioFile] {
            try FileManager.default.copyItem(at: source.directoryURL.appendingPathComponent(name),
                                             to: stage.appendingPathComponent(name))
        }
        let validated = try Self.load(at: stage, requireCanonicalName: false)
        return try commit(stage: stage, validated: validated)
    }

    /// Enumerates only committed packages. A corrupt package is reported, never
    /// treated as playable; callers may load individually to isolate bad entries.
    public func bundles() throws -> [ReadAlongBundle] {
        if !FileManager.default.fileExists(atPath: rootURL.path) { return [] }
        try Self.checkDirectory(rootURL, create: false)
        let urls = try FileManager.default.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "readalong" }
        return try urls.map { try Self.load(at: $0) }
            .sorted { $0.manifest.createdAt > $1.manifest.createdAt }
    }

    public static func load(at directoryURL: URL) throws -> ReadAlongBundle {
        try load(at: directoryURL, requireCanonicalName: true)
    }

    private func commit(stage: URL, validated: ReadAlongBundle) throws -> ReadAlongBundle {
        let destination = rootURL.appendingPathComponent("\(validated.manifest.id).readalong", isDirectory: true)
        if FileManager.default.fileExists(atPath: destination.path) {
            return try existingBundle(at: destination, matching: validated)
        }
        do {
            try FileManager.default.moveItem(at: stage, to: destination)
        } catch {
            // Another exporter may have committed the same immutable ID.
            if FileManager.default.fileExists(atPath: destination.path) {
                return try existingBundle(at: destination, matching: validated)
            }
            throw error
        }
        return try Self.load(at: destination)
    }

    private func existingBundle(at url: URL, matching candidate: ReadAlongBundle) throws -> ReadAlongBundle {
        let existing = try Self.load(at: url)
        guard existing.manifest.hashes.text == candidate.manifest.hashes.text,
              existing.manifest.hashes.audio == candidate.manifest.hashes.audio,
              existing.words == candidate.words,
              existing.manifest.audioFile == candidate.manifest.audioFile,
              abs(existing.manifest.durationSeconds - candidate.manifest.durationSeconds) <= 0.25,
              existing.manifest.timingFidelity == candidate.manifest.timingFidelity else {
            throw ReadAlongBundleError.duplicateBundleConflict(candidate.manifest.id)
        }
        return existing
    }

    private static func load(at directoryURL: URL, requireCanonicalName: Bool) throws -> ReadAlongBundle {
        let directory = directoryURL.standardizedFileURL
        try checkDirectory(directory, create: false)
        let manifestBytes = try readRegularFile(directory.appendingPathComponent("manifest.json"), limit: 64 * 1024)
        let manifest: ReadAlongManifest
        do { manifest = try JSONDecoder().decode(ReadAlongManifest.self, from: manifestBytes) }
        catch let error as ReadAlongBundleError { throw error }
        catch { throw ReadAlongBundleError.invalidManifest("manifest.json could not be decoded") }
        guard manifest.schemaVersion == ReadAlongManifest.currentSchemaVersion else {
            throw ReadAlongBundleError.invalidManifest("unsupported schema version \(manifest.schemaVersion)")
        }
        guard isDigest(manifest.id), isDigest(manifest.hashes.text),
              isDigest(manifest.hashes.audio), isDigest(manifest.hashes.timing) else {
            throw ReadAlongBundleError.invalidManifest("IDs and hashes must be lowercase SHA-256 hex")
        }
        guard manifest.textFile == "text.txt", manifest.timingFile == "timing.json",
              ["audio.wav", "audio.mp3"].contains(manifest.audioFile) else {
            throw ReadAlongBundleError.unsafePath("package filenames must match the v1 schema")
        }
        if requireCanonicalName && directory.lastPathComponent != "\(manifest.id).readalong" {
            throw ReadAlongBundleError.unsafePath("package directory must be named \(manifest.id).readalong")
        }
        guard !manifest.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              manifest.createdAt.timeIntervalSince1970.isFinite,
              manifest.durationSeconds.isFinite, manifest.durationSeconds > 0,
              manifest.durationSeconds * 1000 < Double(Int.max - 2) else {
            throw ReadAlongBundleError.invalidManifest("title, timestamp and positive finite duration are required")
        }
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        let expected = Set(["manifest.json", "text.txt", "timing.json", manifest.audioFile])
        guard Set(names) == expected else {
            throw ReadAlongBundleError.incompleteBundle("expected exactly manifest, text, timings and audio")
        }
        let textBytes = try readRegularFile(directory.appendingPathComponent(manifest.textFile), limit: 32 * 1024 * 1024)
        let timingBytes = try readRegularFile(directory.appendingPathComponent(manifest.timingFile), limit: 64 * 1024 * 1024)
        guard sha256(textBytes) == manifest.hashes.text else { throw ReadAlongBundleError.hashMismatch("text.txt") }
        guard sha256(timingBytes) == manifest.hashes.timing else { throw ReadAlongBundleError.hashMismatch("timing.json") }
        let digests = try audioDigests(at: directory.appendingPathComponent(manifest.audioFile), textBytes: textBytes)
        guard digests.audio == manifest.hashes.audio else { throw ReadAlongBundleError.hashMismatch(manifest.audioFile) }
        guard digests.id == manifest.id else { throw ReadAlongBundleError.hashMismatch("content ID") }
        let audioDuration = try decodedDuration(at: directory.appendingPathComponent(manifest.audioFile))
        guard abs(audioDuration - manifest.durationSeconds) <= 0.25 else {
            throw ReadAlongBundleError.invalidManifest("declared duration does not match playable audio")
        }
        guard let text = String(data: textBytes, encoding: .utf8), !text.isEmpty else {
            throw ReadAlongBundleError.invalidManifest("text.txt must contain nonempty UTF-8 text")
        }
        let words: [ReadAlongWord]
        do { words = try JSONDecoder().decode([ReadAlongWord].self, from: timingBytes) }
        catch { throw ReadAlongBundleError.invalidTimings("timing.json could not be decoded") }
        try validate(words: words, text: text, durationSeconds: manifest.durationSeconds, audioDuration: audioDuration)
        return ReadAlongBundle(directoryURL: directory, manifest: manifest, text: text, words: words)
    }

    private static func validate(words: [ReadAlongWord], text: String, durationSeconds: Double, audioDuration: Double) throws {
        guard !words.isEmpty else { throw ReadAlongBundleError.invalidTimings("at least one word is required") }
        let textLength = text.utf16.count
        let durationLimit = Int(ceil(durationSeconds * 1000)) + 1
        // MP3 frame padding and decoder delay can differ from browser duration
        // estimates. Both declared and decoded media bounds still apply.
        let audioLimit = Int(ceil((audioDuration + 0.25) * 1000))
        var previousTime = 0
        var previousOffset = 0
        let lexical = CharacterSet.letters.union(.decimalDigits)
        for (index, word) in words.enumerated() {
            guard !word.word.isEmpty, word.startMilliseconds >= previousTime,
                  word.endMilliseconds > word.startMilliseconds,
                  word.endMilliseconds <= durationLimit, word.endMilliseconds <= audioLimit else {
                throw ReadAlongBundleError.invalidTimings("word \(index) is unordered or outside the audio duration")
            }
            guard word.utf16Start >= previousOffset, word.utf16End > word.utf16Start,
                  word.utf16End <= textLength,
                  let range = Range(NSRange(location: word.utf16Start, length: word.utf16End - word.utf16Start), in: text),
                  text[range].utf16.elementsEqual(word.word.utf16) else {
                throw ReadAlongBundleError.invalidTimings("word \(index) does not match its source UTF-16 range")
            }
            guard let gap = Range(NSRange(location: previousOffset, length: word.utf16Start - previousOffset), in: text),
                  !text[gap].unicodeScalars.contains(where: { lexical.contains($0) }) else {
                throw ReadAlongBundleError.invalidTimings("word \(index) skips source text")
            }
            previousTime = word.startMilliseconds
            previousOffset = word.utf16End
        }
        guard let tail = Range(NSRange(location: previousOffset, length: textLength - previousOffset), in: text),
              !text[tail].unicodeScalars.contains(where: { lexical.contains($0) }) else {
            throw ReadAlongBundleError.invalidTimings("timings omit the end of the source text")
        }
    }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        return encoder
    }

    private static func decodedDuration(at url: URL) throws -> Double {
        try checkRegularFile(url)
        let audio: AVAudioFile
        do { audio = try AVAudioFile(forReading: url) }
        catch { throw ReadAlongBundleError.invalidManifest("audio is not a readable WAV or MP3") }
        let sampleRate = audio.fileFormat.sampleRate
        let duration = Double(audio.length) / sampleRate
        guard sampleRate.isFinite, sampleRate > 0, audio.fileFormat.channelCount > 0,
              audio.length > 0, duration.isFinite, duration > 0,
              duration * 1000 < Double(Int.max - 250) else {
            throw ReadAlongBundleError.invalidManifest("audio has no playable duration")
        }
        return duration
    }

    private static func checkDirectory(_ url: URL, create: Bool) throws {
        guard url.isFileURL else { throw ReadAlongBundleError.unsafePath("a local file URL is required") }
        if create && !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        let values: URLResourceValues
        do { values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) }
        catch { throw ReadAlongBundleError.incompleteBundle("package directory is unavailable") }
        guard values.isSymbolicLink != true, values.isDirectory == true else {
            throw ReadAlongBundleError.unsafePath("directories cannot be symbolic links")
        }
    }

    private static func checkRegularFile(_ url: URL) throws {
        guard url.isFileURL else { throw ReadAlongBundleError.unsafePath("a local file URL is required") }
        let values: URLResourceValues
        do { values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]) }
        catch { throw ReadAlongBundleError.incompleteBundle("\(url.lastPathComponent) is unavailable") }
        guard values.isSymbolicLink != true, values.isRegularFile == true else {
            throw ReadAlongBundleError.unsafePath("\(url.lastPathComponent) must be a regular file")
        }
    }

    private static func openRegularFile(_ url: URL) throws -> FileHandle {
        try checkRegularFile(url)
        let descriptor = url.withUnsafeFileSystemRepresentation { pointer in
            pointer.map { Darwin.open($0, O_RDONLY | O_NOFOLLOW | O_CLOEXEC) } ?? -1
        }
        guard descriptor >= 0 else { throw ReadAlongBundleError.unsafePath("cannot open \(url.lastPathComponent)") }
        var info = stat()
        guard fstat(descriptor, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else {
            Darwin.close(descriptor)
            throw ReadAlongBundleError.unsafePath("\(url.lastPathComponent) is not a regular file")
        }
        return FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    }

    private static func readRegularFile(_ url: URL, limit: Int) throws -> Data {
        let file = try openRegularFile(url)
        defer { try? file.close() }
        var bytes = Data()
        while let chunk = try file.read(upToCount: min(64 * 1024, limit + 1 - bytes.count)), !chunk.isEmpty {
            bytes.append(chunk)
            guard bytes.count <= limit else { throw ReadAlongBundleError.invalidManifest("\(url.lastPathComponent) exceeds the size limit") }
        }
        return bytes
    }

    private static func audioDigests(at url: URL, textBytes: Data) throws -> (audio: String, id: String) {
        let file = try openRegularFile(url)
        defer { try? file.close() }
        var audio = SHA256()
        var identity = SHA256()
        identity.update(data: textBytes)
        var byteCount = 0
        while let chunk = try file.read(upToCount: 1024 * 1024), !chunk.isEmpty {
            audio.update(data: chunk)
            identity.update(data: chunk)
            byteCount += chunk.count
        }
        guard byteCount > 0 else { throw ReadAlongBundleError.incompleteBundle("audio file is empty") }
        return (hex(audio.finalize()), hex(identity.finalize()))
    }

    private static func sha256(_ data: Data) -> String { hex(SHA256.hash(data: data)) }
    private static func hex(_ digest: SHA256.Digest) -> String { digest.map { String(format: "%02x", $0) }.joined() }
    private static func isDigest(_ string: String) -> Bool {
        string.utf8.count == 64 && string.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
}
