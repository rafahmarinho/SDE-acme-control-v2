import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

sealed class CommandException implements Exception {
  const CommandException(this.message);
  final String message;
  @override
  String toString() => message;
}

class OfflineException extends CommandException {
  const OfflineException() : super('Control actions require a connection. Reconnect and try again.');
}

class SessionExpiredException extends CommandException {
  const SessionExpiredException() : super('Your session has expired. Please sign in again.');
}

class ReauthenticationRequiredException extends CommandException {
  const ReauthenticationRequiredException() : super('Please confirm your password to perform this action.');
}

class CommandRejectedException extends CommandException {
  const CommandRejectedException(super.message, this.code);
  final String code;
}

/// Friendly English messages for API error codes; raw server details are never shown.
const _messages = {
  'source_tank_empty': 'The pump cannot start: the source tank is empty.',
  'equipment_in_maintenance': 'The equipment is in maintenance.',
  'equipment_in_auto_mode': 'Switch the equipment to manual mode first.',
  'forbidden': 'You do not have permission to perform this action.',
  'not_found': 'The item was not found.',
  'out_of_range': 'The value is outside the allowed range.',
  'separation_of_duties': 'You cannot review your own proposal.',
  'already_reviewed': 'This proposal has already been reviewed.',
  'rate_limited': 'Too many requests. Please wait and try again.',
  'invalid_request': 'The request was not valid.',
};

/// Sends control actions to the Vercel API. Every call: requires connectivity (never queued),
/// sends the Supabase access token as a Bearer header (no cookies), and uses a JSON body.
/// The server performs authorization and interlocks; the client never decides permissions.
class CommandService {
  CommandService(this._supabase, {http.Client? client, Connectivity? connectivity})
      : _http = client ?? http.Client(),
        _connectivity = connectivity ?? Connectivity();

  final SupabaseClient _supabase;
  final http.Client _http;
  final Connectivity _connectivity;

  /// Called when the server reports the session is invalid, to run full logout cleanup.
  void Function()? onSessionExpired;

  Future<Map<String, dynamic>> _post(String path, Map<String, Object?> body) async {
    final status = await _connectivity.checkConnectivity();
    if (status.contains(ConnectivityResult.none)) throw const OfflineException();
    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null) throw const SessionExpiredException();

    final http.Response res;
    try {
      res = await _http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}$path'),
            headers: {'authorization': 'Bearer $token', 'content-type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const CommandRejectedException('The server did not respond. The command state is unknown; check the actual state.', 'timeout');
    }

    final decoded = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return decoded;
    final code = decoded['error'] as String? ?? 'error';
    if (res.statusCode == 401 && code == 'reauthentication_required') throw const ReauthenticationRequiredException();
    if (res.statusCode == 401) {
      onSessionExpired?.call();
      throw const SessionExpiredException();
    }
    throw CommandRejectedException(_messages[code] ?? 'The action could not be completed.', code);
  }

  Future<Map<String, dynamic>> setPump(String plantId, String pumpId, bool on) =>
      _post('/api/commands', {'type': 'pump', 'plantId': plantId, 'equipmentId': pumpId, 'state': on ? 'on' : 'off'});

  Future<Map<String, dynamic>> setValve(String plantId, String valveId, bool open) =>
      _post('/api/commands', {'type': 'valve', 'plantId': plantId, 'equipmentId': valveId, 'state': open ? 'open' : 'closed'});

  Future<Map<String, dynamic>> setMode(String plantId, String kind, String equipmentId, bool auto) =>
      _post('/api/commands', {'type': 'mode', 'plantId': plantId, 'equipmentKind': kind, 'equipmentId': equipmentId, 'mode': auto ? 'auto' : 'manual'});

  Future<Map<String, dynamic>> setLockout(String plantId, String kind, String equipmentId, bool inMaintenance) =>
      _post('/api/commands', {'type': 'lockout', 'plantId': plantId, 'equipmentKind': kind, 'equipmentId': equipmentId, 'inMaintenance': inMaintenance});

  Future<Map<String, dynamic>> proposeSetpoint(String plantId, String setpointId, double value, String reason) =>
      _post('/api/setpoints', {'action': 'propose', 'plantId': plantId, 'setpointId': setpointId, 'value': value, 'reason': reason});

  Future<Map<String, dynamic>> reviewSetpoint(String plantId, String proposalId, bool approve, {String? comment}) =>
      _post('/api/setpoints', {'action': 'review', 'plantId': plantId, 'proposalId': proposalId, 'decision': approve ? 'approve' : 'reject', if (comment != null) 'comment': comment});
}
