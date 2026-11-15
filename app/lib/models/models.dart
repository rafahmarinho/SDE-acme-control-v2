import 'package:flutter/foundation.dart';

/// Typed rows read from Supabase (RLS-scoped). Parsing is defensive: numeric columns arrive as
/// int or double from PostgREST, and unknown enum values fall back to a safe default.

double _num(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
DateTime _ts(Object? v) => v is String ? DateTime.parse(v).toLocal() : DateTime.fromMillisecondsSinceEpoch(0);
DateTime? _tsOrNull(Object? v) => v is String ? DateTime.parse(v).toLocal() : null;

enum Role { operator, engineer, supervisor, maintenance }

Role? roleFrom(String? value) => Role.values.where((r) => r.name == value).firstOrNull;

String roleLabel(Role r) => switch (r) {
      Role.operator => 'Operator',
      Role.engineer => 'Engineer',
      Role.supervisor => 'Supervisor',
      Role.maintenance => 'Maintenance',
    };

@immutable
class Plant {
  const Plant({required this.id, required this.name, this.locationLabel, required this.role});
  final String id;
  final String name;
  final String? locationLabel;
  final Role? role;
}

@immutable
class Tank {
  const Tank({
    required this.id,
    required this.tag,
    required this.name,
    required this.capacityM3,
    required this.levelPct,
    required this.lowLimitPct,
    required this.highLimitPct,
    required this.pressureBar,
  });
  final String id, tag, name;
  final double capacityM3, levelPct, lowLimitPct, highLimitPct, pressureBar;

  static const columns = 'id, tag, name, capacity_m3, level_pct, low_limit_pct, high_limit_pct, pressure_bar';
  factory Tank.fromRow(Map<String, dynamic> r) => Tank(
        id: r['id'] as String,
        tag: r['tag'] as String,
        name: r['name'] as String,
        capacityM3: _num(r['capacity_m3']),
        levelPct: _num(r['level_pct']),
        lowLimitPct: _num(r['low_limit_pct']),
        highLimitPct: _num(r['high_limit_pct']),
        pressureBar: _num(r['pressure_bar']),
      );

  double get volumeM3 => capacityM3 * levelPct / 100;
  bool get isLow => levelPct <= lowLimitPct;
  bool get isHigh => levelPct >= highLimitPct;
}

/// Shared shape of pumps and valves (requested vs. actual state, mode, maintenance lockout).
@immutable
abstract class Equipment {
  const Equipment();
  String get id;
  String get tag;
  String get name;
  String get kind; // 'pump' | 'valve'
  String get requestedState;
  String get actualState;
  String get mode;
  bool get inMaintenance;
  double get flowM3h;
  double get ratedFlowM3h;
  DateTime get updatedAt;

  bool get isAuto => mode == 'auto';
  bool get isActive => actualState == 'on' || actualState == 'open';
  bool get isRequestedActive => requestedState == 'on' || requestedState == 'open';
  bool get mismatch => requestedState != actualState;
}

@immutable
class Pump extends Equipment {
  const Pump({
    required this.id,
    required this.tag,
    required this.name,
    required this.sourceTankId,
    required this.destTankId,
    required this.ratedFlowM3h,
    required this.requestedState,
    required this.actualState,
    required this.mode,
    required this.inMaintenance,
    required this.flowM3h,
    required this.updatedAt,
  });
  @override
  final String id, tag, name;
  final String sourceTankId, destTankId;
  @override
  final double ratedFlowM3h, flowM3h;
  @override
  final String requestedState, actualState, mode;
  @override
  final bool inMaintenance;
  @override
  final DateTime updatedAt;
  @override
  String get kind => 'pump';

  static const columns =
      'id, tag, name, source_tank_id, dest_tank_id, rated_flow_m3h, requested_state, actual_state, mode, in_maintenance, flow_m3h, updated_at';
  factory Pump.fromRow(Map<String, dynamic> r) => Pump(
        id: r['id'] as String,
        tag: r['tag'] as String,
        name: r['name'] as String,
        sourceTankId: r['source_tank_id'] as String,
        destTankId: r['dest_tank_id'] as String,
        ratedFlowM3h: _num(r['rated_flow_m3h']),
        requestedState: r['requested_state'] as String? ?? 'off',
        actualState: r['actual_state'] as String? ?? 'off',
        mode: r['mode'] as String? ?? 'manual',
        inMaintenance: r['in_maintenance'] as bool? ?? false,
        flowM3h: _num(r['flow_m3h']),
        updatedAt: _ts(r['updated_at']),
      );
}

@immutable
class Valve extends Equipment {
  const Valve({
    required this.id,
    required this.tag,
    required this.name,
    required this.tankId,
    required this.direction,
    required this.ratedFlowM3h,
    required this.requestedState,
    required this.actualState,
    required this.mode,
    required this.inMaintenance,
    required this.flowM3h,
    required this.updatedAt,
  });
  @override
  final String id, tag, name;
  final String tankId, direction;
  @override
  final double ratedFlowM3h, flowM3h;
  @override
  final String requestedState, actualState, mode;
  @override
  final bool inMaintenance;
  @override
  final DateTime updatedAt;
  @override
  String get kind => 'valve';
  bool get isInlet => direction == 'inlet';

  static const columns =
      'id, tag, name, tank_id, direction, rated_flow_m3h, requested_state, actual_state, mode, in_maintenance, flow_m3h, updated_at';
  factory Valve.fromRow(Map<String, dynamic> r) => Valve(
        id: r['id'] as String,
        tag: r['tag'] as String,
        name: r['name'] as String,
        tankId: r['tank_id'] as String,
        direction: r['direction'] as String? ?? 'inlet',
        ratedFlowM3h: _num(r['rated_flow_m3h']),
        requestedState: r['requested_state'] as String? ?? 'closed',
        actualState: r['actual_state'] as String? ?? 'closed',
        mode: r['mode'] as String? ?? 'manual',
        inMaintenance: r['in_maintenance'] as bool? ?? false,
        flowM3h: _num(r['flow_m3h']),
        updatedAt: _ts(r['updated_at']),
      );
}

/// Live process state of one plant (tanks, pumps, valves).
@immutable
class PlantProcess {
  const PlantProcess({required this.tanks, required this.pumps, required this.valves, required this.fetchedAt, this.offline = false});
  final List<Tank> tanks;
  final List<Pump> pumps;
  final List<Valve> valves;
  final DateTime fetchedAt;

  /// True when rendered from the encrypted offline snapshot (read-only).
  final bool offline;

  List<Equipment> get equipment => [...pumps, ...valves];
  Tank? tankById(String id) => tanks.where((t) => t.id == id).firstOrNull;

  PlantProcess copyWith({List<Tank>? tanks, List<Pump>? pumps, List<Valve>? valves, bool? offline}) => PlantProcess(
        tanks: tanks ?? this.tanks,
        pumps: pumps ?? this.pumps,
        valves: valves ?? this.valves,
        fetchedAt: DateTime.now(),
        offline: offline ?? this.offline,
      );
}

@immutable
class Alarm {
  const Alarm({
    required this.id,
    required this.tag,
    required this.severity,
    required this.message,
    required this.active,
    required this.raisedAt,
    this.clearedAt,
    this.acknowledgedAt,
  });
  final String id, tag, severity, message;
  final bool active;
  final DateTime raisedAt;
  final DateTime? clearedAt, acknowledgedAt;
  bool get acknowledged => acknowledgedAt != null;

  static const columns = 'id, tag, severity, message, active, raised_at, cleared_at, acknowledged_at';
  factory Alarm.fromRow(Map<String, dynamic> r) => Alarm(
        id: r['id'] as String,
        tag: r['tag'] as String,
        severity: r['severity'] as String? ?? 'low',
        message: r['message'] as String? ?? '',
        active: r['active'] as bool? ?? false,
        raisedAt: _ts(r['raised_at']),
        clearedAt: _tsOrNull(r['cleared_at']),
        acknowledgedAt: _tsOrNull(r['acknowledged_at']),
      );
}

const alarmSeverities = ['critical', 'high', 'medium', 'low'];

@immutable
class Setpoint {
  const Setpoint({required this.id, required this.tag, required this.description, required this.value, required this.unit, required this.minValue, required this.maxValue});
  final String id, tag, description, unit;
  final double value, minValue, maxValue;

  static const columns = 'id, tag, description, value, unit, min_value, max_value';
  factory Setpoint.fromRow(Map<String, dynamic> r) => Setpoint(
        id: r['id'] as String,
        tag: r['tag'] as String,
        description: r['description'] as String? ?? '',
        value: _num(r['value']),
        unit: r['unit'] as String? ?? '',
        minValue: _num(r['min_value']),
        maxValue: _num(r['max_value']),
      );
}

@immutable
class SetpointProposal {
  const SetpointProposal({
    required this.id,
    required this.setpointId,
    required this.proposedValue,
    required this.reason,
    required this.proposedBy,
    required this.status,
    required this.createdAt,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewComment,
  });
  final String id, setpointId, reason, proposedBy, status;
  final double proposedValue;
  final DateTime createdAt;
  final String? reviewedBy, reviewComment;
  final DateTime? reviewedAt;
  bool get pending => status == 'pending';

  static const columns = 'id, setpoint_id, proposed_value, reason, proposed_by, status, reviewed_by, reviewed_at, review_comment, created_at';
  factory SetpointProposal.fromRow(Map<String, dynamic> r) => SetpointProposal(
        id: r['id'] as String,
        setpointId: r['setpoint_id'] as String,
        proposedValue: _num(r['proposed_value']),
        reason: r['reason'] as String? ?? '',
        proposedBy: r['proposed_by'] as String,
        status: r['status'] as String? ?? 'pending',
        createdAt: _ts(r['created_at']),
        reviewedBy: r['reviewed_by'] as String?,
        reviewedAt: _tsOrNull(r['reviewed_at']),
        reviewComment: r['review_comment'] as String?,
      );
}

@immutable
class PlantEvent {
  const PlantEvent({required this.id, required this.ts, required this.type, required this.message, this.actor});
  final int id;
  final DateTime ts;
  final String type, message;
  final String? actor;

  static const columns = 'id, ts, type, message, actor';
  factory PlantEvent.fromRow(Map<String, dynamic> r) => PlantEvent(
        id: (r['id'] as num).toInt(),
        ts: _ts(r['ts']),
        type: r['type'] as String? ?? '',
        message: r['message'] as String? ?? '',
        actor: r['actor'] as String?,
      );
}

@immutable
class MaintenanceOrder {
  const MaintenanceOrder({
    required this.id,
    required this.equipmentTag,
    required this.description,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id, equipmentTag, description, status, createdBy;
  final DateTime createdAt, updatedAt;

  static const columns = 'id, equipment_tag, description, status, created_by, created_at, updated_at';
  factory MaintenanceOrder.fromRow(Map<String, dynamic> r) => MaintenanceOrder(
        id: r['id'] as String,
        equipmentTag: r['equipment_tag'] as String? ?? '',
        description: r['description'] as String? ?? '',
        status: r['status'] as String? ?? 'open',
        createdBy: r['created_by'] as String,
        createdAt: _ts(r['created_at']),
        updatedAt: _ts(r['updated_at'] ?? r['created_at']),
      );
}

const maintenanceStatuses = ['open', 'in_progress', 'done'];

String statusLabel(String s) => s.isEmpty ? s : (s[0].toUpperCase() + s.substring(1)).replaceAll('_', ' ');

@immutable
class TrendPoint {
  const TrendPoint(this.ts, this.value);
  final DateTime ts;
  final double value;
}

@immutable
class TrendSeries {
  const TrendSeries({required this.tag, required this.unit, required this.points});
  final String tag, unit;
  final List<TrendPoint> points; // oldest first
}

@immutable
class TrendTag {
  const TrendTag(this.tag, this.unit);
  final String tag, unit;
}

@immutable
class EquipmentHit {
  const EquipmentHit({required this.kind, required this.id, required this.tag, required this.name});
  final String kind, id, tag, name;
}
