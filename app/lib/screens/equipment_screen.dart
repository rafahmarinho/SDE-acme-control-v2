import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/permissions.dart';
import '../app/plant_providers.dart';
import '../components/equipment_controls.dart';
import '../components/plant_scaffold.dart';
import '../components/state_views.dart';
import '../models/models.dart';
import 'process_view_screen.dart';

/// Equipment (assets) list with search and filters. Search runs through the bound-parameter
/// `search_equipment` RPC (capped at 50 rows); filters are applied to typed values.
class EquipmentScreen extends ConsumerStatefulWidget {
  const EquipmentScreen({super.key, required this.plantId});
  final String plantId;
  @override
  ConsumerState<EquipmentScreen> createState() => _EquipmentScreenState();
}

enum _Kind { all, tank, pump, valve }

enum _Status { any, active, idle, maintenance, mismatch }

class _EquipmentScreenState extends ConsumerState<EquipmentScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  Set<String>? _hits; // ids matching the search (null = no search)
  bool _searching = false;
  bool _searchFailed = false;
  _Kind _kind = _Kind.all;
  _Status _status = _Status.any;

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final query = q.trim();
      if (query.isEmpty) {
        setState(() {
          _hits = null;
          _searchFailed = false;
        });
        return;
      }
      setState(() => _searching = true);
      try {
        final hits = await ref.read(repositoryProvider).searchEquipment(widget.plantId, query);
        if (mounted) setState(() => _hits = hits.map((h) => h.id).toSet());
        _searchFailed = false;
      } catch (_) {
        if (mounted) setState(() => _searchFailed = true);
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final process = ref.watch(plantProcessProvider(widget.plantId));
    return PlantScaffold(
      plantId: widget.plantId,
      section: PlantSection.equipment,
      title: 'Equipment',
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _search,
            maxLength: 64,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching ? const Padding(padding: EdgeInsets.all(12), child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
              labelText: 'Search by tag or name',
              border: const OutlineInputBorder(),
              counterText: '',
              errorText: _searchFailed ? 'Search is unavailable right now.' : null,
            ),
            onChanged: _onSearch,
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            for (final k in _Kind.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(label: Text(switch (k) { _Kind.all => 'All', _Kind.tank => 'Tanks', _Kind.pump => 'Pumps', _Kind.valve => 'Valves' }), selected: _kind == k, onSelected: (_) => setState(() => _kind = k)),
              ),
            const SizedBox(width: 8),
            DropdownButton<_Status>(
              value: _status,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: _Status.any, child: Text('Any status')),
                DropdownMenuItem(value: _Status.active, child: Text('Running / open')),
                DropdownMenuItem(value: _Status.idle, child: Text('Stopped / closed')),
                DropdownMenuItem(value: _Status.maintenance, child: Text('In maintenance')),
                DropdownMenuItem(value: _Status.mismatch, child: Text('Requested ≠ actual')),
              ],
              onChanged: (v) => setState(() => _status = v ?? _Status.any),
            ),
          ]),
        ),
        Expanded(
          child: process.when(
            skipLoadingOnRefresh: true,
            loading: () => const LoadingView(label: 'Loading equipment…'),
            error: (_, __) => ErrorView(message: 'Could not load equipment.', onRetry: () => ref.invalidate(plantProcessProvider(widget.plantId))),
            data: (p) {
              if (p.offline) return const EmptyView(message: 'Equipment details need a connection. The process view shows the last tank readings.', icon: Icons.cloud_off);
              final items = <Object>[
                if (_kind == _Kind.all || _kind == _Kind.tank) ...p.tanks.where((t) => _status == _Status.any),
                if (_kind == _Kind.all || _kind == _Kind.pump) ...p.pumps.where(_matchesStatus),
                if (_kind == _Kind.all || _kind == _Kind.valve) ...p.valves.where(_matchesStatus),
              ].where((x) => _hits == null || _hits!.contains(x is Tank ? x.id : (x as Equipment).id)).toList();
              if (items.isEmpty) return const EmptyView(message: 'No equipment matches the current search and filters.', icon: Icons.search_off);
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(plantProcessProvider(widget.plantId)),
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _tile(context, p, items[i]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  bool _matchesStatus(Equipment e) => switch (_status) {
        _Status.any => true,
        _Status.active => e.isActive,
        _Status.idle => !e.isActive,
        _Status.maintenance => e.inMaintenance,
        _Status.mismatch => e.mismatch,
      };

  Widget _tile(BuildContext context, PlantProcess p, Object item) {
    if (item is Tank) {
      return ListTile(
        minTileHeight: 64,
        leading: const CircleAvatar(child: Icon(Icons.propane_tank_outlined)),
        title: Text('${item.tag} · ${item.name}'),
        subtitle: Text('Tank · ${item.capacityM3.toStringAsFixed(0)} m³ · ${item.pressureBar.toStringAsFixed(2)} bar'),
        trailing: Text('${item.levelPct.toStringAsFixed(1)} %', style: Theme.of(context).textTheme.titleSmall),
        onTap: () => showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (_) => TankDetails(tank: item, plantId: widget.plantId)),
      );
    }
    final e = item as Equipment;
    return ListTile(
      minTileHeight: 72,
      leading: CircleAvatar(
        backgroundColor: e.inMaintenance ? const Color(0x33FB8C00) : (e.isActive ? const Color(0x3343A047) : null),
        child: Icon(e is Pump ? Icons.settings_input_component : Icons.alt_route),
      ),
      title: Text('${e.tag} · ${e.name}'),
      subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: EquipmentStateRow(equipment: e)),
      trailing: Text('${e.flowM3h.toStringAsFixed(1)} m³/h'),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => EquipmentSheet(plantId: widget.plantId, equipmentId: e.id),
      ),
    );
  }
}
