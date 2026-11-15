import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/permissions.dart';
import '../app/plant_providers.dart';
import '../app/providers.dart';
import '../components/control_action.dart';
import '../components/plant_scaffold.dart';
import '../components/state_views.dart';
import '../models/models.dart';

/// Setpoints and change proposals. Engineers propose a new value (within the engineering range,
/// with a reason); supervisors approve or reject (never their own proposal, recent login
/// required). The API enforces all of this; the UI only reflects it.
class SetpointsScreen extends ConsumerStatefulWidget {
  const SetpointsScreen({super.key, required this.plantId});
  final String plantId;
  @override
  ConsumerState<SetpointsScreen> createState() => _SetpointsScreenState();
}

class _SetpointsScreenState extends ConsumerState<SetpointsScreen> {
  String _filter = 'pending';

  @override
  Widget build(BuildContext context) {
    final setpoints = ref.watch(setpointsProvider(widget.plantId));
    final proposals = ref.watch(proposalsProvider(widget.plantId));
    final role = ref.watch(plantRoleProvider(widget.plantId)).valueOrNull;
    final wide = MediaQuery.sizeOf(context).width >= wideLayoutBreakpoint;

    final spList = setpoints.when(
      skipLoadingOnRefresh: true,
      loading: () => const LoadingView(label: 'Loading setpoints…'),
      error: (_, __) => ErrorView(message: 'Could not load setpoints.', onRetry: () => ref.invalidate(setpointsProvider(widget.plantId))),
      data: (list) => list.isEmpty
          ? const EmptyView(message: 'No setpoints configured for this plant.')
          : ListView(padding: const EdgeInsets.all(12), children: [
              for (final sp in list)
                Card(
                  child: ListTile(
                    minTileHeight: 72,
                    title: Text('${sp.tag} · ${sp.description}'),
                    subtitle: Text('Range ${_fmt(sp.minValue)}-${_fmt(sp.maxValue)} ${sp.unit}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('${_fmt(sp.value)} ${sp.unit}', style: Theme.of(context).textTheme.titleMedium),
                      if (uiAllows(role, UiAction.setpointPropose)) ...[
                        const SizedBox(width: 8),
                        IconButton.filledTonal(tooltip: 'Propose change', icon: const Icon(Icons.edit_note), onPressed: () => _propose(sp)),
                      ],
                    ]),
                  ),
                ),
              if (!uiAllows(role, UiAction.setpointPropose))
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Engineers propose setpoint changes; supervisors review them.', textAlign: TextAlign.center),
                ),
            ]),
    );

    final propList = proposals.when(
      skipLoadingOnRefresh: true,
      loading: () => const LoadingView(label: 'Loading proposals…'),
      error: (_, __) => ErrorView(message: 'Could not load proposals.', onRetry: () => ref.invalidate(proposalsProvider(widget.plantId))),
      data: (list) {
        final sps = {for (final s in setpoints.valueOrNull ?? const <Setpoint>[]) s.id: s};
        final filtered = list.where((p) => _filter == 'all' || p.status == _filter).toList();
        final idsKey = (list.expand((p) => [p.proposedBy, if (p.reviewedBy != null) p.reviewedBy!]).toSet().toList()..sort()).join(',');
        final names = ref.watch(displayNamesProvider(idsKey)).valueOrNull ?? const {};
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'pending', label: Text('Pending')),
                ButtonSegment(value: 'approved', label: Text('Approved')),
                ButtonSegment(value: 'rejected', label: Text('Rejected')),
                ButtonSegment(value: 'all', label: Text('All')),
              ],
              selected: {_filter},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyView(message: 'No proposals in this view.', icon: Icons.fact_check_outlined)
                : ListView(padding: const EdgeInsets.all(12), children: [
                    for (final p in filtered)
                      _ProposalCard(
                        plantId: widget.plantId,
                        proposal: p,
                        setpoint: sps[p.setpointId],
                        proposerName: names[p.proposedBy] ?? 'Unknown user',
                        reviewerName: p.reviewedBy == null ? null : (names[p.reviewedBy!] ?? 'Unknown user'),
                        canReview: uiAllows(role, UiAction.setpointReview) && p.pending && p.proposedBy != ref.read(repositoryProvider).userId,
                        ownProposal: p.proposedBy == ref.read(repositoryProvider).userId,
                      ),
                  ]),
          ),
        ]);
      },
    );

    return PlantScaffold(
      plantId: widget.plantId,
      section: PlantSection.setpoints,
      body: wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: spList), const VerticalDivider(width: 1), Expanded(child: propList)])
          : DefaultTabController(
              length: 2,
              child: Column(children: [
                const TabBar(tabs: [Tab(text: 'Setpoints'), Tab(text: 'Proposals')]),
                Expanded(child: TabBarView(children: [spList, propList])),
              ]),
            ),
    );
  }

  Future<void> _propose(Setpoint sp) async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ProposeSheet(plantId: widget.plantId, setpoint: sp),
    );
    if (submitted == true) ref.invalidate(proposalsProvider(widget.plantId));
  }
}

String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

class _ProposeSheet extends ConsumerStatefulWidget {
  const _ProposeSheet({required this.plantId, required this.setpoint});
  final String plantId;
  final Setpoint setpoint;
  @override
  ConsumerState<_ProposeSheet> createState() => _ProposeSheetState();
}

