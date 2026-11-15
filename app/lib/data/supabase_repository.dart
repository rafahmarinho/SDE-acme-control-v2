import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Database access layer: typed, read-mostly queries against Supabase PostgreSQL.
///
/// Security (skills/database-security, skills/api-security):
/// - Explicit column lists only (never a wildcard select), so new columns are never exposed by accident.
/// - Every list query is bounded with `.limit()`; trends go through the `trend_values` RPC,
///   which rejects ranges over 7 days / more than 2000 points server-side.
/// - Filters use the typed builder (`eq`, `inFilter`) or bound RPC parameters; user text is
///   never concatenated into a PostgREST filter string.
/// - RLS decides what the caller may read. The only direct writes are the ones the RLS policies
///   and column grants allow (maintenance orders, shift handover). Process changes go through the
///   audited API (CommandService).
class SupabaseRepository {
  SupabaseRepository(this._db);
  final SupabaseClient _db;

  static const maxEvents = 200;
  static const maxAlarms = 200;
  static const maxOrders = 200;
  static const maxProposals = 100;
  static const maxTrendRange = Duration(days: 7);
  static const maxTrendPoints = 2000;

  String? get userId => _db.auth.currentUser?.id;

  Future<List<Plant>> plants() async {
    final uid = userId;
    if (uid == null) return const [];
    final results = await Future.wait([
      _db.from('plants').select('id, name, location_label').order('name').limit(50),
      _db.from('plant_members').select('plant_id, role').eq('user_id', uid).limit(50),
    ]);
    final roles = {for (final m in results[1]) m['plant_id'] as String: roleFrom(m['role'] as String?)};
    return [
      for (final p in results[0])
        Plant(id: p['id'] as String, name: p['name'] as String, locationLabel: p['location_label'] as String?, role: roles[p['id']]),
    ];
  }

  /// Caller's role in a plant (from plant_members under RLS). UX only: the API re-checks.
  Future<Role?> roleIn(String plantId) async {
    final uid = userId;
    if (uid == null) return null;
    final row = await _db.from('plant_members').select('role').eq('user_id', uid).eq('plant_id', plantId).maybeSingle();
    return roleFrom(row?['role'] as String?);
  }

  Future<PlantProcess> process(String plantId) async {
    final results = await Future.wait([
      _db.from('tanks').select(Tank.columns).eq('plant_id', plantId).order('tag').limit(20),
      _db.from('pumps').select(Pump.columns).eq('plant_id', plantId).order('tag').limit(20),
      _db.from('valves').select(Valve.columns).eq('plant_id', plantId).order('tag').limit(20),
    ]);
    return PlantProcess(
      tanks: results[0].map(Tank.fromRow).toList(),
      pumps: results[1].map(Pump.fromRow).toList(),
      valves: results[2].map(Valve.fromRow).toList(),
      fetchedAt: DateTime.now(),
    );
  }

