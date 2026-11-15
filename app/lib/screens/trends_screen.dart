import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/permissions.dart';
import '../app/plant_providers.dart';
import '../components/plant_scaffold.dart';
import '../components/state_views.dart';
import '../components/trend_chart.dart';

/// Allowed time windows. The server (`trend_values`) independently rejects ranges over 7 days
/// and more than 2000 points (T2600).
const trendRanges = <String, Duration>{
  '15 min': Duration(minutes: 15),
  '1 h': Duration(hours: 1),
  '6 h': Duration(hours: 6),
  '24 h': Duration(hours: 24),
  '7 days': Duration(days: 7),
};

/// Trends of level, pressure and flow recorded by the process simulation.
class TrendsScreen extends ConsumerStatefulWidget {
  const TrendsScreen({super.key, required this.plantId, this.initialTag});
  final String plantId;
  final String? initialTag;
  @override
  ConsumerState<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends ConsumerState<TrendsScreen> {
  String? _tag;
  String _range = '1 h';

  @override
  void initState() {
    super.initState();
    final t = widget.initialTag;
    // Only accept tags shaped like "<TAG>.<metric>"; anything else is ignored.
    if (t != null && RegExp(r'^[A-Z0-9\-]{1,32}\.(level|pressure|flow)$').hasMatch(t)) _tag = t;
  }

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(trendTagsProvider(widget.plantId));
    return PlantScaffold(
      plantId: widget.plantId,
      section: PlantSection.trends,
      body: tags.when(
        loading: () => const LoadingView(label: 'Loading trend tags…'),
        error: (_, __) => ErrorView(message: 'Could not load trends.', onRetry: () => ref.invalidate(trendTagsProvider(widget.plantId))),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyView(
              message: 'No trend data yet. Values are recorded each time the process simulation advances (Simulation area).',
              icon: Icons.show_chart,
            );
          }
          final selected = list.any((t) => t.tag == _tag) ? _tag! : list.first.tag;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                DropdownMenu<String>(
                  label: const Text('Tag'),
                  initialSelection: selected,
                  width: 260,
                  dropdownMenuEntries: [for (final t in list) DropdownMenuEntry(value: t.tag, label: '${t.tag} (${t.unit})')],
                  onSelected: (v) => setState(() => _tag = v),
                ),
                SegmentedButton<String>(
                  segments: [for (final r in trendRanges.keys) ButtonSegment(value: r, label: Text(r))],
                  selected: {_range},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _range = s.first),
                ),
              ]),
              const SizedBox(height: 16),
              Expanded(child: _TrendCard(plantId: widget.plantId, tag: selected, range: trendRanges[_range]!)),
            ]),
          );
        },
      ),
    );
  }
}

class _TrendCard extends ConsumerWidget {
  const _TrendCard({required this.plantId, required this.tag, required this.range});
  final String plantId, tag;
  final Duration range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = (plantId: plantId, tag: tag, range: range);
    final series = ref.watch(trendProvider(q));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: series.when(
          skipLoadingOnRefresh: true,
          loading: () => const LoadingView(),
          error: (_, __) => ErrorView(message: 'Could not load this trend.', onRetry: () => ref.invalidate(trendProvider(q))),
          data: (s) {
            if (s.points.isEmpty) return const EmptyView(message: 'No values in this time window.', icon: Icons.timeline);
            final values = s.points.map((p) => p.value);
            final last = s.points.last;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.tag, style: Theme.of(context).textTheme.titleMedium),
              Text(
                'Last ${last.value.toStringAsFixed(2)} ${s.unit} · min ${values.reduce((a, b) => a < b ? a : b).toStringAsFixed(2)} · '
                'max ${values.reduce((a, b) => a > b ? a : b).toStringAsFixed(2)} · ${s.points.length} points',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Expanded(child: TrendChart(series: s, color: tag.endsWith('.level') ? const Color(0xFF29B6F6) : (tag.endsWith('.flow') ? const Color(0xFF66BB6A) : const Color(0xFFFFB300)))),
            ]);
          },
        ),
      ),
    );
  }
}

/// Exposed for tests: the client never asks for more than the server maximum.
bool trendRangeAllowed(Duration d) => d > Duration.zero && d <= const Duration(days: 7);
