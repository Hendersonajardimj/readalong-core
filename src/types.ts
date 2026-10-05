// Structure adapted from the existing Readalong tokenTimingSchema.
// This type does not validate data at runtime.
export type TokenTiming = {
  id: number;
  text: string;
  start_ms: number;
  end_ms: number;
  synthesis_range: { start: number; end: number };
  script_range: { start: number; end: number } | null;
};
