import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/permissions.dart';
import '../app/plant_providers.dart';
import '../app/providers.dart';
import '../components/control_action.dart';
import '../components/plant_scaffold.dart';
import '../components/state_views.dart';
import '../models/models.dart';

/// Alarms: active / history, severity filter, text search, acknowledgement (operator and
/// supervisor; enforced by the API). Updates arrive through Supabase Realtime.
class AlarmsScreen extends ConsumerStatefulWidget {
  const AlarmsScreen({super.key, required this.plantId});
  final String plantId;
  @override
  ConsumerState<AlarmsScreen> createState() => _AlarmsScreenState();
}

class _AlarmsScreenState extends ConsumerState<AlarmsScreen> {
  bool _activeOnly = true;
  String? _severity;
  String _query = '';
  final _busy = <String>{};

  AlarmQuery get _q => (plantId: widget.plantId, activeOnly: _activeOnly, severity: _severity);

  Future<void> _ack(Alarm a) async {
    setState(() => _busy.add(a.id));
    final ok = await runControlAction(context, ref, () => ref.read(commandServiceProvider).acknowledgeAlarm(widget.plantId, a.id), success: 'Alarm on ${a.tag} acknowledged.');
    if (ok) ref.invalidate(alarmsProvider(_q));
    if (mounted) setState(() => _busy.remove(a.id));
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(plantRoleProvider(widget.plantId)).valueOrNull;
    final online = isOnline(ref);
    final alarms = ref.watch(alarmsProvider(_q));
    final canAck = uiAllows(role, UiAction.alarmAcknowledge);
    return PlantScaffold(
      plantId: widget.plantId,
      section: PlantSection.alarms,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SegmentedButton<bool>(
              segments: const [ButtonSegment(value: true, label: Text('Active')), ButtonSegment(value: false, label: Text('History'))],
              selected: {_activeOnly},
              onSelectionChanged: (s) => setState(() => _activeOnly = s.first),
            ),
            for (final s in alarmSeverities)
              FilterChip(
                label: Text(statusLabel(s)),
                avatar: Icon(Icons.circle, size: 12, color: severityColor(context, s)),
                selected: _severity == s,
                onSelected: (v) => setState(() => _severity = v ? s : null),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            maxLength: 64,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Filter by tag or message', counterText: '', isDense: true, border: OutlineInputBorder()),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: alarms.when(
            skipLoadingOnRefresh: true,
            loading: () => const LoadingView(label: 'Loading alarms…'),
            error: (_, __) => ErrorView(message: 'Could not load alarms.', onRetry: () => ref.invalidate(alarmsProvider(_q))),
            data: (list) {
              final filtered = list.where((a) => _query.isEmpty || a.tag.toLowerCase().contains(_query) || a.message.toLowerCase().contains(_query)).toList();
              if (filtered.isEmpty) {
                return EmptyView(message: _activeOnly ? 'No active alarms. The process is within limits.' : 'No alarms match the current filters.', icon: Icons.notifications_off_outlined);
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(alarmsProvider(_q)),
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final a = filtered[i];
                    return ListTile(
                      minTileHeight: 72,
                      leading: Icon(a.active ? Icons.warning_amber_rounded : Icons.check_circle_outline, color: a.active ? severityColor(context, a.severity) : null, size: 32),
                      title: Text(a.message), // plain text, never HTML (T36)
                      subtitle: Text([
                        a.tag,
                        statusLabel(a.severity),
                        'raised ${formatTime(a.raisedAt)}',
                        if (a.clearedAt != null) 'cleared ${formatTime(a.clearedAt!)}',
                        if (a.acknowledged) 'acknowledged ${formatTime(a.acknowledgedAt!)}',
                      ].join(' · ')),
                      trailing: a.acknowledged || !canAck
                          ? (a.acknowledged ? const Icon(Icons.done_all) : null)
                          : FilledButton.tonal(onPressed: !online || _busy.contains(a.id) ? null : () => _ack(a), child: const Text('Acknowledge')),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
