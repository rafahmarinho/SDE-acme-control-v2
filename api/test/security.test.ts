import { afterEach, describe, expect, it } from 'vitest';
import { isPermitted, PERMISSIONS, ROLES } from '../src/auth/permissions.js';
import { REAUTH_MAX_AGE_SECONDS, requireRecentAuth } from '../src/auth/verify.js';
import { checkPumpCommand, checkValveCommand } from '../src/commands/interlocks.js';
import { AttachmentRequestSchema, CommandSchema, sanitizeFileName, SetpointRequestSchema, SimulationRequestSchema } from '../src/commands/schemas.js';
import { redact } from '../src/lib/audit.js';
import { corsHeaders, isAllowedOrigin } from '../src/lib/cors.js';
import { requireHttpsUrl } from '../src/lib/env.js';
import { HttpError, MAX_BODY_BYTES, readJson, route } from '../src/lib/http.js';
import { escapeHtml, renderText } from '../src/lib/templates.js';
import { simulate, type PlantState } from '../src/simulation/engine.js';

const PLANT = '11111111-1111-4111-8111-111111111111';
const EQ = 'a1111111-0000-4000-8000-000000000001';

describe('interlocks', () => {
  const base = { mode: 'manual' as const, inMaintenance: false, sourceLevelPct: 50, sourceLowLimitPct: 5 };
  it('blocks starting a pump on an empty source tank', () => {
    expect(checkPumpCommand({ ...base, sourceLevelPct: 4 }, 'on')).toBe('source_tank_empty');
  });
  it('blocks starting a pump under maintenance', () => {
    expect(checkPumpCommand({ ...base, inMaintenance: true }, 'on')).toBe('equipment_in_maintenance');
  });
  it('always allows stopping a manual pump', () => {
    expect(checkPumpCommand({ ...base, inMaintenance: true, sourceLevelPct: 0 }, 'off')).toBeNull();
  });
  it('rejects manual commands in auto mode', () => {
    expect(checkPumpCommand({ ...base, mode: 'auto' }, 'on')).toBe('equipment_in_auto_mode');
    expect(checkValveCommand({ mode: 'auto', inMaintenance: false })).toBe('equipment_in_auto_mode');
  });
});

describe('simulation', () => {
  it('stops the pump when the source tank reaches its low limit', () => {
    const state: PlantState = {
      tanks: [
        { id: 'a', tag: 'TK-1', capacityM3: 10, levelPct: 6, lowLimitPct: 5, highLimitPct: 95 },
        { id: 'b', tag: 'TK-2', capacityM3: 10, levelPct: 10, lowLimitPct: 5, highLimitPct: 95 },
      ],
      pumps: [{ id: 'p', tag: 'P-1', sourceTankId: 'a', destTankId: 'b', ratedFlowM3h: 100, requestedState: 'on', actualState: 'off', mode: 'manual', inMaintenance: false, flowM3h: 0 }],
      valves: [],
      autoStartPct: 30,
      autoStopPct: 90,
    };
    const next = simulate(state, 20);
    expect(next.tanks[0]!.levelPct).toBeLessThanOrEqual(6);
    expect(next.pumps[0]!.actualState).toBe('off');
    expect(state.tanks[0]!.levelPct).toBe(6); // input not mutated
  });
});

describe('authorization matrix', () => {
  it('only engineers propose and only supervisors review setpoints', () => {
    expect(ROLES.filter((r) => isPermitted(r, 'setpoint.propose'))).toEqual(['engineer']);
    expect(ROLES.filter((r) => isPermitted(r, 'setpoint.review'))).toEqual(['supervisor']);
  });
  it('maintenance cannot operate pumps; operators cannot lock out equipment', () => {
    expect(isPermitted('maintenance', 'pump.toggle')).toBe(false);
    expect(isPermitted('operator', 'equipment.lockout')).toBe(false);
  });
  it('every action has at least one role', () => {
    for (const roles of Object.values(PERMISSIONS)) expect(roles.length).toBeGreaterThan(0);
  });
  it('requires recent authentication for critical actions', () => {
    const now = 1_000_000;
    expect(() => requireRecentAuth({ id: 'u', token: 't', lastAuthAt: now - REAUTH_MAX_AGE_SECONDS - 1 }, now)).toThrow(HttpError);
    expect(() => requireRecentAuth({ id: 'u', token: 't', lastAuthAt: null }, now)).toThrow(HttpError);
    expect(() => requireRecentAuth({ id: 'u', token: 't', lastAuthAt: now - 60 }, now)).not.toThrow();
  });
});

