import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';

class AdminDashboardTab extends ConsumerWidget {
  const AdminDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(adminDashboardSummaryProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminDashboardSummaryProvider);
        await ref.read(adminDashboardSummaryProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          summary.when(
            loading: () => const _SummarySkeleton(),
            error: (error, _) => Center(child: Text(error.toString())),
            data: (value) => _SummaryGrid(summary: value),
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
