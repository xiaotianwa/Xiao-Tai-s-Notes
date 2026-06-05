import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/data/app_data_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/prototype_ui.dart';

class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  late Future<AppLocalStore> _storeFuture;
  final _controller = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _storeFuture = AppLocalStore.create();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppLocalStore>(
      future: _storeFuture,
      builder: (context, snapshot) {
        final store = snapshot.data;
        final results = store == null
            ? const <_SearchResult>[]
            : _search(store);
        return PrototypePage(
          title: '\u5168\u5c40\u641c\u7d22',
          subtitle:
              '\u627e\u56de\u65e5\u8bb0\u3001\u5907\u5fd8\u3001\u5730\u70b9\u548c\u90a3\u4e9b\u5c0f\u7ea6\u5b9a',
          leading: PrototypeIconButton(
            icon: Icons.chevron_left,
            color: AppColors.textPrimary,
            onTap: context.pop,
          ),
          showActionButton: false,
          separateHeaderControls: true,
          children: [
            const SizedBox(height: 18),
            _SearchInput(
              controller: _controller,
              onChanged: (value) => setState(() => _query = value.trim()),
              onClear: _query.isEmpty
                  ? null
                  : () {
                      _controller.clear();
                      setState(() => _query = '');
                    },
            ),
            const SizedBox(height: 18),
            if (store == null)
              const _SearchLoadingCard()
            else if (_query.isEmpty)
              AppEmptyState(
                icon: Icons.search_outlined,
                title: '\u8f93\u5165\u5173\u952e\u8bcd\u5f00\u59cb\u627e',
                message:
                    '\u53ef\u4ee5\u641c\u8bb0\u5f55\u3001\u5907\u5fd8\u3001\u7eaa\u5ff5\u65e5\u3001\u60f3\u53bb\u5730\u70b9\u3001\u63d0\u9192\u548c\u60c5\u4fa3\u6e05\u5355\u3002',
                actionLabel: '\u5199\u4e00\u6761\u65b0\u8bb0\u5f55',
                onAction: () => context.push(AppRoutes.entryEditor),
              )
            else if (results.isEmpty)
              AppEmptyState(
                icon: Icons.manage_search_outlined,
                title: '\u6ca1\u6709\u627e\u5230\u5339\u914d\u5185\u5bb9',
                message:
                    '\u6362\u4e00\u4e2a\u66f4\u77ed\u7684\u5173\u952e\u8bcd\u8bd5\u8bd5\uff0c\u6216\u8005\u73b0\u5728\u8865\u4e0a\u4e00\u6761\u65b0\u8bb0\u5f55\u3002',
                actionLabel: '\u65b0\u589e\u8bb0\u5f55',
                onAction: () => context.push(AppRoutes.entryEditor),
              )
            else ...[
              _SearchSummary(query: _query, count: results.length),
              const SizedBox(height: 12),
              for (final result in results)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SearchResultCard(
                    result: result,
                    onTap: () => _openResult(result),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  List<_SearchResult> _search(AppLocalStore store) {
    final keyword = _query.toLowerCase();
    if (keyword.isEmpty) {
      return const [];
    }
    final results = <_SearchResult>[];

    bool contains(String? value) {
      return value != null && value.toLowerCase().contains(keyword);
    }

    for (final entry in store.getEntries()) {
      if (contains(entry.title) ||
          contains(entry.content) ||
          contains(entry.mood) ||
          contains(entry.kindLabel) ||
          contains(entry.location ?? '') ||
          entry.tags.any(contains) ||
          (entry.draft && contains('\u8349\u7a3f'))) {
        results.add(
          _SearchResult(
            type: '\u8bb0\u5f55',
            icon: Icons.edit_note_outlined,
            color: AppColors.primary,
            title: entry.title,
            subtitle:
                '${_formatDate(entry.createdAt)} \u00b7 ${_entrySearchMeta(entry)}',
            route: AppRoutes.entryDetail,
            extra: entry,
          ),
        );
      }
    }

    for (final memo in store.getMemos()) {
      if (contains(memo.title) ||
          contains(memo.content) ||
          memo.tags.any(contains)) {
        results.add(
          _SearchResult(
            type: '\u5907\u5fd8',
            icon: Icons.sticky_note_2_outlined,
            color: AppColors.warning,
            title: memo.title,
            subtitle:
                '${_formatDate(memo.updatedAt)} \u00b7 ${_memoSearchMeta(memo)}',
            route: AppRoutes.memos,
          ),
        );
      }
    }

    for (final reminder in store.getReminders()) {
      if (contains(reminder.title) || contains(reminder.priority)) {
        results.add(
          _SearchResult(
            type: '\u63d0\u9192',
            icon: Icons.notifications_none_outlined,
            color: AppColors.warning,
            title: reminder.title,
            subtitle: _formatDate(reminder.scheduledAt),
            route: AppRoutes.reminder,
          ),
        );
      }
    }

    for (final anniversary in store.getAnniversaries()) {
      if (contains(anniversary.title) || contains(anniversary.category)) {
        final now = DateTime.now();
        final countUp = anniversary.showCountUp;
        final days = countUp
            ? anniversary.daysPassed(now)
            : anniversary.daysLeft(now);
        results.add(
          _SearchResult(
            type: '\u7eaa\u5ff5\u65e5',
            icon: Icons.event_available_outlined,
            color: AppColors.accent,
            title: anniversary.title,
            subtitle:
                '${_formatDate(anniversary.date)} · ${countUp ? '已记录' : '还有'} $days 天',
            route: AppRoutes.anniversary,
          ),
        );
      }
    }

    for (final place in store.getPlaces()) {
      if (contains(place.title) ||
          contains(place.description) ||
          contains(place.category)) {
        results.add(
          _SearchResult(
            type: '\u5730\u70b9',
            icon: Icons.place_outlined,
            color: AppColors.success,
            title: place.title,
            subtitle: place.description,
            route: AppRoutes.places,
          ),
        );
      }
    }

    for (final task in store.getCoupleTasks()) {
      if (contains(task.title) || contains(task.index.toString())) {
        results.add(
          _SearchResult(
            type: '\u60c5\u4fa3\u6e05\u5355',
            icon: Icons.favorite_border,
            color: AppColors.accent,
            title: '${task.index}. ${task.title}',
            subtitle: task.completed
                ? '\u5df2\u5b8c\u6210'
                : '\u8fd8\u6ca1\u6709\u5b8c\u6210',
            route: AppRoutes.coupleTasks,
          ),
        );
      }
    }

    for (final goal in store.getWeeklyGoals()) {
      if (contains(goal.title) || contains(goal.unit)) {
        results.add(
          _SearchResult(
            type: '\u672c\u5468\u76ee\u6807',
            icon: Icons.flag_outlined,
            color: AppColors.success,
            title: goal.title,
            subtitle:
                '${_formatNumber(goal.currentValue)} / ${_formatNumber(goal.targetValue)} ${goal.unit}',
            route: AppRoutes.weeklyGoals,
          ),
        );
      }
    }

    for (final record in store.getMoneyRecords()) {
      if (contains(record.title) ||
          contains(record.note) ||
          contains(record.category) ||
          contains(_moneyOwnerLabel(record.owner))) {
        final amount = record.isIncome
            ? _formatMoney(record.amountCents)
            : '-${_formatMoney(record.amountCents)}';
        results.add(
          _SearchResult(
            type: '\u8bb0\u8d26',
            icon: Icons.account_balance_wallet_outlined,
            color: record.isIncome ? AppColors.success : AppColors.danger,
            title: record.title,
            subtitle:
                '${_formatDate(record.happenedAt)} \u00b7 ${record.category} \u00b7 $amount',
            route: AppRoutes.money,
          ),
        );
      }
    }

    return results.take(80).toList();
  }

  Future<void> _openResult(_SearchResult result) async {
    if (result.extra != null) {
      await context.push(result.route, extra: result.extra);
      return;
    }
    await context.push(result.route);
  }
}

String _memoSearchMeta(AppMemo memo) {
  final parts = <String>[
    if (memo.tags.isNotEmpty) memo.tags.take(2).join('\u3001'),
    if (memo.remindAt != null) '\u6709\u63d0\u9192',
  ];
  return parts.isEmpty
      ? '\u70b9\u5f00\u5907\u5fd8\u9875\u7ee7\u7eed\u7f16\u8f91'
      : parts.join(' 璺?');
}

String _entrySearchMeta(AppEntry entry) {
  final parts = <String>[
    if (entry.draft) '\u8349\u7a3f',
    if (entry.mood.trim().isNotEmpty) entry.mood.trim(),
    if ((entry.location ?? '').trim().isNotEmpty) entry.location!.trim(),
    if (entry.tags.isNotEmpty) entry.tags.take(2).join('\u3001'),
  ];
  return parts.isEmpty
      ? '\u70b9\u5f00\u65e5\u8bb0\u7ee7\u7eed\u7f16\u8f91'
      : parts.join(' 璺?');
}

class _SearchResult {
  const _SearchResult({
    required this.type,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.route,
    this.extra,
  });

  final String type;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String route;
  final Object? extra;
}

class _SearchInput extends StatelessWidget {
  const _SearchInput({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      radius: 22,
      child: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: '\u8f93\u5165\u5173\u952e\u8bcd\u6216\u5730\u70b9',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: onClear == null
              ? null
              : IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
        ),
      ),
    );
  }
}

class _SearchSummary extends StatelessWidget {
  const _SearchSummary({required this.query, required this.count});

  final String query;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '\u5173\u4e8e\u300c$query\u300d\u7684\u641c\u7d22\u7ed3\u679c',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        TinyPill(
          label: '$count \u6761',
          color: AppColors.primary,
          selected: true,
        ),
      ],
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.result, required this.onTap});

  final _SearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: SoftCard(
        padding: const EdgeInsets.all(14),
        radius: 20,
        borderColor: result.color.withValues(alpha: .2),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: result.color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(result.icon, color: result.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TinyPill(label: result.type, color: result.color),
                  const SizedBox(height: 8),
                  Text(
                    result.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    result.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _SearchLoadingCard extends StatelessWidget {
  const _SearchLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const SoftCard(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

String _formatDate(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '${time.month}\u6708${time.day}\u65e5 $hour:$minute';
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}

String _formatMoney(int cents) {
  final yuan = cents ~/ 100;
  final cent = cents % 100;
  return "\u00a5$yuan.${cent.toString().padLeft(2, '0')}";
}

String _moneyOwnerLabel(String value) {
  return switch (value) {
    'me' => '\u6211',
    'partner' => '\u5a77\u5a77',
    _ => '\u5171\u540c',
  };
}
