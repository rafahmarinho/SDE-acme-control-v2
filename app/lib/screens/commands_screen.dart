import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/permissions.dart';
import '../app/plant_providers.dart';
import '../components/equipment_controls.dart';
import '../components/plant_scaffold.dart';
import '../components/state_views.dart';
import '../models/models.dart';

/// Commands: operate pumps (start/stop) and valves (open/close) and switch manual/auto mode.
/// Shows requested vs. actual state and recent command events. Requires a connection; the API
/// authorizes every command and applies the interlocks (empty tank, maintenance, auto mode).
class CommandsScreen extends ConsumerWidget {
  const CommandsScreen({super.key, required this.plantId});
  final String plantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final process = ref.watch(plantProcessProvider(plantId));
    final role = ref.watch(plantRoleProvider(plantId)).valueOrNull;
    final events = ref.watch(eventsProvider((plantId: plantId, typePrefix: 'command')));
    final wide = MediaQuery.sizeOf(context).width >= wideLayoutBreakpoint;

    final controls = process.when(
      skipLoadingOnRefresh: true,
      loading: () => const LoadingView(label: 'Loading equipment…'),
      error: (_, __) => ErrorView(message: 'Could not load equipment.', onRetry: () => ref.invalidate(plantProcessProvider(plantId))),
      data: (p) {
        if (p.offline) return const EmptyView(message: 'Control actions require a connection.', icon: Icons.cloud_off);
        return ListView(padding: const EdgeInsets.all(12), children: [
          if (!uiAllows(role, UiAction.pumpToggle))
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Read-only for your role'),
                subtitle: Text('Only operators and supervisors can operate pumps and valves.'),
              ),
            ),
          _Group(title: 'Pumps', plantId: plantId, items: p.pumps, process: p),
          _Group(title: 'Valves', plantId: plantId, items: p.valves, process: p),
        ]);
      },
    );

    final log = Card(
      margin: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const ListTile(title: Text('Recent commands'), subtitle: Text('Accepted and blocked commands')),
        Expanded(
          child: events.when(
            skipLoadingOnRefresh: true,
            loading: () => const LoadingView(),
            error: (_, __) => const ErrorView(message: 'Could not load the command log.'),
            data: (list) => list.isEmpty
                ? const EmptyView(message: 'No commands yet.')
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final e = list[i];
                      final blocked = e.type == 'command.blocked';
                      return ListTile(
                        dense: true,
                        leading: Icon(blocked ? Icons.block : Icons.check_circle_outline, color: blocked ? const Color(0xFFFB8C00) : null),
                        title: Text(e.message),
                        subtitle: Text('${formatTime(e.ts)} · ${e.type}'),
                      );
                    },
                  ),
          ),
        ),
      ]),
    );

    return PlantScaffold(
      plantId: plantId,
      section: PlantSection.commands,
      body: wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(flex: 3, child: controls), Expanded(flex: 2, child: log)])
          : DefaultTabController(
              length: 2,
              child: Column(children: [
                const TabBar(tabs: [Tab(text: 'Controls'), Tab(text: 'Command log')]),
                Expanded(child: TabBarView(children: [controls, log])),
              ]),
            ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.plantId, required this.items, required this.process});
  final String title, plantId;
  final List<Equipment> items;
  final PlantProcess process;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 4), child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
      for (final e in items)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${e.tag} · ${e.name}', style: Theme.of(context).textTheme.titleSmall)),
                Text('${e.flowM3h.toStringAsFixed(1)} m³/h'),
              ]),
              if (e is Pump) Text('Source ${process.tankById(e.sourceTankId)?.tag ?? '-'} at ${process.tankById(e.sourceTankId)?.levelPct.toStringAsFixed(1) ?? '-'} %', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              EquipmentControls(plantId: plantId, equipment: e),
            ]),
          ),
        ),
    ]);
  }
}