class _ProposeSheetState extends ConsumerState<_ProposeSheet> {
  final _form = GlobalKey<FormState>();
  late final _value = TextEditingController(text: _fmt(widget.setpoint.value));
  final _reason = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _value.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final ok = await runControlAction(
      context,
      ref,
      () => ref.read(commandServiceProvider).proposeSetpoint(widget.plantId, widget.setpoint.id, double.parse(_value.text.trim()), _reason.text.trim()),
      success: 'Proposal submitted for supervisor review.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final sp = widget.setpoint;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Propose change · ${sp.tag}', style: Theme.of(context).textTheme.titleLarge),
          Text('${sp.description} · current ${_fmt(sp.value)} ${sp.unit}'),
          const SizedBox(height: 16),
          TextFormField(
            controller: _value,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), LengthLimitingTextInputFormatter(10)],
            decoration: InputDecoration(labelText: 'New value (${sp.unit})', helperText: 'Allowed range ${_fmt(sp.minValue)}-${_fmt(sp.maxValue)} ${sp.unit}', border: const OutlineInputBorder()),
            validator: (v) {
              final n = double.tryParse(v?.trim() ?? '');
              if (n == null) return 'Enter a number.';
              if (n < sp.minValue || n > sp.maxValue) return 'Must be between ${_fmt(sp.minValue)} and ${_fmt(sp.maxValue)}.';
              if (n == sp.value) return 'The value is unchanged.';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _reason,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Reason for the change', border: OutlineInputBorder()),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Explain why the change is needed.' : null,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _busy ? null : _submit, icon: const Icon(Icons.send), label: const Text('Submit for review')),
        ]),
      ),
    );
  }
}

class _ProposalCard extends ConsumerStatefulWidget {
  const _ProposalCard({
    required this.plantId,
    required this.proposal,
    required this.setpoint,
    required this.proposerName,
    required this.reviewerName,
    required this.canReview,
    required this.ownProposal,
  });
  final String plantId;
  final SetpointProposal proposal;
  final Setpoint? setpoint;
  final String proposerName;
  final String? reviewerName;
  final bool canReview, ownProposal;
  @override
  ConsumerState<_ProposalCard> createState() => _ProposalCardState();
}

class _ProposalCardState extends ConsumerState<_ProposalCard> {
  final _comment = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _review(bool approve) async {
    final ok = await confirmAction(
      context,
      title: approve ? 'Approve proposal?' : 'Reject proposal?',
      message: approve ? 'The setpoint will change immediately to the proposed value.' : 'The setpoint will stay unchanged.',
      confirm: approve ? 'Approve' : 'Reject',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final comment = _comment.text.trim();
    final done = await runControlAction(
      context,
      ref,
      () => ref.read(commandServiceProvider).reviewSetpoint(widget.plantId, widget.proposal.id, approve, comment: comment.isEmpty ? null : comment),
      success: approve ? 'Proposal approved and setpoint updated.' : 'Proposal rejected.',
    );
    if (done) {
      ref.invalidate(proposalsProvider(widget.plantId));
      ref.invalidate(setpointsProvider(widget.plantId));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.proposal;
    final sp = widget.setpoint;
    final online = isOnline(ref);
    final color = switch (p.status) { 'approved' => const Color(0xFF43A047), 'rejected' => const Color(0xFFE53935), _ => const Color(0xFFFFB300) };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${sp?.tag ?? 'Setpoint'}: ${sp == null ? '' : '${_fmt(sp.value)} → '}${_fmt(p.proposedValue)} ${sp?.unit ?? ''}', style: Theme.of(context).textTheme.titleSmall)),
            Chip(label: Text(statusLabel(p.status)), side: BorderSide(color: color), visualDensity: VisualDensity.compact),
          ]),
          const SizedBox(height: 4),
          Text(p.reason),
          const SizedBox(height: 4),
          Text('Proposed by ${widget.proposerName}${widget.ownProposal ? ' (you)' : ''} · ${formatTime(p.createdAt)}', style: Theme.of(context).textTheme.bodySmall),
          if (p.reviewedAt != null)
            Text('Reviewed by ${widget.reviewerName} · ${formatTime(p.reviewedAt!)}${p.reviewComment == null ? '' : ' · "${p.reviewComment}"'}', style: Theme.of(context).textTheme.bodySmall),
          if (widget.canReview) ...[
            const SizedBox(height: 12),
            TextField(controller: _comment, maxLength: 500, decoration: const InputDecoration(labelText: 'Review comment (optional)', isDense: true, border: OutlineInputBorder())),
            Wrap(spacing: 8, children: [
              FilledButton.icon(onPressed: _busy || !online ? null : () => _review(true), icon: const Icon(Icons.check), label: const Text('Approve')),
              OutlinedButton.icon(onPressed: _busy || !online ? null : () => _review(false), icon: const Icon(Icons.close), label: const Text('Reject')),
            ]),
          ] else if (p.pending && widget.ownProposal)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text('Waiting for a supervisor to review.', style: Theme.of(context).textTheme.bodySmall)),
        ]),
      ),
    );
  }
}
