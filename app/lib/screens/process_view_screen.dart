import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/permissions.dart';
import '../app/plant_providers.dart';
import '../components/equipment_controls.dart';
import '../components/plant_scaffold.dart';
import '../components/process_diagram.dart';
import '../components/state_views.dart';
import '../models/models.dart';

/// Process view: live water-treatment diagram with KPIs. Tapping an element opens its details
/// and (for permitted roles, online only) its controls. Offline, the last encrypted snapshot is
/// shown read-only.
class ProcessViewScreen extends ConsumerStatefulWidget {
  const ProcessViewScreen({super.key, required this.plantId});
  final String plantId;
  @override
  ConsumerState<ProcessViewScreen> createState() => _ProcessViewScreenState();
}

class _ProcessViewScreenState extends ConsumerState<ProcessViewScreen> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final process = ref.watch(plantProcessProvider(widget.plantId));
    return PlantScaffold(
      plantId: widget.plantId,
      section: PlantSection.process,
      title: 'Process view',
      actions: [IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(plantProcessProvider(widget.plantId)))],
      body: process.when(
        skipLoadingOnRefresh: true,
        loading: () => const LoadingView(label: 'Loading process…'),
        error: (_, __) => ErrorView(message: 'Could not load the process data.', onRetry: () => ref.invalidate(plantProcessProvider(widget.plantId))),
        data: (p) => p.offline ? _OfflineProcess(process: p) : _live(context, p),
      ),
    );
  }

  Widget _live(BuildContext context, PlantProcess p) {
    final wide = MediaQuery.sizeOf(context).width >= wideLayoutBreakpoint;
    final diagram = Card(
      margin: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      color: const Color(0xFF0E1A22),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: ProcessDiagram(process: p, selectedId: _selectedId, onSelect: (kind, id) => _select(context, p, kind, id)),
      ),
    );
    final kpis = _Kpis(process: p);
    if (wide) {
      return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: diagram),
        SizedBox(width: 320, child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(0, 12, 12, 12), child: kpis)),
      ]);
    }
    return ListView(children: [
      SizedBox(height: MediaQuery.sizeOf(context).height * 0.62, child: diagram),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: kpis),
      const SizedBox(height: 24),
    ]);
  }

  Future<void> _select(BuildContext context, PlantProcess p, String kind, String id) async {
    setState(() => _selectedId = id);
    if (kind == 'tank') {
      final t = p.tanks.firstWhere((x) => x.id == id);
      await showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (_) => TankDetails(tank: t, plantId: widget.plantId));
    } else {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => EquipmentSheet(plantId: widget.plantId, equipmentId: id),
      );
    }
    if (mounted) setState(() => _selectedId = null);
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.process});
  final PlantProcess process;
  @override
  Widget build(BuildContext context) {
    final p = process;
    final theme = Theme.of(context);
    final inflow = p.valves.where((v) => v.isInlet).fold<double>(0, (s, v) => s + v.flowM3h);
    final outflow = p.valves.where((v) => !v.isInlet).fold<double>(0, (s, v) => s + v.flowM3h);
    final transfer = p.pumps.fold<double>(0, (s, x) => s + x.flowM3h);
    Widget tile(String label, String value, IconData icon) => ListTile(dense: true, leading: Icon(icon), title: Text(label), trailing: Text(value, style: theme.textTheme.titleSmall));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(
        child: Column(children: [
          ListTile(title: Text('Flows', style: theme.textTheme.titleMedium)),
          tile('Raw water inflow', '${inflow.toStringAsFixed(1)} m³/h', Icons.south_east),
          tile('Transfer (pumps)', '${transfer.toStringAsFixed(1)} m³/h', Icons.sync_alt),
          tile('Distribution outflow', '${outflow.toStringAsFixed(1)} m³/h', Icons.north_east),
        ]),
      ),
      Card(
        child: Column(children: [
          ListTile(title: Text('Tanks', style: theme.textTheme.titleMedium)),
          for (final t in p.tanks)
            ListTile(
              dense: true,
              leading: Icon(Icons.propane_tank_outlined, color: t.isLow || t.isHigh ? const Color(0xFFFB8C00) : null),
              title: Text('${t.tag} · ${t.name}'),
              subtitle: Text('${t.pressureBar.toStringAsFixed(2)} bar · ${t.volumeM3.toStringAsFixed(0)} m³'),
              trailing: Text('${t.levelPct.toStringAsFixed(1)} %', style: theme.textTheme.titleSmall),
            ),
        ]),
      ),
      Card(
        child: Column(children: [
          ListTile(title: Text('Equipment', style: theme.textTheme.titleMedium), subtitle: const Text('Requested vs. actual state')),
          for (final e in p.equipment)
            ListTile(
              dense: true,
              title: Text('${e.tag} · ${e.name}'),
              subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: EquipmentStateRow(equipment: e)),
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(8),
        child: Text('Updated ${formatTime(p.fetchedAt)} · live', style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
      ),
    ]);
  }
}

class TankDetails extends StatelessWidget {
  const TankDetails({super.key, required this.tank, required this.plantId});
  final Tank tank;
  final String plantId;
  @override
  Widget build(BuildContext context) {
    final t = tank;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${t.tag} · ${t.name}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: t.levelPct / 100, minHeight: 12),
          const SizedBox(height: 12),
          Text('Level: ${t.levelPct.toStringAsFixed(1)} % (limits ${t.lowLimitPct.toStringAsFixed(0)}-${t.highLimitPct.toStringAsFixed(0)} %)'),
          Text('Volume: ${t.volumeM3.toStringAsFixed(1)} of ${t.capacityM3.toStringAsFixed(0)} m³'),
          Text('Pressure: ${t.pressureBar.toStringAsFixed(2)} bar'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.show_chart),
            label: const Text('Open level trend'),
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/plants/$plantId/trends?tag=${Uri.encodeQueryComponent('${t.tag}.level')}');
            },
          ),
        ]),
      ),
    );
  }
}

/// Read-only view from the encrypted offline snapshot (tank readings + active alarms).
class _OfflineProcess extends ConsumerWidget {
  const _OfflineProcess({required this.process});
  final PlantProcess process;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(offlineSnapshotProvider).valueOrNull;
    final theme = Theme.of(context);
    return ListView(padding: const EdgeInsets.all(16), children: [
      OfflineBanner(since: process.fetchedAt),
      const SizedBox(height: 12),
      Text('Last known tank readings', style: theme.textTheme.titleMedium),
      for (final t in process.tanks)
        Card(
          child: ListTile(
            leading: const Icon(Icons.propane_tank_outlined),
            title: Text(t.tag),
            subtitle: LinearProgressIndicator(value: t.levelPct / 100),
            trailing: Text('${t.levelPct.toStringAsFixed(1)} % · ${t.pressureBar.toStringAsFixed(2)} bar'),
          ),
        ),
      const SizedBox(height: 12),
      Text('Active alarms at that time', style: theme.textTheme.titleMedium),
      if (snapshot == null || snapshot.activeAlarms.isEmpty) const ListTile(title: Text('No active alarms.')),
      for (final a in snapshot?.activeAlarms ?? const [])
        ListTile(leading: Icon(Icons.warning_amber, color: severityColor(context, a.severity)), title: Text(a.message), subtitle: Text('${a.tag} · ${a.severity}')),
    ]);
  }
}
