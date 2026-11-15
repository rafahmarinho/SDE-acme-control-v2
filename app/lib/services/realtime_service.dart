import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tables published to Supabase Realtime (see migrations). RLS applies to every subscriber.
const realtimeTables = ['tanks', 'pumps', 'valves', 'alarms', 'events', 'setpoint_proposals', 'maintenance_orders'];

/// Realtime process updates. Per the PRD, updates PAUSE when the app goes to background and
/// RESUME when it returns or connectivity comes back. No Android background/foreground service
/// is used (nothing exported, nothing running while backgrounded).
class RealtimeService with WidgetsBindingObserver {
  RealtimeService(this._supabase, {Connectivity? connectivity}) : _connectivity = connectivity ?? Connectivity();

  final SupabaseClient _supabase;
  final Connectivity _connectivity;
  RealtimeChannel? _channel;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  String? _plantId;
  bool _disposed = false;
  void Function(String table, Map<String, dynamic> row)? onChange;

  /// Called after the subscription is (re)established, so callers can re-fetch anything that
  /// changed while updates were paused.
  void Function()? onResumed;

  void start(String plantId) {
    _plantId = plantId;
    WidgetsBinding.instance.addObserver(this);
    _connSub = _connectivity.onConnectivityChanged.listen((r) {
      if (r.contains(ConnectivityResult.none)) {
        pause();
      } else {
        resume();
      }
    });
    resume(notify: false);
  }

  void resume({bool notify = true}) {
    final plantId = _plantId;
    if (_disposed || plantId == null || _channel != null) return;
    final channel = _supabase.channel('plant:$plantId');
    for (final table in realtimeTables) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'plant_id', value: plantId),
        callback: (payload) => onChange?.call(table, payload.newRecord),
      );
    }
    _channel = channel..subscribe(); // RLS applies to realtime subscribers
    if (notify) onResumed?.call();
  }

  Future<void> pause() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) await _supabase.removeChannel(channel);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) pause();
    if (state == AppLifecycleState.resumed) resume();
  }

  Future<void> dispose() async {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    await _connSub?.cancel();
    await pause();
  }
}