  Future<List<EquipmentHit>> searchEquipment(String plantId, String query) async {
    final rows = await _db.rpc<List<dynamic>>('search_equipment', params: {'p_plant': plantId, 'p_q': query.trim()});
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        EquipmentHit(kind: r['kind'] as String, id: r['id'] as String, tag: r['tag'] as String, name: r['name'] as String),
    ];
  }

  Future<List<Alarm>> alarms(String plantId, {bool activeOnly = false, String? severity, int limit = 100}) async {
    var q = _db.from('alarms').select(Alarm.columns).eq('plant_id', plantId);
    if (activeOnly) q = q.eq('active', true);
    if (severity != null && alarmSeverities.contains(severity)) q = q.eq('severity', severity);
    return (await q.order('raised_at', ascending: false).limit(limit.clamp(1, maxAlarms))).map(Alarm.fromRow).toList();
  }

  Future<int> activeAlarmCount(String plantId) async {
    final rows = await _db.from('alarms').select('id').eq('plant_id', plantId).eq('active', true).limit(maxAlarms);
    return rows.length;
  }

  Future<List<Setpoint>> setpoints(String plantId) async =>
      (await _db.from('setpoints').select(Setpoint.columns).eq('plant_id', plantId).order('tag').limit(50)).map(Setpoint.fromRow).toList();

  Future<List<SetpointProposal>> proposals(String plantId) async => (await _db
          .from('setpoint_proposals')
          .select(SetpointProposal.columns)
          .eq('plant_id', plantId)
          .order('created_at', ascending: false)
          .limit(maxProposals))
      .map(SetpointProposal.fromRow)
      .toList();

  /// Display names for user ids (profiles RLS: self + users sharing a plant).
  Future<Map<String, String>> displayNames(Iterable<String> ids) async {
    final unique = ids.toSet().take(100).toList();
    if (unique.isEmpty) return const {};
    final rows = await _db.from('profiles').select('id, display_name').inFilter('id', unique).limit(100);
    return {for (final r in rows) r['id'] as String: r['display_name'] as String};
  }

  Future<List<PlantEvent>> events(String plantId, {String? typePrefix, int limit = 100}) async {
    var q = _db.from('events').select(PlantEvent.columns).eq('plant_id', plantId);
    if (typePrefix != null && RegExp(r'^[a-z_]{1,32}$').hasMatch(typePrefix)) q = q.like('type', '$typePrefix.%');
    return (await q.order('ts', ascending: false).limit(limit.clamp(1, maxEvents))).map(PlantEvent.fromRow).toList();
  }

  Future<List<MaintenanceOrder>> maintenanceOrders(String plantId, {String? status}) async {
    var q = _db.from('maintenance_orders').select(MaintenanceOrder.columns).eq('plant_id', plantId);
    if (status != null && maintenanceStatuses.contains(status)) q = q.eq('status', status);
    return (await q.order('created_at', ascending: false).limit(maxOrders)).map(MaintenanceOrder.fromRow).toList();
  }

  /// RLS: only the maintenance role may insert, and created_by must be the caller.
  Future<void> createMaintenanceOrder(String plantId, String equipmentTag, String description) =>
      _db.from('maintenance_orders').insert({'plant_id': plantId, 'equipment_tag': equipmentTag, 'description': description});

  /// RLS + column grant: only `status` may change, only by the maintenance role (trigger audits it).
  Future<void> updateMaintenanceStatus(String plantId, String orderId, String status) async {
    if (!maintenanceStatuses.contains(status)) throw ArgumentError('invalid status');
    await _db.from('maintenance_orders').update({'status': status}).eq('id', orderId).eq('plant_id', plantId);
  }

  Future<List<TrendTag>> trendTags(String plantId) async {
    final rows = await _db.rpc<List<dynamic>>('trend_tags', params: {'p_plant': plantId});
    return [for (final r in rows.cast<Map<String, dynamic>>()) TrendTag(r['tag'] as String, r['unit'] as String)];
  }

  Future<TrendSeries> trend(String plantId, String tag, Duration range) async {
    if (range > maxTrendRange || range <= Duration.zero) throw ArgumentError('range');
    final to = DateTime.now().toUtc();
    final rows = await _db.rpc<List<dynamic>>('trend_values', params: {
      'p_plant': plantId,
      'p_tag': tag,
      'p_from': to.subtract(range).toIso8601String(),
      'p_to': to.add(const Duration(minutes: 1)).toIso8601String(),
      'p_limit': 1000,
    });
    final list = rows.cast<Map<String, dynamic>>();
    final unit = list.isEmpty ? '' : list.first['unit'] as String;
    final points = [
      for (final r in list.reversed) TrendPoint(DateTime.parse(r['ts'] as String).toLocal(), (r['value'] as num).toDouble()),
    ];
    return TrendSeries(tag: tag, unit: unit, points: points);
  }

  /// Supervisor-only audit trail (the RPC raises 42501 for other roles).
  Future<List<Map<String, dynamic>>> auditEntries(String plantId, {int limit = 50}) async {
    final rows = await _db.rpc<List<dynamic>>('audit_entries', params: {'p_plant': plantId, 'p_limit': limit.clamp(1, 200)});
    return rows.cast<Map<String, dynamic>>();
  }
}
