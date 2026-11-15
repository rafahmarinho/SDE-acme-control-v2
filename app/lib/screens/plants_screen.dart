import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/plant_providers.dart';
import '../components/account_menu.dart';
import '../components/state_views.dart';
import '../config.dart';
import '../models/models.dart';

/// Plants the user is a member of (RLS-scoped), with a live summary per plant and search.
class PlantsScreen extends ConsumerStatefulWidget {
  const PlantsScreen({super.key});
  @override
  ConsumerState<PlantsScreen> createState() => _PlantsScreenState();
}

class _PlantsScreenState extends ConsumerState<PlantsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final plants = ref.watch(plantsProvider);
    final online = isOnline(ref);
    return Scaffold(
      appBar: AppBar(
        title: const Text('ACME Control'),
        actions: [
          if (AppConfig.enableDemoTools) IconButton(tooltip: 'Simulation', icon: const Icon(Icons.science_outlined), onPressed: () => context.push('/simulation')),
          const AccountMenu(),
        ],
      ),
      body: Column(children: [
        if (!online) const OfflineBanner(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search plants', border: OutlineInputBorder()),
            maxLength: 64,
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
          ),
        ),
        Expanded(
          child: plants.when(
            loading: () => const LoadingView(label: 'Loading plants…'),
            error: (_, __) => ErrorView(message: 'Could not load your plants.', onRetry: () => ref.invalidate(plantsProvider)),
            data: (list) {
              final filtered = list.where((p) => _query.isEmpty || p.name.toLowerCase().contains(_query) || (p.locationLabel ?? '').toLowerCase().contains(_query)).toList();
              if (list.isEmpty) return const EmptyView(message: 'You are not a member of any plant yet. Ask an administrator for access.', icon: Icons.factory_outlined);
              if (filtered.isEmpty) return const EmptyView(message: 'No plants match your search.', icon: Icons.search_off);
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(plantsProvider),
                child: LayoutBuilder(builder: (context, c) {
                  final columns = c.maxWidth >= 1100 ? 3 : (c.maxWidth >= 700 ? 2 : 1);
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 240),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _PlantCard(plant: filtered[i]),
                  );
                }),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _PlantCard extends ConsumerWidget {
  const _PlantCard({required this.plant});
  final Plant plant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final process = ref.watch(plantProcessProvider(plant.id));
    final alarms = ref.watch(activeAlarmCountProvider(plant.id)).valueOrNull ?? 0;
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/plants/${plant.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.factory),
              const SizedBox(width: 8),
              Expanded(child: Text(plant.name, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
              if (alarms > 0)
                Chip(
                  avatar: const Icon(Icons.notifications_active, size: 16, color: Color(0xFFFB8C00)),
                  label: Text('$alarms active'),
                  visualDensity: VisualDensity.compact,
                ),
            ]),
            Text([plant.locationLabel, if (plant.role != null) roleLabel(plant.role!)].whereType<String>().join(' · '), style: theme.textTheme.bodySmall),
            const Divider(),
            Expanded(
              child: process.when(
                loading: () => const Center(child: LinearProgressIndicator()),
                error: (_, __) => const Text('Live data unavailable.'),
                data: (p) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final t in p.tanks)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        SizedBox(width: 64, child: Text(t.tag, style: theme.textTheme.labelMedium)),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: t.levelPct / 100,
                              minHeight: 10,
                              color: t.isLow || t.isHigh ? const Color(0xFFFB8C00) : const Color(0xFF29B6F6),
                            ),
                          ),
                        ),
                        SizedBox(width: 56, child: Text('${t.levelPct.toStringAsFixed(1)}%', textAlign: TextAlign.right)),
                      ]),
                    ),
                  const Spacer(),
                  if (!p.offline)
                    Text(
                      'Pumps running: ${p.pumps.where((x) => x.isActive).length}/${p.pumps.length} · Valves open: ${p.valves.where((x) => x.isActive).length}/${p.valves.length}',
                      style: theme.textTheme.bodySmall,
                    )
                  else
                    Text('Offline snapshot from ${formatTime(p.fetchedAt)}', style: theme.textTheme.bodySmall),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
