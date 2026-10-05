import { test } from 'node:test';
import assert from 'node:assert/strict';
import { activeTokenIndex } from '../src/lookup.ts';
import { normalizeScript } from '../src/normalize.ts';
import type { TokenTiming } from '../src/types.ts';

// Cases adapted from the existing Readalong core tests.
const tokens: TokenTiming[] = [
  { id: 0, text: 'one', start_ms: 100, end_ms: 300,
    synthesis_range: { start: 0, end: 3 }, script_range: { start: 0, end: 3 } },
  { id: 1, text: 'two', start_ms: 350, end_ms: 550,
    synthesis_range: { start: 4, end: 7 }, script_range: { start: 4, end: 7 } },
];

test('lookup includes starts, excludes ends, and leaves gaps inactive', () => {
  for (const [time, expected] of [[99, -1], [100, 0], [299, 0],
    [300, -1], [400, 1], [550, -1]]) {
    assert.equal(activeTokenIndex(tokens, time!), expected);
  }
});

test('normalization reduces whitespace and retains a source map', () => {
  const script = '  Hello,   world.\r\n\r\n\r\nNext line.  ';
  const result = normalizeScript(script);
  assert.equal(result.text, 'Hello, world.\n\nNext line.');
  assert.ok(result.outputToScript.map(index => script[index])
    .filter(Boolean).join('').replace(/\r/g, '\n').includes('Hello, world.'));
});

test('normalization preserves non-BMP UTF-16 code units', () => {
  const script = 'Say 👋🏽 now';
  const result = normalizeScript(script);
  assert.equal(result.text, script);
  assert.equal(result.outputToScript.length, script.length);
  assert.deepEqual(result.outputToScript.slice(4, 8), [4, 5, 6, 7]);
});
