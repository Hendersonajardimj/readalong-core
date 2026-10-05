export const NORMALIZER_VERSION = 'readalong.spoken-text.v1' as const;

export type NormalizedScript = {
  text: string;
  outputToScript: number[];
};

type Unit = {
  value: string;
  sourceIndex: number;
};

function pushValue(units: Unit[], value: string, sourceIndex: number): void {
  for (let offset = 0; offset < value.length; offset += 1) {
    units.push({ value: value[offset]!, sourceIndex: sourceIndex + offset });
  }
}

export function normalizeScript(script: string): NormalizedScript {
  const normalizedNewlines: Unit[] = [];
  for (let index = 0; index < script.length; index += 1) {
    const value = script[index]!;
    if (value === '\r') {
      if (script[index + 1] === '\n') {
        index += 1;
      }
      normalizedNewlines.push({ value: '\n', sourceIndex: index });
      continue;
    }
    pushValue(normalizedNewlines, value, index);
  }

  const output: Unit[] = [];
  let pendingHorizontal: Unit | undefined;
  let pendingNewline: Unit | undefined;
  let newlineCount = 0;

  const flushWhitespace = (): void => {
    if (newlineCount > 0 && pendingNewline) {
      if (output.length > 0) {
        output.push({ value: '\n', sourceIndex: pendingNewline.sourceIndex });
        if (newlineCount > 1) {
          output.push({
            value: '\n',
            sourceIndex: pendingNewline.sourceIndex,
          });
        }
      }
    } else if (pendingHorizontal && output.length > 0) {
      output.push({ value: ' ', sourceIndex: pendingHorizontal.sourceIndex });
    }
    pendingHorizontal = undefined;
    pendingNewline = undefined;
    newlineCount = 0;
  };

  for (const unit of normalizedNewlines) {
    if (unit.value === '\n') {
      pendingNewline ??= unit;
      newlineCount += 1;
      pendingHorizontal = undefined;
      continue;
    }
    if (/\s/u.test(unit.value)) {
      pendingHorizontal ??= unit;
      continue;
    }
    flushWhitespace();
    output.push(unit);
  }

  while (
    output.length > 0 &&
    (output.at(-1)?.value === ' ' || output.at(-1)?.value === '\n')
  ) {
    output.pop();
  }

  return {
    text: output.map((unit) => unit.value).join(''),
    outputToScript: output.map((unit) => unit.sourceIndex),
  };
}
