import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_repository.dart';
import '../models/models.dart';
import '../services/offline_cache_service.dart';
import '../services/realtime_service.dart';
import 'providers.dart';

/// Data providers for the plant screens. Every provider watches [sessionProvider] so all user
/// data is dropped automatically on logout (T164).

final repositoryProvider = Provider<SupabaseRepository>((ref) {
  ref.watch(sessionProvider);
  return SupabaseRepository(ref.watch(supabaseProvider));
});

/// true while the device has a network connection. Control actions are disabled when false.
final onlineProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  yield !(await c.checkConnectivity()).contains(ConnectivityResult.none);
  yield* c.onConnectivityChanged.map((r) => !r.contains(ConnectivityResult.none));
});

bool isOnline(WidgetRef ref) => ref.watch(onlineProvider).valueOrNull ?? true;

final plantsProvider = FutureProvider.autoDispose<List<Plant>>((ref) => ref.watch(repositoryProvider).plants());

/// Caller's role in a plant. Navigation/UX only - the API and RLS enforce (T17, T145).
final plantRoleProvider = FutureProvider.autoDispose.family<Role?, String>((ref, plantId) => ref.watch(repositoryProvider).roleIn(plantId));

final plantNameProvider = Provider.autoDispose.family<String, String>((ref, plantId) {
  final plants = ref.watch(plantsProvider).valueOrNull ?? const [];
  return plants.where((p) => p.id == plantId).firstOrNull?.name ?? 'Plant';
});

/// Realtime change feed for one plant (single channel shared by all screens of that plant).
final plantChangesProvider = StreamProvider.autoDispose.family<String, String>((ref, plantId) {
  ref.watch(sessionProvider);
  final controller = StreamController<String>.broadcast();
  final rt = RealtimeService(ref.watch(supabaseProvider))
    ..onChange = ((table, _) => controller.add(table))
    ..onResumed = (() => controller.add('*'));
  rt.start(plantId);
  ref.onDispose(() async {
    await rt.dispose();
    await controller.close();
  });
  return controller.stream;
});

/// Invalidates the calling provider (debounced) when one of [tables] changes in realtime.
void refreshOnChanges(Ref ref, String plantId, Set<String> tables) {
  Timer? debounce;
  ref.listen(plantChangesProvider(plantId), (_, next) {
    final table = next.valueOrNull;
    if (table == null || (table != '*' && !tables.contains(table))) return;
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), ref.invalidateSelf);
  });
  ref.onDispose(() => debounce?.cancel());
}

/// Live process state. Falls back to the encrypted offline snapshot (mobile) when the network
/// is unavailable; a successful fetch refreshes that snapshot with whitelisted fields only.
final plantProcessProvider = FutureProvider.autoDispose.family<PlantProcess, String>((ref, plantId) async {
  refreshOnChanges(ref, plantId, const {'tanks', 'pumps', 'valves'});
  final repo = ref.watch(repositoryProvider);
  final cache = ref.watch(offlineCacheProvider);
  try {
    final process = await repo.process(plantId);
    unawaited(_saveSnapshot(repo, cache, plantId, process));
    return process;
  } catch (_) {
    final snapshot = await cache.read();
    if (snapshot == null || snapshot.plantId != plantId) rethrow;
    return offlineProcess(snapshot);
  }
});

Future<void> _saveSnapshot(SupabaseRepository repo, OfflineCacheService cache, String plantId, PlantProcess p) async {
  if (!cache.enabled) return;
  try {
    final alarms = await repo.alarms(plantId, activeOnly: true, limit: 20);
    await cache.save(OfflineSnapshot(
      takenAt: DateTime.now(),
      plantId: plantId,
      tanks: [for (final t in p.tanks) TankReading(tag: t.tag, levelPct: t.levelPct, pressureBar: t.pressureBar)],
      activeAlarms: [for (final a in alarms) AlarmSummary(tag: a.tag, severity: a.severity, message: a.message)],
    ));
  } catch (_) {
    // Snapshot is best-effort; never block the live view.
  }
}

/// Read-only process built from the offline snapshot (tank readings only).
PlantProcess offlineProcess(OfflineSnapshot s) => PlantProcess(
      tanks: [
        for (final t in s.tanks)
          Tank(id: t.tag, tag: t.tag, name: t.tag, capacityM3: 1, levelPct: t.levelPct, lowLimitPct: 5, highLimitPct: 95, pressureBar: t.pressureBar),
      ],
      pumps: const [],
      valves: const [],
      fetchedAt: s.takenAt,
      offline: true,
    );

/// Offline snapshot (for the alarm summary shown while disconnected).
final offlineSnapshotProvider = FutureProvider.autoDispose<OfflineSnapshot?>((ref) {
  ref.watch(sessionProvider);
  return ref.watch(offlineCacheProvider).read();
});

final activeAlarmCountProvider = FutureProvider.autoDispose.family<int, String>((ref, plantId) {
  refreshOnChanges(ref, plantId, const {'alarms'});
  return ref.watch(repositoryProvider).activeAlarmCount(plantId);
});

typedef AlarmQuery = ({String plantId, bool activeOnly, String? severity});

final alarmsProvider = FutureProvider.autoDispose.family<List<Alarm>, AlarmQuery>((ref, q) {
  refreshOnChanges(ref, q.plantId, const {'alarms'});
  return ref.watch(repositoryProvider).alarms(q.plantId, activeOnly: q.activeOnly, severity: q.severity, limit: 200);
});

final setpointsProvider = FutureProvider.autoDispose.family<List<Setpoint>, String>((ref, plantId) {
  refreshOnChanges(ref, plantId, const {'setpoint_proposals'});
  return ref.watch(repositoryProvider).setpoints(plantId);
});

final proposalsProvider = FutureProvider.autoDispose.family<List<SetpointProposal>, String>((ref, plantId) {
  refreshOnChanges(ref, plantId, const {'setpoint_proposals'});
  return ref.watch(repositoryProvider).proposals(plantId);
});

final displayNamesProvider = FutureProvider.autoDispose.family<Map<String, String>, String>((ref, idsKey) {
  final ids = idsKey.isEmpty ? const <String>[] : idsKey.split(',');
  return ref.watch(repositoryProvider).displayNames(ids);
});

typedef EventQuery = ({String plantId, String? typePrefix});

final eventsProvider = FutureProvider.autoDispose.family<List<PlantEvent>, EventQuery>((ref, q) {
  refreshOnChanges(ref, q.plantId, const {'events'});
  return ref.watch(repositoryProvider).events(q.plantId, typePrefix: q.typePrefix, limit: 150);
});

typedef OrderQuery = ({String plantId, String? status});

final maintenanceOrdersProvider = FutureProvider.autoDispose.family<List<MaintenanceOrder>, OrderQuery>((ref, q) {
  refreshOnChanges(ref, q.plantId, const {'maintenance_orders'});
  return ref.watch(repositoryProvider).maintenanceOrders(q.plantId, status: q.status);
});

final trendTagsProvider = FutureProvider.autoDispose.family<List<TrendTag>, String>((ref, plantId) => ref.watch(repositoryProvider).trendTags(plantId));

typedef TrendQuery = ({String plantId, String tag, Duration range});

final trendProvider = FutureProvider.autoDispose.family<TrendSeries, TrendQuery>((ref, q) {
  refreshOnChanges(ref, q.plantId, const {'tanks', 'pumps'});
  return ref.watch(repositoryProvider).trend(q.plantId, q.tag, q.range);
});
