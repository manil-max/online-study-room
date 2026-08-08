import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../core/l10n/group_error_text.dart';
import '../../../core/time_engine/group_time_zone_label.dart';
import '../../../core/time_engine/device_timezone.dart';
import '../../../core/time_engine/world_clock_math.dart';
import '../../../data/models/study_group.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/group_providers.dart';
import 'group_avatar.dart';

/// WP-555: arama kutusunda her tusa bir RPC gidiyordu ("matematik" = 9 istek).
/// Kullanici yazmayi birakinca **tek** istek gitsin diye bekleme suresi.
const kGroupDiscoverySearchDebounce = Duration(milliseconds: 300);

/// Yalnızca RPC'nin döndürdüğü güvenli açık-grup özetlerini gösterir. Davet
/// kodu, yönetici/üye profili veya grup çalışma verisi bu ekrana taşınmaz.
class GroupDiscoveryScreen extends ConsumerStatefulWidget {
  const GroupDiscoveryScreen({super.key});

  @override
  ConsumerState<GroupDiscoveryScreen> createState() =>
      _GroupDiscoveryScreenState();
}

class _GroupDiscoveryScreenState extends ConsumerState<GroupDiscoveryScreen> {
  static const _pageSize = 20;

  final _searchController = TextEditingController();
  final _groups = <PublicGroupSummary>[];
  final _joinedIds = <String>{};
  final _joiningIds = <String>{};
  var _loading = true;
  var _loadingMore = false;
  var _hasMore = false;
  String? _timeZoneFilter;
  var _onlyWithCapacity = false;
  Object? _error;
  int _requestVersion = 0;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    // Ekran kapandiktan sonra tetiklenen zamanlayici `_load()` -> `setState`
    // demektir; iptal edilmezse "setState after dispose" hatasi duser.
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Her tusa degil, yazma durunca yukler.
  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(kGroupDiscoverySearchDebounce, () {
      if (!mounted) return;
      _load();
    });
  }

  /// Acik kullanici eylemi (gonder / yenile / filtre): beklemeden yukle, ama
  /// bekleyen debounce'i dusur ki ardindan ikinci bir istek gitmesin.
  void _loadNow() {
    _searchDebounce?.cancel();
    _load();
  }

  Future<void> _load({bool reset = true}) async {
    final requestVersion = ++_requestVersion;
    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
      } else {
        _loadingMore = true;
      }
    });
    try {
      await DeviceTimezone.ensureInitialized();
      final page = await ref
          .read(groupRepositoryProvider)
          .discoverPublicGroups(
            query: _searchController.text.trim(),
            timeZone: _timeZoneFilter,
            userTimeZone: DeviceTimezone.lastId ?? kDefaultGroupTimeZone,
            onlyWithCapacity: _onlyWithCapacity,
            offset: reset ? 0 : _groups.length,
            limit: _pageSize,
          );
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        if (reset) _groups.clear();
        _groups.addAll(page);
        _hasMore = page.length == _pageSize;
        _error = null;
      });
      // 🔴 WP-551: burada `on GroupException` yaziyordu. Ag kopunca Supabase
      // repository'den `SocketException` / `ClientException` sarilmadan cikar
      // ve bu blok onu yakalamazdi: `_error` null kalir, `finally` yalnizca
      // `_loading = false` yapardi ve kullanici hata yerine bos "grup
      // bulunamadi" listesini gorurdu (yakalanmamis async hata bonus).
    } catch (failure) {
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() => _error = failure);
    } finally {
      if (mounted && requestVersion == _requestVersion) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _join(PublicGroupSummary group) async {
    final user = ref.read(authStateProvider).value;
    if (user == null || _joiningIds.contains(group.id)) return;
    setState(() => _joiningIds.add(group.id));
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(groupRepositoryProvider)
          .joinPublicGroup(groupId: group.id, member: user);
      ref.read(activeGroupIdProvider.notifier).select(group.id);
      ref.invalidate(userGroupsProvider);
      if (!mounted) return;
      setState(() => _joinedIds.add(group.id));
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.groupDiscoveryJoined)),
      );
      // 🔴 WP-551: her sebep tek bir genel cumleye iniyordu (yasakli / grup
      // dolu / oturum yok / ad reddedildi / ag). `groupActionErrorText` ayni
      // ceviriciyi davet kodu akisiyla paylasir.
    } catch (failure) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(groupActionErrorText(failure, l10n))),
        );
      }
    } finally {
      if (mounted) setState(() => _joiningIds.remove(group.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final memberIds =
        ref.watch(userGroupsProvider).value?.map((group) => group.id).toSet() ??
        const <String>{};

    return Scaffold(
      appBar: AppBar(title: Text(l10n.groupDiscoveryTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _loadNow(),
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: l10n.groupDiscoverySearchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: l10n.classroomYenile,
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadNow,
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _timeZoneFilter ?? '',
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.groupDiscoveryRegionFilter,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Text(l10n.groupDiscoveryAllRegions),
                        ),
                        for (final timeZone in kGroupTimeZoneChoices)
                          DropdownMenuItem(
                            value: timeZone,
                            child: Text(
                              localizedWorldCityLabel(
                                timeZone,
                                l10n,
                                fallback: timeZone,
                              ),
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _timeZoneFilter = value == null || value.isEmpty
                              ? null
                              : value;
                        });
                        _loadNow();
                      },
                    ),
                  ),
                  FilterChip(
                    label: Text(l10n.groupDiscoveryOpenSeatsOnly),
                    selected: _onlyWithCapacity,
                    onSelected: (selected) {
                      setState(() => _onlyWithCapacity = selected);
                      _loadNow();
                    },
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(l10n, memberIds)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, Set<String> memberIds) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(groupActionErrorText(_error!, l10n)),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loadNow,
                child: Text(l10n.groupDiscoveryRetry),
              ),
            ],
          ),
        ),
      );
    }
    if (_groups.isEmpty) return Center(child: Text(l10n.groupDiscoveryEmpty));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _groups.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == _groups.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: OutlinedButton(
                  onPressed: _loadingMore ? null : () => _load(reset: false),
                  child: _loadingMore
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.groupDiscoveryLoadMore),
                ),
              ),
            );
          }
          final group = _groups[index];
          return _PublicGroupCard(
            group: group,
            isJoined:
                memberIds.contains(group.id) || _joinedIds.contains(group.id),
            isJoining: _joiningIds.contains(group.id),
            onJoin: () => _join(group),
          );
        },
      ),
    );
  }
}

