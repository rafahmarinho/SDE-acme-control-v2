import 'package:flutter/material.dart';

import '../models/models.dart';

/// Loading / empty / error states (PRD). Error text is generic: raw server or database details
/// are never shown to the user (T2139).
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = 'Loading…'});
  final String label;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.message, this.icon = Icons.inbox_outlined});
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ]),
        ),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, this.message = 'Something went wrong while loading this data.', this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ],
          ]),
        ),
      );
}

/// Banner shown while the device is offline: data is read-only and control actions are disabled.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.since});
  final DateTime? since;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Icon(Icons.cloud_off, size: 18, color: scheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              since == null
                  ? 'Offline - showing the last available data (read-only). Control actions need a connection.'
                  : 'Offline - last data from ${formatTime(since!)} (read-only). Control actions need a connection.',
              style: TextStyle(color: scheme.onTertiaryContainer),
            ),
          ),
        ]),
      ),
    );
  }
}

String _two(int v) => v.toString().padLeft(2, '0');
String formatTime(DateTime t) => '${t.year}-${_two(t.month)}-${_two(t.day)} ${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
String formatShortTime(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';
String formatNumber(double v, {int digits = 1}) => v.toStringAsFixed(digits);

Color severityColor(BuildContext context, String severity) => switch (severity) {
      'critical' => const Color(0xFFE53935),
      'high' => const Color(0xFFFB8C00),
      'medium' => const Color(0xFFFDD835),
      _ => Theme.of(context).colorScheme.outline,
    };

/// Small coloured state pill (e.g. requested ON / actual OFF).
class StatePill extends StatelessWidget {
  const StatePill({super.key, required this.label, required this.value, this.active = false, this.warning = false});
  final String label;
  final String value;
  final bool active;
  final bool warning;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = warning ? const Color(0xFFFB8C00) : (active ? const Color(0xFF43A047) : scheme.outline);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(12), color: color.withValues(alpha: 0.12)),
      child: Text('$label: ${value.toUpperCase()}', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

/// Requested vs. actual state + mode + maintenance flags for a pump or valve.
class EquipmentStateRow extends StatelessWidget {
  const EquipmentStateRow({super.key, required this.equipment});
  final Equipment equipment;
  @override
  Widget build(BuildContext context) {
    final e = equipment;
    return Wrap(spacing: 6, runSpacing: 6, children: [
      StatePill(label: 'Requested', value: e.requestedState, active: e.isRequestedActive),
      StatePill(label: 'Actual', value: e.actualState, active: e.isActive, warning: e.mismatch),
      StatePill(label: 'Mode', value: e.mode, active: e.isAuto),
      if (e.inMaintenance) const StatePill(label: 'Status', value: 'maintenance', warning: true),
    ]);
  }
}
