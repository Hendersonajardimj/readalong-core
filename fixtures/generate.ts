// An independent synthetic publisher: this is not the full private web exporter.
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { createHash } from 'node:crypto';

const root = process.argv[2];
if (!root) throw new Error('Pass a fixture output directory.');
const text = Buffer.from('😀 Hello café world.', 'utf8');
const audio = Buffer.alloc(16044);
audio.write('RIFF', 0); audio.writeUInt32LE(16036, 4); audio.write('WAVEfmt ', 8);
audio.writeUInt32LE(16, 16); audio.writeUInt16LE(1, 20); audio.writeUInt16LE(1, 22);
audio.writeUInt32LE(8000, 24); audio.writeUInt32LE(16000, 28);
audio.writeUInt16LE(2, 32); audio.writeUInt16LE(16, 34);
audio.write('data', 36); audio.writeUInt32LE(16000, 40);
const words = [
  { word: 'Hello', startMilliseconds: 0, endMilliseconds: 220, utf16Start: 3, utf16End: 8 },
  { word: 'café', startMilliseconds: 250, endMilliseconds: 500, utf16Start: 9, utf16End: 13 },
  { word: 'world', startMilliseconds: 550, endMilliseconds: 800, utf16Start: 14, utf16End: 19 },
];
const timing = Buffer.from(JSON.stringify(words));
const digest = (data: Uint8Array) => createHash('sha256').update(data).digest('hex');
const id = digest(Buffer.concat([text, audio]));
const manifest = { schemaVersion: 'readalong.bundle.v1', id, title: 'Synthetic contract example', createdAt: '2026-10-10T00:00:00Z', audioFile: 'audio.wav', durationSeconds: 1, timingFidelity: 'estimated', textFile: 'text.txt', timingFile: 'timing.json', hashes: { text: digest(text), audio: digest(audio), timing: digest(timing) } };
const directory = join(root, `${id}.readalong`);
mkdirSync(directory, { recursive: true });
for (const [name, bytes] of Object.entries({ 'text.txt': text, 'audio.wav': audio, 'timing.json': timing, 'manifest.json': Buffer.from(JSON.stringify(manifest)) })) writeFileSync(join(directory, name), bytes);
console.log(directory);
