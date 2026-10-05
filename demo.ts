import { activeTokenIndex } from './src/lookup.ts';
import { normalizeScript } from './src/normalize.ts';
import type { TokenTiming } from './src/types.ts';

const tokens: TokenTiming[] = [
  { id: 0, text: 'one', start_ms: 100, end_ms: 300,
    synthesis_range: { start: 0, end: 3 }, script_range: { start: 0, end: 3 } },
  { id: 1, text: 'two', start_ms: 350, end_ms: 550,
    synthesis_range: { start: 4, end: 7 }, script_range: { start: 4, end: 7 } },
];

console.log('Audio time -> active word');
for (const time of [0, 100, 299, 300, 350, 549, 550]) {
  const index = activeTokenIndex(tokens, time);
  console.log(`${time}ms -> ${index === -1 ? '(none)' : tokens[index]!.text}`);
}

const script = '  Hello,   world.\r\n\r\n\r\nNext line.  ';
console.log('\nNormalized text and map to original script:');
console.log(JSON.stringify(normalizeScript(script), null, 2));