describe('input validation', () => {
  it('rejects unknown command types and extra fields', () => {
    expect(CommandSchema.safeParse({ type: 'shell', plantId: PLANT, equipmentId: EQ }).success).toBe(false);
    expect(CommandSchema.safeParse({ type: 'pump', plantId: PLANT, equipmentId: EQ, state: 'on', role: 'supervisor' }).success).toBe(false);
    expect(CommandSchema.safeParse({ type: 'pump', plantId: PLANT, equipmentId: EQ, state: 'on' }).success).toBe(true);
  });
  it('allow-lists scenarios and bounds simulation steps', () => {
    expect(SimulationRequestSchema.safeParse({ action: 'scenario', plantId: PLANT, scenario: '../../etc/passwd' }).success).toBe(false);
    expect(SimulationRequestSchema.safeParse({ action: 'step', plantId: PLANT, steps: 601 }).success).toBe(false);
    expect(SimulationRequestSchema.safeParse({ action: 'step', plantId: PLANT, steps: 10 }).success).toBe(true);
  });
  it('bounds setpoint reason length', () => {
    expect(SetpointRequestSchema.safeParse({ action: 'propose', plantId: PLANT, setpointId: EQ, value: 1, reason: 'x'.repeat(501) }).success).toBe(false);
  });
  it('accepts only allowed attachment types and sizes, never raw paths', () => {
    expect(AttachmentRequestSchema.safeParse({ action: 'upload_url', plantId: PLANT, fileName: 'a.exe', mime: 'application/x-msdownload', sizeBytes: 10 }).success).toBe(false);
    expect(AttachmentRequestSchema.safeParse({ action: 'download_url', plantId: PLANT, path: `${PLANT}/x` }).success).toBe(false);
    expect(sanitizeFileName('../../config.xml')).toBe('config.xml');
    expect(sanitizeFileName('..\\..\\..')).toBe('file');
  });
});

describe('http hardening', () => {
  it('rejects oversized and non-JSON bodies', async () => {
    const big = new Request('https://api.test/x', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ a: 'x'.repeat(MAX_BODY_BYTES) }) });
    await expect(readJson(big)).rejects.toMatchObject({ status: 413 });
    const form = new Request('https://api.test/x', { method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' }, body: 'a=1' });
    await expect(readJson(form)).rejects.toMatchObject({ status: 415 });
  });
  it('returns 405 for unsupported methods and generic errors without internals', async () => {
    const handler = route({
      POST: async () => {
        throw new Error('relation "secret_table" does not exist');
      },
    });
    const get = await handler(new Request('https://api.test/x', { method: 'GET' }));
    expect(get.status).toBe(405);
    const post = await handler(new Request('https://api.test/x', { method: 'POST' }));
    expect(post.status).toBe(500);
    const body = await post.text();
    expect(body).not.toContain('secret_table');
    expect(post.headers.get('X-Frame-Options')).toBe('DENY');
    expect(post.headers.get('Cache-Control')).toBe('no-store');
  });
});

describe('cors', () => {
  afterEach(() => {
    delete process.env.ALLOWED_ORIGINS;
  });
  it('allows only exact listed origins and never wildcards', () => {
    process.env.ALLOWED_ORIGINS = 'https://app.example.com,*';
    expect(isAllowedOrigin('https://app.example.com')).toBe(true);
    expect(isAllowedOrigin('https://evil.example.com')).toBe(false);
    expect(isAllowedOrigin('*')).toBe(false);
    expect(corsHeaders('https://evil.example.com', ['POST'])['Access-Control-Allow-Origin']).toBeUndefined();
    expect(corsHeaders('https://app.example.com', ['POST'])['Access-Control-Allow-Credentials']).toBeUndefined();
  });
});

describe('templates, redaction and env', () => {
  it('renders user text literally (no template injection)', () => {
    expect(renderText('alarm', { tag: '{{plant}}', plant: 'North', message: '${7*7}' })).toBe('ACME Control alarm {{plant}} at North: ${7*7}');
    expect(escapeHtml('<img src=x onerror=alert(1)>')).toBe('&lt;img src=x onerror=alert(1)&gt;');
  });
  it('redacts secrets from audit payloads', () => {
    expect(redact({ password: 'p', nested: { accessToken: 't', ok: 1 } })).toEqual({ password: '[redacted]', nested: { accessToken: '[redacted]', ok: 1 } });
  });
  it('requires https backend URLs', () => {
    process.env.TEST_URL = 'http://example.com';
    expect(() => requireHttpsUrl('TEST_URL')).toThrow();
    process.env.TEST_URL = 'https://user:pw@example.com';
    expect(() => requireHttpsUrl('TEST_URL')).toThrow();
    process.env.TEST_URL = 'https://abc.supabase.co';
    expect(requireHttpsUrl('TEST_URL')).toBe('https://abc.supabase.co');
  });
});