class _PublicGroupCard extends StatelessWidget {
  const _PublicGroupCard({
    required this.group,
    required this.isJoined,
    required this.isJoining,
    required this.onJoin,
  });

  final PublicGroupSummary group;
  final bool isJoined;
  final bool isJoining;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isFull = group.memberCount >= group.memberLimit;
    final theme = Theme.of(context);
    final relative = groupTimeZoneRelativeLabel(
      groupTimeZone: group.timeZone,
      l10n: l10n,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GroupAvatar(
                  name: group.name,
                  avatarPath: group.avatarPath,
                  avatarUpdatedAt: group.avatarUpdatedAt,
                  radius: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    group.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  avatar: const Icon(Icons.public, size: 16),
                  label: Text(l10n.groupDiscoveryPublic),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.groupDiscoveryMemberCount(
                group.memberCount,
                group.memberLimit,
              ),
            ),
            Text(l10n.groupDiscoveryDailyGoal(group.dailyGoalMinutes)),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => showGroupTimeZoneInfoDialog(
                context,
                groupTimeZone: group.timeZone,
              ),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.public_outlined, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizedWorldCityLabel(
                              group.timeZone,
                              l10n,
                              fallback: group.timeZone,
                            ),
                          ),
                          if (relative != null)
                            Text(relative, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: isJoined || isFull || isJoining ? null : onJoin,
                child: isJoining
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        isJoined
                            ? l10n.groupDiscoveryJoined
                            : isFull
                            ? l10n.groupDiscoveryFull
                            : l10n.classroomKatil,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
