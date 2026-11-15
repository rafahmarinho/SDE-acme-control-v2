import 'package:acme_control/app/permissions.dart';
import 'package:acme_control/app/plant_providers.dart';
import 'package:acme_control/components/process_diagram.dart';
import 'package:acme_control/components/state_views.dart';
import 'package:acme_control/models/models.dart';
import 'package:acme_control/screens/trends_screen.dart';
import 'package:acme_control/services/offline_cache_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PlantProcess demoProcess({String pumpActual = 'on', String pumpRequested = 'on', bool maintenance = false}) {
  final now = DateTime.utc(2026, 11, 15);
  return PlantProcess(
    tanks: [
      Tank.fromRow({'id': 't1', 'tag': 'TK-101', 'name': 'Raw water tank', 'capacity_m3': 500, 'level_pct': 60, 'low_limit_pct': 5, 'high_limit_pct': 95, 'pressure_bar': 1.72}),
      Tank.fromRow({'id': 't2', 'tag': 'TK-102', 'name': 'Treated water tank', 'capacity_m3': 400, 'level_pct': 3.5, 'low_limit_pct': 5, 'high_limit_pct': 95, 'pressure_bar': 1.04}),
    ],
    pumps: [
      Pump(id: 'p1', tag: 'P-101', name: 'Transfer pump A', sourceTankId: 't1', destTankId: 't2', ratedFlowM3h: 120, requestedState: pumpRequested, actualState: pumpActual, mode: 'manual', inMaintenance: maintenance, flowM3h: pumpActual == 'on' ? 118 : 0, updatedAt: now),
      Pump(id: 'p2', tag: 'P-102', name: 'Transfer pump B', sourceTankId: 't1', destTankId: 't2', ratedFlowM3h: 90, requestedState: 'off', actualState: 'off', mode: 'auto', inMaintenance: false, flowM3h: 0, updatedAt: now),
    ],
    valves: [
      Valve(id: 'v1', tag: 'XV-101', name: 'Raw water inlet', tankId: 't1', direction: 'inlet', ratedFlowM3h: 140, requestedState: 'open', actualState: 'open', mode: 'manual', inMaintenance: false, flowM3h: 140, updatedAt: now),
      Valve(id: 'v2', tag: 'XV-102', name: 'Distribution outlet', tankId: 't2', direction: 'outlet', ratedFlowM3h: 100, requestedState: 'closed', actualState: 'closed', mode: 'manual', inMaintenance: false, flowM3h: 0, updatedAt: now),
    ],
    fetchedAt: now,
  );
}

void main() {
  group('UI permission mirror (navigation only; API enforces)', () {
    test('matches the API matrix in api/src/auth/permissions.ts', () {
      expect(Role.values.where((r) => uiAllows(r, UiAction.pumpToggle)), {Role.operator, Role.supervisor});
      expect(Role.values.where((r) => uiAllows(r, UiAction.lockout)), {Role.maintenance});
      expect(Role.values.where((r) => uiAllows(r, UiAction.setpointPropose)), {Role.engineer});
      expect(Role.values.where((r) => uiAllows(r, UiAction.setpointReview)), {Role.supervisor});
      expect(Role.values.where((r) => uiAllows(r, UiAction.alarmAcknowledge)), {Role.operator, Role.supervisor});
      expect(Role.values.where((r) => uiAllows(r, UiAction.simulation)), {Role.supervisor});
      expect(uiAllows(null, UiAction.pumpToggle), isFalse);
    });

    test('navigation adapts to each role', () {
      expect(sectionsFor(Role.supervisor), PlantSection.values);
      expect(sectionsFor(Role.engineer), isNot(contains(PlantSection.commands)));
      expect(sectionsFor(Role.maintenance), contains(PlantSection.maintenance));
      expect(sectionsFor(Role.operator), contains(PlantSection.commands));
      for (final r in Role.values) {
        expect(sectionsFor(r).take(3), [PlantSection.process, PlantSection.alarms, PlantSection.equipment]);
      }
    });

    test('section routes stay under the plant path', () {
      expect(PlantSection.process.route('x'), '/plants/x');
      expect(PlantSection.alarms.route('x'), '/plants/x/alarms');
    });
  });

  group('models', () {
    test('parse numeric columns from int or double and flag requested/actual mismatch', () {
      final p = demoProcess(pumpRequested: 'on', pumpActual: 'off');
      expect(p.tanks.first.volumeM3, 300);
      expect(p.tanks[1].isLow, isTrue);
      expect(p.pumps.first.mismatch, isTrue);
      expect(p.pumps[1].isAuto, isTrue);
      expect(p.equipment, hasLength(4));
    });

    test('unknown roles are ignored', () {
      expect(roleFrom('admin'), isNull);
      expect(roleFrom('supervisor'), Role.supervisor);
    });
  });

  test('trend windows never exceed the server maximum (7 days)', () {
    for (final d in trendRanges.values) {
      expect(trendRangeAllowed(d), isTrue);
    }
    expect(trendRangeAllowed(const Duration(days: 8)), isFalse);
  });

  test('offline process is read-only and built only from whitelisted snapshot fields', () {
    final p = offlineProcess(OfflineSnapshot(
      takenAt: DateTime.utc(2026, 11, 15),
      plantId: 'p',
      tanks: const [TankReading(tag: 'TK-101', levelPct: 42, pressureBar: 1.5)],
      activeAlarms: const [],
    ));
    expect(p.offline, isTrue);
    expect(p.pumps, isEmpty);
    expect(p.tanks.single.levelPct, 42);
  });

  testWidgets('process diagram renders on wide and phone layouts and reports taps', (tester) async {
    String? tapped;
    for (final size in const [Size(1200, 600), Size(390, 700)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(body: ProcessDiagram(process: demoProcess(), onSelect: (_, id) => tapped = id)),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ProcessDiagram), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.bySemanticsLabel(RegExp('^P-101')));
      expect(tapped, 'p1');
    }
    addTearDown(tester.view.reset);
  });

  testWidgets('state pills show requested vs. actual and maintenance', (tester) async {
    final pump = demoProcess(pumpRequested: 'on', pumpActual: 'off', maintenance: true).pumps.first;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: EquipmentStateRow(equipment: pump))));
    expect(find.text('Requested: ON'), findsOneWidget);
    expect(find.text('Actual: OFF'), findsOneWidget);
    expect(find.text('Status: MAINTENANCE'), findsOneWidget);
  });

  testWidgets('user text is rendered literally, never as HTML or templates', (tester) async {
    const payload = '<img src=x onerror=alert(1)> {{tag}} \${7*7}';
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: EmptyView(message: payload))));
    expect(find.text(payload), findsOneWidget);
  });
}
