import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'secure_store.dart';

/// Whitelisted, read-only snapshot shown when the device is offline (PRD). It contains only
/// process values and active alarm summaries - no tokens, personal data, notes, photos or
/// pending commands. Control actions are never queued offline.
@immutable
class OfflineSnapshot {
  const OfflineSnapshot({required this.takenAt, required this.plantId, required this.tanks, required this.activeAlarms});

  final DateTime takenAt;
  final String plantId;
  final List<TankReading> tanks;
  final List<AlarmSummary> activeAlarms;

  Map<String, Object?> toJson() => {
        'takenAt': takenAt.toUtc().toIso8601String(),
        'plantId': plantId,
        'tanks': tanks.map((t) => t.toJson()).toList(),
        'activeAlarms': activeAlarms.map((a) => a.toJson()).toList(),
      };

  static OfflineSnapshot fromJson(Map<String, dynamic> j) => OfflineSnapshot(
        takenAt: DateTime.parse(j['takenAt'] as String),
        plantId: j['plantId'] as String,
        tanks: (j['tanks'] as List).map((e) => TankReading.fromJson(e as Map<String, dynamic>)).toList(),
        activeAlarms: (j['activeAlarms'] as List).map((e) => AlarmSummary.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

@immutable
class TankReading {
  const TankReading({required this.tag, required this.levelPct, required this.pressureBar});
  final String tag;
  final double levelPct;
  final double pressureBar;
  Map<String, Object?> toJson() => {'tag': tag, 'levelPct': levelPct, 'pressureBar': pressureBar};
  static TankReading fromJson(Map<String, dynamic> j) =>
      TankReading(tag: j['tag'] as String, levelPct: (j['levelPct'] as num).toDouble(), pressureBar: (j['pressureBar'] as num).toDouble());
}

@immutable
class AlarmSummary {
  const AlarmSummary({required this.tag, required this.severity, required this.message});
  final String tag;
  final String severity;
  final String message;
  Map<String, Object?> toJson() => {'tag': tag, 'severity': severity, 'message': message};
  static AlarmSummary fromJson(Map<String, dynamic> j) =>
      AlarmSummary(tag: j['tag'] as String, severity: j['severity'] as String, message: j['message'] as String);
}

/// Encrypted offline cache with a 24 h TTL. Disabled on web, where data is re-fetched from
/// Supabase after reload instead of being stored in the browser.
class OfflineCacheService {
  OfflineCacheService(this._store);

  static const ttl = Duration(hours: 24);
  static const _name = 'offline_snapshot';
  final SecureStore _store;

  bool get enabled => !kIsWeb;

  Future<void> save(OfflineSnapshot snapshot) async {
    if (!enabled) return;
    await _store.put(_name, Uint8List.fromList(utf8.encode(jsonEncode(snapshot.toJson()))));
  }

  Future<OfflineSnapshot?> read({DateTime? now}) async {
    if (!enabled) return null;
    final bytes = await _store.get(_name);
    if (bytes == null) return null;
    final snapshot = OfflineSnapshot.fromJson(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
    if ((now ?? DateTime.now()).difference(snapshot.takenAt) > ttl) {
      await wipe();
      return null;
    }
    return snapshot;
  }

  /// Removes cached data and its key (logout, "Clear offline data", expiry).
  Future<void> wipe() async {
    if (!enabled) return;
    await _store.delete(_name);
    await _store.wipeKey();
  }
}
