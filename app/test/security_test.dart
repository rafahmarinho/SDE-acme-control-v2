import 'package:acme_control/app/navigation_guards.dart';
import 'package:acme_control/services/auth_service.dart';
import 'package:acme_control/services/offline_cache_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('password policy mirrors the server (12+ chars, upper, lower, digit)', () {
    expect(validatePassword('Short1A'), isNotNull);
    expect(validatePassword('alllowercase123'), isNotNull);
    expect(validatePassword('ValidPassword12'), isNull);
  });

  test('post-login redirects stay inside the app', () {
    expect(safeNext('https://evil.example'), '/plants');
    expect(safeNext('//evil.example'), '/plants');
    expect(safeNext('/settings'), '/settings');
    expect(safeNext(null), '/plants');
  });

  test('deep links cannot open control screens and only the auth code is read', () {
    expect(isAllowedDeepLink(Uri.parse('https://app/plants/11111111-1111-4111-8111-111111111111/alarms')), isTrue);
    expect(isAllowedDeepLink(Uri.parse('https://app/plants/11111111-1111-4111-8111-111111111111/commands')), isFalse);
    expect(authCallbackCode(Uri.parse('https://app/auth/callback?code=abc123&next=/commands')), 'abc123');
    expect(authCallbackCode(Uri.parse('https://app/auth/callback?code=<script>')), isNull);
  });

  test('offline snapshot serialises only whitelisted fields', () {
    final s = OfflineSnapshot(
      takenAt: DateTime.utc(2026, 11, 12),
      plantId: 'p',
      tanks: const [TankReading(tag: 'TK-101', levelPct: 50, pressureBar: 1.6)],
      activeAlarms: const [AlarmSummary(tag: 'TK-101', severity: 'high', message: 'Level low')],
    );
    expect(s.toJson().keys, unorderedEquals(['takenAt', 'plantId', 'tanks', 'activeAlarms']));
  });
}
