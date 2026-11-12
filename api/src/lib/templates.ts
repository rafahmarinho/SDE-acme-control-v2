/**
 * Fixed, version-controlled message templates. User data is passed only as variables and is
 * substituted in a single pass (values are never re-parsed as templates), so template syntax in
 * user text is rendered literally. No eval / new Function / dynamic template compilation.
 */
const TEMPLATES = {
  alarm: 'ACME Control alarm {{tag}} at {{plant}}: {{message}}',
  setpointApproved: 'Setpoint {{tag}} changed to {{value}} {{unit}} at {{plant}}.',
  interlockBlocked: 'Command on {{tag}} blocked: {{reason}}.',
} as const;

export type TemplateName = keyof typeof TEMPLATES;

export function renderText(name: TemplateName, vars: Record<string, string | number>): string {
  return TEMPLATES[name].replace(/\{\{(\w+)\}\}/g, (_, key: string) => {
    const v = vars[key];
    return v === undefined ? '' : String(v).slice(0, 300);
  });
}

/** Context-correct HTML escaping for any server-generated HTML (reports). */
export function escapeHtml(s: string): string {
  return s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c] as string);
}
