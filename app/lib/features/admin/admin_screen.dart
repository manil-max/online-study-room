import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/feedback_ticket.dart';
import '../../data/providers/admin_providers.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/repositories/admin_repository.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(adminIsSuperAdminProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Yönetim')),
      body: isAdmin.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _AdminError(message: error.toString()),
        data: (allowed) {
          if (!allowed) {
            return const _AdminError(
              icon: Icons.lock_outline,
              message: 'Bu alan yalnızca süper-admin içindir.',
            );
          }
          return const _AdminDashboard();
        },
      ),
    );
  }
}

class _AdminDashboard extends ConsumerWidget {
  const _AdminDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(adminDashboardSummaryProvider);
    final tickets = ref.watch(adminFeedbackTicketsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminDashboardSummaryProvider);
        ref.invalidate(adminFeedbackTicketsProvider);
        await Future.wait([
          ref.read(adminDashboardSummaryProvider.future),
          ref.read(adminFeedbackTicketsProvider.future),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          summary.when(
            loading: () => const _SummarySkeleton(),
            error: (error, _) => _AdminError(message: error.toString()),
            data: (value) => _SummaryGrid(summary: value),
          ),
          const SizedBox(height: 18),
          Text('Raporlar', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          tickets.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, _) => _AdminError(message: error.toString()),
            data: (items) {
              if (items.isEmpty) {
                return const _EmptyReports();
              }
              return Column(
                children: [
                  for (final ticket in items) _TicketCard(ticket: ticket),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final AdminDashboardSummary? summary;

  @override
  Widget build(BuildContext context) {
    final value =
        summary ??
        const AdminDashboardSummary(
          userCount: 0,
          groupCount: 0,
          sessionCount: 0,
          openTicketCount: 0,
        );

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.75,
      children: [
        _SummaryTile(
          label: 'Kullanıcılar',
          value: value.userCount.toString(),
          icon: Icons.people_outline,
        ),
        _SummaryTile(
          label: 'Gruplar',
          value: value.groupCount.toString(),
          icon: Icons.groups_outlined,
        ),
        _SummaryTile(
          label: 'Oturumlar',
          value: value.sessionCount.toString(),
          icon: Icons.timer_outlined,
        ),
        _SummaryTile(
          label: 'Açık raporlar',
          value: value.openTicketCount.toString(),
          icon: Icons.report_problem_outlined,
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(label, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketCard extends ConsumerWidget {
  const _TicketCard({required this.ticket});

  final FeedbackTicket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ticket.kind == FeedbackTicketKind.bug
                      ? Icons.bug_report_outlined
                      : Icons.lightbulb_outline,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ticket.subject,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusMenu(ticket: ticket),
              ],
            ),
            const SizedBox(height: 6),
            Text(ticket.message, maxLines: 4, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(_statusLabel(ticket.status)),
                ),
                if (ticket.reporterDisplayName?.isNotEmpty == true)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.person_outline, size: 18),
                    label: Text(ticket.reporterDisplayName!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusMenu extends ConsumerWidget {
  const _StatusMenu({required this.ticket});

  final FeedbackTicket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<FeedbackTicketStatus>(
      tooltip: 'Durumu değiştir',
      initialValue: ticket.status,
      onSelected: (status) async {
        final profile = ref.read(authStateProvider).value;
        if (profile == null) return;
        try {
          await ref
              .read(adminRepositoryProvider)
              .updateFeedbackStatus(
                userId: profile.id,
                ticketId: ticket.id,
                status: status,
              );
          ref.invalidate(adminDashboardSummaryProvider);
          ref.invalidate(adminFeedbackTicketsProvider);
        } on AdminException catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
      },
      itemBuilder: (context) => [
        for (final status in FeedbackTicketStatus.values)
          PopupMenuItem(value: status, child: Text(_statusLabel(status))),
      ],
    );
  }
}

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 156,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyReports extends StatelessWidget {
  const _EmptyReports();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Text('Henüz rapor yok.'),
      ),
    );
  }
}

class _AdminError extends StatelessWidget {
  const _AdminError({required this.message, this.icon = Icons.error_outline});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(FeedbackTicketStatus status) {
  return switch (status) {
    FeedbackTicketStatus.open => 'Açık',
    FeedbackTicketStatus.inProgress => 'İnceleniyor',
    FeedbackTicketStatus.closed => 'Kapalı',
  };
}
