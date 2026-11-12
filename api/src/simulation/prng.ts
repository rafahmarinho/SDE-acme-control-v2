/**
 * Deterministic PRNG for simulation noise ONLY (mulberry32). Not cryptographically secure and
 * must never be used for identifiers, tokens, keys or passwords - use node:crypto for those.
 * This directory is the only place where non-cryptographic randomness is allowed.
 */
export function createSimulationRng(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
