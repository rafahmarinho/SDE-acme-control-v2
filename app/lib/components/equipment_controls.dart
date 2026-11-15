import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/permissions.dart';
import '../app/plant_providers.dart';
import '../app/providers.dart';
import '../models/models.dart';
import 'control_action.dart';
import 'state_views.dart';

/// Controls for one pump or valve: start/stop or open/close, manual/auto mode and (maintenance
/// role) lockout. Buttons are enabled from the UI permission mirror only for usability; the API
/// re-validates role, plant membership, mode and interlocks and may still reject the command.
class EquipmentControls extends ConsumerStatefulWidget {
  const EquipmentControls({super.key, required this.plantId, required this.equipment, this.compact = false});
  final String plantId;
  final Equipment equipment;
  final bool compact;
  @override
  ConsumerState<EquipmentControls> createState() => _EquipmentControlsState();
}

class _EquipmentControlsState extends ConsumerState<EquipmentControls> {
  bool _busy = false;

  Future<void> _run(Future<Object?> Function() action, String success) async {
    setState(() => _busy = true);
    final ok = await runControlAction(context, ref, action, success: success);
    if (ok) ref.invalidate(plantProcessProvider(widget.plantId));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.equipment;
    final role = ref.watch(plantRoleProvider(widget.plantId)).valueOrNull;
    final online = isOnline(ref);
    final isPump = e is Pump;
    final canToggle = uiAllows(role, isPump ? UiAction.pumpToggle : UiAction.valveToggle);
    final canMode = uiAllows(role, UiAction.modeSet);
    final canLockout = uiAllows(role, UiAction.lockout);
    final service = ref.read(commandServiceProvider);

    String? toggleHint;
    if (!online) {
      toggleHint = 'Control actions require a connection.';
    } else if (!canToggle) {
      toggleHint = 'Your role cannot operate this equipment.';
    } else if (e.isAuto) {
      toggleHint = 'In AUTO mode the controller decides. Switch to MANUAL to operate.';
    } else if (e.inMaintenance) {
      toggleHint = 'Locked out for maintenance.';
    }
    final toggleEnabled = !_busy && toggleHint == null;

    final onLabel = isPump ? 'Start' : 'Open';
    final offLabel = isPump ? 'Stop' : 'Close';
    final toggle = SegmentedButton<bool>(
      segments: [
        ButtonSegment(value: true, label: Text(onLabel), icon: Icon(isPump ? Icons.play_arrow : Icons.open_in_full)),
        ButtonSegment(value: false, label: Text(offLabel), icon: Icon(isPump ? Icons.stop : Icons.close_fullscreen)),
      ],
      selected: {e.isRequestedActive},
      onSelectionChanged: toggleEnabled
          ? (s) => _run(
                () => isPump ? service.setPump(widget.plantId, e.id, s.first) : service.setValve(widget.plantId, e.id, s.first),
                '${e.tag}: ${s.first ? onLabel.toLowerCase() : offLabel.toLowerCase()} command sent.',
              )
          : null,
    );

    final modeEnabled = !_busy && online && canMode && !e.inMaintenance;
    final mode = SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: false, label: Text('Manual'), icon: Icon(Icons.pan_tool_outlined)),
        ButtonSegment(value: true, label: Text('Auto'), icon: Icon(Icons.auto_mode)),
      ],
      selected: {e.isAuto},
      onSelectionChanged: modeEnabled
          ? (s) => _run(() => service.setMode(widget.plantId, e.kind, e.id, s.first), '${e.tag}: mode set to ${s.first ? 'AUTO' : 'MANUAL'}.')
          : null,
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      EquipmentStateRow(equipment: e),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [toggle, mode]),
      if (toggleHint != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(toggleHint, style: Theme.of(context).textTheme.bodySmall)),
      if (canLockout) ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: Icon(e.inMaintenance ? Icons.lock_open : Icons.lock_outline),
          label: Text(e.inMaintenance ? 'Release from maintenance' : 'Lock out for maintenance'),
          onPressed: _busy || !online
              ? null
              : () async {
                  final ok = await confirmAction(
                    context,
                    title: e.inMaintenance ? 'Release ${e.tag}?' : 'Lock out ${e.tag}?',
                    message: e.inMaintenance
                        ? 'The equipment will be available for operation again.'
                        : 'The equipment will be forced to a safe state (${isPump ? 'stopped' : 'closed'}, manual) and cannot be operated until released.',
                  );
                  if (ok) await _run(() => service.setLockout(widget.plantId, e.kind, e.id, !e.inMaintenance), e.inMaintenance ? '${e.tag} released.' : '${e.tag} locked out.');
                },
        ),
      ],
      if (_busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
    ]);
  }
}

/// Bottom sheet with live details and controls for one pump/valve.
class EquipmentSheet extends ConsumerWidget {
  const EquipmentSheet({super.key, required this.plantId, required this.equipmentId});
  final String plantId;
  final String equipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final process = ref.watch(plantProcessProvider(plantId)).valueOrNull;
    final e = process?.equipment.where((x) => x.id == equipmentId).firstOrNull;
    if (process == null || e == null) return const SizedBox(height: 160, child: LoadingView());
    final theme = Theme.of(context);
    String tankTag(String id) => process.tankById(id)?.tag ?? '-';
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('${e.tag} · ${e.name}', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            e is Pump
                ? 'Transfer pump ${tankTag(e.sourceTankId)} → ${tankTag(e.destTankId)} · rated ${e.ratedFlowM3h.toStringAsFixed(0)} m³/h'
                : '${(e as Valve).isInlet ? 'Inlet' : 'Outlet'} valve on ${tankTag(e.tankId)} · rated ${e.ratedFlowM3h.toStringAsFixed(0)} m³/h',
            style: theme.textTheme.bodyMedium,
          ),
          Text('Current flow: ${e.flowM3h.toStringAsFixed(1)} m³/h · updated ${formatTime(e.updatedAt)}', style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          EquipmentControls(plantId: plantId, equipment: e),
        ]),
      ),
    );
  }
}
