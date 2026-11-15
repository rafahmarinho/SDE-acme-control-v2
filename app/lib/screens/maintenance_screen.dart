import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/permissions.dart';
import '../app/plant_providers.dart';
import '../components/equipment_controls.dart';
import '../components/plant_scaffold.dart';
import '../components/state_views.dart';
import '../models/models.dart';

/// Maintenance: work orders (create / progress, maintenance role - RLS enforced and audited by a
/// database trigger) and equipment lockout (API, recent login). Locked-out equipment cannot run.
class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({super.key, required this.plantId});
  final String plantId;
  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  String? _status;
  String _query = '';

  OrderQuery get _q => (plantId: widget.plantId, status: _status);

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(plantRoleProvider(widget.plantId)).valueOrNull;
    final canWrite = uiAllows(role, UiAction.maintenanceWrite);
    final online = isOnline(ref);
    final orders = ref.watch(maintenanceOrdersProvider(_q));
    final process = ref.watch(plantProcessProvider(widget.plantId)).valueOrNull;
    final wide = MediaQuery.sizeOf(context).width >= wideLayoutBreakpoint;

    final orderList = Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(label: const Text('All'), selected: _status == null, onSelected: (_) => setState(() => _status = null)),
          for (final s in maintenanceStatuses) ChoiceChip(label: Text(statusLabel(s)), selected: _status == s, onSelected: (_) => setState(() => _status = s)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: TextField(
          maxLength: 64,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search work orders', counterText: '', isDense: true, border: OutlineInputBorder()),
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        ),
      ),
      Expanded(
        child: orders.when(
          skipLoadingOnRefresh: true,
          loading: () => const LoadingView(label: 'Loading work orders…'),
          error: (_, __) => ErrorView(message: 'Could not load work orders.', onRetry: () => ref.invalidate(maintenanceOrdersProvider(_q))),
          data: (list) {
            final filtered = list.where((o) => _query.isEmpty || o.equipmentTag.toLowerCase().contains(_query) || o.description.toLowerCase().contains(_query)).toList();
            if (filtered.isEmpty) return const EmptyView(message: 'No work orders in this view.', icon: Icons.build_circle_outlined);
            return ListView(padding: const EdgeInsets.all(12), children: [
              for (final o in filtered) _OrderCard(plantId: widget.plantId, order: o, canWrite: canWrite && online, query: _q),
            ]);
          },
        ),
      ),
    ]);

    final lockouts = ListView(padding: const EdgeInsets.all(12), children: [
      Text('Equipment lockout', style: Theme.of(context).textTheme.titleMedium),
      Text(
        canWrite ? 'Locking out forces the equipment to a safe state. A recent login is required.' : 'Only the maintenance team can lock out equipment.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      if (process == null) const LoadingView(),
      if (process != null && process.offline) const EmptyView(message: 'Lockout requires a connection.', icon: Icons.cloud_off),
      if (process != null && !process.offline)
        for (final e in process.equipment)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${e.tag} · ${e.name}', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                EquipmentControls(plantId: widget.plantId, equipment: e),
              ]),
            ),
          ),
    ]);

    return PlantScaffold(
      plantId: widget.plantId,
      section: PlantSection.maintenance,
      floatingActionButton: canWrite && process != null && !process.offline
          ? FloatingActionButton.extended(onPressed: online ? () => _create(process) : null, icon: const Icon(Icons.add), label: const Text('New work order'))
          : null,
      body: wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(flex: 3, child: orderList), const VerticalDivider(width: 1), Expanded(flex: 2, child: lockouts)])
          : DefaultTabController(
              length: 2,
              child: Column(children: [
                const TabBar(tabs: [Tab(text: 'Work orders'), Tab(text: 'Lockout')]),
                Expanded(child: TabBarView(children: [orderList, lockouts])),
              ]),
            ),
    );
  }

  Future<void> _create(PlantProcess process) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _NewOrderSheet(plantId: widget.plantId, tags: [...process.tanks.map((t) => t.tag), ...process.equipment.map((e) => e.tag)]..sort()),
    );
    if (created == true) ref.invalidate(maintenanceOrdersProvider(_q));
  }
}

class _OrderCard extends ConsumerStatefulWidget {
  const _OrderCard({required this.plantId, required this.order, required this.canWrite, required this.query});
  final String plantId;
  final MaintenanceOrder order;
  final bool canWrite;
  final OrderQuery query;
  @override
  ConsumerState<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends ConsumerState<_OrderCard> {
  bool _busy = false;

  Future<void> _setStatus(String status) async {
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).updateMaintenanceStatus(widget.plantId, widget.order.id, status);
      ref.invalidate(maintenanceOrdersProvider(widget.query));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Work order marked as ${statusLabel(status).toLowerCase()}.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The work order could not be updated.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final next = switch (o.status) { 'open' => 'in_progress', 'in_progress' => 'done', _ => null };
    final names = ref.watch(displayNamesProvider(o.createdBy)).valueOrNull ?? const {};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(switch (o.status) { 'done' => Icons.task_alt, 'in_progress' => Icons.engineering, _ => Icons.pending_actions }),
            const SizedBox(width: 8),
            Expanded(child: Text(o.equipmentTag, style: Theme.of(context).textTheme.titleSmall)),
            Chip(label: Text(statusLabel(o.status)), visualDensity: VisualDensity.compact),
          ]),
          const SizedBox(height: 4),
          SelectableText(o.description), // plain text only (T36)
          const SizedBox(height: 4),
          Text('Created by ${names[o.createdBy] ?? 'Unknown user'} · ${formatTime(o.createdAt)} · updated ${formatTime(o.updatedAt)}', style: Theme.of(context).textTheme.bodySmall),
          if (widget.canWrite && next != null)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: _busy ? null : () => _setStatus(next),
                icon: Icon(next == 'done' ? Icons.check : Icons.play_arrow),
                label: Text(next == 'done' ? 'Mark done' : 'Start work'),
              ),
            ),
        ]),
      ),
    );
  }
}

class _NewOrderSheet extends ConsumerStatefulWidget {
  const _NewOrderSheet({required this.plantId, required this.tags});
  final String plantId;
  final List<String> tags;
  @override
  ConsumerState<_NewOrderSheet> createState() => _NewOrderSheetState();
}

class _NewOrderSheetState extends ConsumerState<_NewOrderSheet> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  String? _tag;
  bool _busy = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).createMaintenanceOrder(widget.plantId, _tag!, _description.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The work order could not be created.')));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('New work order', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _tag,
            decoration: const InputDecoration(labelText: 'Equipment', border: OutlineInputBorder()),
            items: [for (final t in widget.tags) DropdownMenuItem(value: t, child: Text(t))],
            onChanged: (v) => setState(() => _tag = v),
            validator: (v) => v == null ? 'Select the equipment.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            maxLength: 2000,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Description of the work', border: OutlineInputBorder()),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Describe the work to be done.' : null,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _busy ? null : _submit, icon: const Icon(Icons.add_task), label: const Text('Create work order')),
        ]),
      ),
    );
  }
}
