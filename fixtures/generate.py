"""Write a synthetic v1 package without a speech provider or private library."""
from pathlib import Path
import hashlib
import json
import struct
import sys

root = Path(sys.argv[1])
text = "😀 Hello café world.".encode("utf-8")
audio = (b"RIFF" + struct.pack("<I", 16036) + b"WAVEfmt " + struct.pack("<IHHIIHH", 16, 1, 1, 8000, 16000, 2, 16) + b"data" + struct.pack("<I", 16000) + bytes(16000))
words = [
    dict(word="Hello", startMilliseconds=0, endMilliseconds=220, utf16Start=3, utf16End=8),
    dict(word="café", startMilliseconds=250, endMilliseconds=500, utf16Start=9, utf16End=13),
    dict(word="world", startMilliseconds=550, endMilliseconds=800, utf16Start=14, utf16End=19),
]
timing = json.dumps(words, ensure_ascii=False).encode("utf-8")
digest = lambda data: hashlib.sha256(data).hexdigest()
identity = digest(text + audio)
package = root / (identity + ".readalong")
package.mkdir(parents=True, exist_ok=True)
manifest = dict(schemaVersion="readalong.bundle.v1", id=identity, title="Synthetic contract example", createdAt="2026-10-10T00:00:00Z", audioFile="audio.wav", durationSeconds=1, timingFidelity="estimated", textFile="text.txt", timingFile="timing.json", hashes=dict(text=digest(text), audio=digest(audio), timing=digest(timing)))
for name, data in [("text.txt", text), ("audio.wav", audio), ("timing.json", timing), ("manifest.json", json.dumps(manifest, ensure_ascii=False).encode("utf-8"))]:
    (package / name).write_bytes(data)
print(package)
