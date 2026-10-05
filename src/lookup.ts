import type { TokenTiming } from './types.ts';

export function activeTokenIndex(
  tokens: readonly TokenTiming[],
  currentMs: number,
): number {
  let low = 0;
  let high = tokens.length - 1;
  let candidate = -1;

  while (low <= high) {
    const middle = Math.floor((low + high) / 2);
    const token = tokens[middle]!;
    if (token.start_ms <= currentMs) {
      candidate = middle;
      low = middle + 1;
    } else {
      high = middle - 1;
    }
  }

  if (candidate < 0 || currentMs >= tokens[candidate]!.end_ms) {
    return -1;
  }
  return candidate;
}
