import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/permissions.dart';
import '../app/plant_providers.dart';
import '../app/providers.dart';
import '../components/account_menu.dart';
import '../components/control_action.dart';
import '../components/process_diagram.dart';
import '../components/state_views.dart';
import '../models/models.dart';

/// Demo area (PRD): choose a scenario, advance the simulation, browse events and reset demo data.
/// Only compiled into the router when ENABLE_DEMO_TOOLS is set; the API returns 404 unless the
/// same flag is enabled server-side and allows it to supervisors only (reset needs re-auth).
/// Results are persisted in Supabase, so they survive reloads.
const scenarios = <String, (String, String)>{
  'normal': ('Normal operation', 'Raw tank at 60 %, treated tank at 40 %.'),
  'tank_low': ('Raw tank low', 'Raw tank just above its low limit; pumps trip when it empties.'),
  'pump_maintenance': ('Pump in maintenance', 'First transfer pump locked out; it cannot run.'),
  'high_demand': ('High demand', 'Distribution outlet flow increased by 80 %.'),
};

class SimulationScreen extends ConsumerStatefulWidget {
  const SimulationScreen({super.key});
  @override
  ConsumerState<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends ConsumerState<SimulationScreen> {
  String? _plantId;
  bool _busy = false;
  Timer? _auto;
  String? _eventType;

  @override
  void dispose() {
    _auto?.cancel();
    super.dispose();
  }

  Future<void> _do(Future<Object?> Function() action, String success) async {
    setState(() => _busy = true);
    final ok = await runControlAction(context, ref, action, success: success);
    if (ok && _plantId != null) ref.invalidate(plantProcessProvider(_plantId!));
    if (mounted) setState(() => _busy = false);
  }

  void _toggleAuto(bool on) {
    _auto?.cancel();
    _auto = null;
    if (on && _plantId != null) {
      final plantId = _plantId!;
      // 15 s cadence stays under the API simulation rate limit (5 requests / minute).
      _auto = Timer.periodic(const Duration(seconds: 15), (_) async {
        if (!mounted || _busy || !isOnline(ref)) return;
        try {
          await ref.read(commandServiceProvider).stepSimulation(plantId, 6);
        } catch (_) {
          _auto?.cancel();
          if (mounted) setState(() => _auto = null);
        }
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final plants = ref.watch(plantsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'All plants', icon: const Icon(Icons.arrow_back), onPressed: () => context.canPop() ? context.pop() : context.go('/plants')),
        title: const Text('Simulation (demo)'),
        actions: const [AccountMenu()],
      ),
      body: plants.when(
        loading: () => const LoadingView(),
        error: (_, __) => ErrorView(message: 'Could not load plants.', onRetry: () => ref.invalidate(plantsProvider)),
        data: (list) {
          final managed = list.where((p) => uiAllows(p.role, UiAction.simulation)).toList();
          if (managed.isEmpty) {
            return const EmptyView(message: 'The simulation area is available to supervisors only.', icon: Icons.lock_outline);
          }
          final plantId = managed.any((p) => p.id == _plantId) ? _plantId! : managed.first.id;
          if (_plantId != plantId) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? setState(() => _plantId = plantId) : null);
          return _body(context, managed, plantId);
        },
      ),
    );
  }

  Widget _body(BuildContext context, List<Plant> plants, String plantId) {
    final service = ref.read(commandServiceProvider);
    final online = isOnline(ref);
    final enabled = !_busy && online;
    final process = ref.watch(plantProcessProvider(plantId));
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final theme = Theme.of(context);

    final controls = ListView(padding: const EdgeInsets.all(16), children: [
      if (!online) const OfflineBanner(),
      DropdownButtonFormField<String>(
        initialValue: plantId,
        decoration: const InputDecoration(labelText: 'Plant', border: OutlineInputBorder()),
        items: [for (final p in plants) DropdownMenuItem(value: p.id, child: Text(p.name))],
        onChanged: (v) {
          _toggleAuto(false);
          setState(() => _plantId = v);
        },
      ),
      const SizedBox(height: 16),
      Text('Scenarios', style: theme.textTheme.titleMedium),
      for (final s in scenarios.entries)
        Card(
          child: ListTile(
            minTileHeight: 64,
            title: Text(s.value.$1),
            subtitle: Text(s.value.$2),
            trailing: const Icon(Icons.play_circle_outline),
            enabled: enabled,
            onTap: () => _do(() => service.applyScenario(plantId, s.key), 'Scenario "${s.value.$1}" applied.'),
          ),
        ),
      const SizedBox(height: 16),
      Text('Advance the process', style: theme.textTheme.titleMedium),
      Text('Each step is 10 s of process time. Levels, alarms and trends are persisted.', style: theme.textTheme.bodySmall),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (steps, label) in const [(1, '+10 s'), (6, '+1 min'), (60, '+10 min'), (360, '+1 h')])
          FilledButton.tonal(onPressed: enabled ? () => _do(() => service.stepSimulation(plantId, steps), 'Simulation advanced $label.') : null, child: Text(label)),
      ]),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Run continuously'),
        subtitle: const Text('Advances 1 minute every 15 seconds while this page is open.'),
        value: _auto != null,
        onChanged: online ? _toggleAuto : null,
      ),
      const SizedBox(height: 16),
      Text('Reset', style: theme.textTheme.titleMedium),
      Text('Restores the demo process data for this plant. The audit log is never touched.', style: theme.textTheme.bodySmall),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.restart_alt),
        label: const Text('Reset demo data'),
        onPressed: enabled
            ? () async {
                final ok = await confirmAction(context, title: 'Reset demo data?', message: 'Tank levels, equipment states, alarms and trends of this plant are restored to the demo baseline.', confirm: 'Reset');
                if (ok) {
                  _toggleAuto(false);
                  await _do(() => service.resetDemo(plantId), 'Demo data reset.');
                }
              }
            : null,
      ),
      if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
      const SizedBox(height: 16),
      SizedBox(
        height: 260,
        child: Card(
          color: const Color(0xFF0E1A22),
          clipBehavior: Clip.antiAlias,
          child: process.when(
            skipLoadingOnRefresh: true,
            loading: () => const LoadingView(),
            error: (_, __) => const ErrorView(message: 'Live process unavailable.'),
            data: (p) => p.offline ? const EmptyView(message: 'Offline.') : Padding(padding: const EdgeInsets.all(6), child: ProcessDiagram(process: p)),
          ),
        ),
      ),
    ]);

    final events = _EventsPanel(plantId: plantId, type: _eventType, onType: (t) => setState(() => _eventType = t));
    return wide
        ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [SizedBox(width: 480, child: controls), const VerticalDivider(width: 1), Expanded(child: events)])
        : DefaultTabController(
            length: 2,
            child: Column(children: [
              const TabBar(tabs: [Tab(text: 'Controls'), Tab(text: 'Events')]),
              Expanded(child: TabBarView(children: [controls, events])),
            ]),
          );
  }
}

