import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/prototype_ui.dart';

class LifePage extends StatelessWidget {
  const LifePage({super.key});

  @override
  Widget build(BuildContext context) {
    return PrototypePage(
      title: '小工具',
      subtitle: '把常用入口集中放在这里',
      leading: const PrototypeBackButton(),
      showActionButton: false,
      children: [
        const SizedBox(height: 22),
        const SectionTitle(title: '常用工具', trailing: Text('轻点进入')),
        _LifeFeatureGrid(
          onMusicTap: () => context.push(AppRoutes.music),
          onComicTap: () => context.push(AppRoutes.dailyComic),
          onMoneyTap: () => context.push(AppRoutes.money),
          onAnniversaryTap: () => context.push(AppRoutes.anniversary),
          onPlacesTap: () => context.push(AppRoutes.places),
          onCoupleTap: () => context.push(AppRoutes.coupleTasks),
          onWeeklyGoalsTap: () => context.push(AppRoutes.weeklyGoals),
        ),
      ],
    );
  }
}

class _LifeFeatureGrid extends StatelessWidget {
  const _LifeFeatureGrid({
    required this.onMusicTap,
    required this.onComicTap,
    required this.onMoneyTap,
    required this.onAnniversaryTap,
    required this.onPlacesTap,
    required this.onCoupleTap,
    required this.onWeeklyGoalsTap,
  });

  final VoidCallback onMusicTap;
  final VoidCallback onComicTap;
  final VoidCallback onMoneyTap;
  final VoidCallback onAnniversaryTap;
  final VoidCallback onPlacesTap;
  final VoidCallback onCoupleTap;
  final VoidCallback onWeeklyGoalsTap;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.library_music_rounded,
        '音乐播放器',
        '歌单与播放',
        AppColors.primary,
        onMusicTap,
      ),
      (
        Icons.auto_stories_rounded,
        '小笨漫画',
        '最新漫画',
        AppColors.accent,
        onComicTap,
      ),
      (
        Icons.account_balance_wallet_outlined,
        '记账本',
        '收支小记',
        const Color(0xFF8FD694),
        onMoneyTap,
      ),
      (
        Icons.event_available_outlined,
        '纪念日',
        '重要日子',
        const Color(0xFFFF9BAA),
        onAnniversaryTap,
      ),
      (
        Icons.place_outlined,
        '想去地点',
        '下一次出发',
        const Color(0xFFFFC65A),
        onPlacesTap,
      ),
      (
        Icons.favorite_border,
        '情侣清单',
        '一起完成',
        const Color(0xFFFF9BAA),
        onCoupleTap,
      ),
      (
        Icons.flag_outlined,
        '小目标',
        '轻轻推进',
        const Color(0xFF92C7FF),
        onWeeklyGoalsTap,
      ),
    ];
    return GridView.builder(
      itemCount: items.length,
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 78,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: item.$5,
          child: SoftCard(
            radius: 18,
            padding: const EdgeInsets.all(12),
            color: item.$4.withValues(alpha: .09),
            borderColor: item.$4.withValues(alpha: .2),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(item.$1, color: item.$4, size: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.$3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
