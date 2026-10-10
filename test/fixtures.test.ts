import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readdirSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';

test('independent Python and TypeScript fixtures agree on content, exact UTF-16 ranges and playable WAV structure', () => {
  const directory = mkdtempSync(join(tmpdir(), 'readalong-fixtures-'));
  const digest = (bytes: Uint8Array) => createHash('sha256').update(bytes).digest('hex');
  try {
    execFileSync('python3', ['fixtures/generate.py', join(directory, 'python')]);
    execFileSync(process.execPath, ['fixtures/generate.ts', join(directory, 'typescript')]);
    const results = ['python', 'typescript'].map(publisher => {
      const [name] = readdirSync(join(directory, publisher));
      const packageDirectory = join(directory, publisher, name);
      const read = (file: string) => readFileSync(join(packageDirectory, file));
      const manifest = JSON.parse(read('manifest.json').toString());
      const text = read('text.txt'), timing = read('timing.json'), audio = read('audio.wav');
      assert.equal(name, `${manifest.id}.readalong`);
      assert.equal(manifest.id, digest(Buffer.concat([text, audio])));
      for (const [kind, bytes] of Object.entries({text, timing, audio})) assert.equal(manifest.hashes[kind], digest(bytes));
      assert.equal(audio.subarray(0, 4).toString(), 'RIFF');
      assert.equal(audio.subarray(8, 16).toString(), 'WAVEfmt ');
      assert.equal(audio.readUInt32LE(4) + 8, audio.length);
      assert.equal(audio.readUInt32LE(40), audio.length - 44);
      const duration = audio.readUInt32LE(40) / audio.readUInt32LE(28);
      assert.equal(duration, manifest.durationSeconds);
      const words = JSON.parse(timing.toString());
      for (const word of words) {
        assert.equal(text.toString().slice(word.utf16Start, word.utf16End), word.word);
        assert.ok(word.endMilliseconds > word.startMilliseconds && word.endMilliseconds <= duration * 1000);
      }
      return {id: manifest.id, text: text.toString(), words};
    });
    assert.deepEqual(results[0], results[1]);
  } finally { rmSync(directory, {recursive: true, force: true}); }
});