const _eventTypes = <String?, String>{null: 'All', 'simulation': 'Simulation', 'command': 'Commands', 'alarm': 'Alarms', 'setpoint': 'Setpoints', 'maintenance': 'Maintenance', 'integration': 'Integrations'};

class _EventsPanel extends ConsumerWidget {
  const _EventsPanel({required this.plantId, required this.type, required this.onType});
  final String plantId;
  final String? type;
  final ValueChanged<String?> onType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider((plantId: plantId, typePrefix: type)));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in _eventTypes.entries) ChoiceChip(label: Text(e.value), selected: type == e.key, onSelected: (_) => onType(e.key)),
        ]),
      ),
      Expanded(
        child: events.when(
          skipLoadingOnRefresh: true,
          loading: () => const LoadingView(label: 'Loading events…'),
          error: (_, __) => ErrorView(message: 'Could not load events.', onRetry: () => ref.invalidate(eventsProvider((plantId: plantId, typePrefix: type)))),
          data: (list) => list.isEmpty
              ? const EmptyView(message: 'No events in this view.', icon: Icons.event_note)
              : ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final e = list[i];
                    return ListTile(dense: true, leading: Icon(_iconFor(e.type)), title: Text(e.message), subtitle: Text('${formatTime(e.ts)} · ${e.type}'));
                  },
                ),
        ),
      ),
    ]);
  }

  IconData _iconFor(String type) => switch (type.split('.').first) {
        'simulation' => Icons.science_outlined,
        'command' => Icons.toggle_on_outlined,
        'alarm' => Icons.warning_amber,
        'setpoint' => Icons.tune,
        'maintenance' => Icons.build_outlined,
        'integration' => Icons.sms_outlined,
        _ => Icons.info_outline,
      };
}
