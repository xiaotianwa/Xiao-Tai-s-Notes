import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/daily_comics/daily_comic_service.dart';
import '../../../core/theme/app_colors.dart';

const _comicPurple = Color(0xFF9B70F1);
const _comicDeep = Color(0xFF25203F);
const _comicMuted = Color(0xFF8C86A2);
const _comicLine = Color(0xFFF0EAF8);
const _comicShadow = Color(0x188B6CF6);
const _comicWarm = Colors.transparent;

enum _ComicPanel { list, reader }

class DailyComicPage extends StatefulWidget {
  const DailyComicPage({super.key});

  @override
  State<DailyComicPage> createState() => _DailyComicPageState();
}

class _DailyComicPageState extends State<DailyComicPage> {
  late Future<AppDailyComicPage> _comicsFuture;
  _ComicPanel _panel = _ComicPanel.list;
  bool _showArchive = false;
  String? _selectedComicId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _comicsFuture = DailyComicService.instance.fetchPublished(pageSize: 30);
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: FutureBuilder<AppDailyComicPage>(
        future: _comicsFuture,
        builder: (context, snapshot) {
          final comics = snapshot.data?.items ?? const <AppDailyComic>[];
          final selected = _selectedComic(comics);
          if (_panel == _ComicPanel.reader && selected != null) {
            return _ComicReaderScreen(
              comic: selected,
              onBack: () => setState(() => _panel = _ComicPanel.list),
              onGoArchive: () {
                setState(() {
                  _panel = _ComicPanel.list;
                  _showArchive = true;
                  _selectedComicId = null;
                });
              },
            );
          }

          return _ComicListScreen(
            loading: snapshot.connectionState == ConnectionState.waiting,
            errorMessage: snapshot.hasError
                ? _friendlyComicError(snapshot.error)
                : null,
            comics: comics,
            showArchive: _showArchive,
            searchQuery: _searchQuery,
            onBack: _goBack,
            onSearch: _openSearchDialog,
            onTabChanged: (archive) => setState(() => _showArchive = archive),
            onRetry: _reload,
            onRefresh: _refresh,
            onOpenComic: (comic) {
              setState(() {
                _selectedComicId = comic.id;
                _panel = _ComicPanel.reader;
              });
            },
          );
        },
      ),
    );
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.treasureBox);
  }

  AppDailyComic? _selectedComic(List<AppDailyComic> comics) {
    if (comics.isEmpty) {
      return null;
    }
    final selectedId = _selectedComicId;
    if (selectedId != null) {
      for (final comic in comics) {
        if (comic.id == selectedId) {
          return comic;
        }
      }
    }
    return comics.first;
  }

  Future<void> _openSearchDialog() async {
    final query = await showDialog<String>(
      context: context,
      builder: (context) => _ComicSearchDialog(initialQuery: _searchQuery),
    );
    if (query == null || !mounted) {
      return;
    }
    setState(() => _searchQuery = query);
  }

  Future<void> _refresh() async {
    final next = DailyComicService.instance.fetchPublished(pageSize: 30);
    setState(() {
      _selectedComicId = null;
      _comicsFuture = next;
    });
    await next;
  }

  void _reload() {
    setState(() {
      _selectedComicId = null;
      _comicsFuture = DailyComicService.instance.fetchPublished(pageSize: 30);
    });
  }
}

class _ComicSearchDialog extends StatefulWidget {
  const _ComicSearchDialog({required this.initialQuery});

  final String initialQuery;

  @override
  State<_ComicSearchDialog> createState() => _ComicSearchDialogState();
}

class _ComicSearchDialogState extends State<_ComicSearchDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('搜索漫画'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: '输入标题或发布日期',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(''),
          child: const Text('清除'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

class _ComicListScreen extends StatelessWidget {
  const _ComicListScreen({
    required this.loading,
    required this.errorMessage,
    required this.comics,
    required this.showArchive,
    required this.searchQuery,
    required this.onBack,
    required this.onSearch,
    required this.onTabChanged,
    required this.onRetry,
    required this.onRefresh,
    required this.onOpenComic,
  });

  final bool loading;
  final String? errorMessage;
  final List<AppDailyComic> comics;
  final bool showArchive;
  final String searchQuery;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final ValueChanged<bool> onTabChanged;
  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;
  final ValueChanged<AppDailyComic> onOpenComic;

  @override
  Widget build(BuildContext context) {
    final baseComics = showArchive
        ? comics.skip(1).toList(growable: false)
        : comics;
    final query = searchQuery.trim();
    final visibleComics = query.isEmpty
        ? baseComics
        : baseComics
              .where(
                (comic) =>
                    comic.title.contains(query) ||
                    _formatDateYmd(comic.publishDate).contains(query),
              )
              .toList(growable: false);

    return Scaffold(
      backgroundColor: _comicWarm,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0x20FFFFFF), Color(0x12FFF7FC), Color(0x18FFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, .48, 1],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            color: _comicPurple,
            onRefresh: onRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
                        child: Column(
                          children: [
                            _ComicListTopBar(
                              onBack: onBack,
                              onSearch: onSearch,
                            ),
                            const SizedBox(height: 16),
                            _ComicHeroTabs(
                              showArchive: showArchive,
                              onChanged: onTabChanged,
                            ),
                            const SizedBox(height: 18),
                            if (query.isNotEmpty) ...[
                              _ComicSearchNotice(query: query),
                              const SizedBox(height: 12),
                            ],
                            if (loading)
                              const _ComicLoadingList()
                            else if (errorMessage != null)
                              _ComicErrorCard(
                                message: errorMessage!,
                                onRetry: onRetry,
                              )
                            else if (visibleComics.isEmpty)
                              _ComicEmptyCard(
                                title: showArchive ? '还没有往期漫画' : '还没有漫画',
                                message: showArchive
                                    ? '服务端发布更多漫画后，往期内容会自动出现在这里。'
                                    : '管理端发布漫画后，APP 会拉取最新和往期内容。',
                                onRetry: onRetry,
                              )
                            else
                              _ComicEpisodeList(
                                comics: visibleComics,
                                archiveMode: showArchive,
                                onOpenComic: onOpenComic,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComicListTopBar extends StatelessWidget {
  const _ComicListTopBar({required this.onBack, required this.onSearch});

  final VoidCallback onBack;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child: _CircleButton(
              icon: Icons.chevron_left_rounded,
              onTap: onBack,
              iconColor: const Color(0xFF9A93AE),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 58),
            child: Text(
              '小笨漫画',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _comicDeep,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Positioned(
            right: 0,
            child: _CircleButton(
              icon: Icons.search_rounded,
              onTap: onSearch,
              iconColor: const Color(0xFFD6C8EF),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComicHeroTabs extends StatelessWidget {
  const _ComicHeroTabs({required this.showArchive, required this.onChanged});

  final bool showArchive;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 126,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFECF7), Color(0xFFFFFAFD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(color: _comicShadow, blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: 16,
            top: 0,
            child: Icon(
              Icons.cloud_outlined,
              color: Color(0xFFF6DDEB),
              size: 62,
            ),
          ),
          const Positioned(
            right: 3,
            bottom: 14,
            child: Icon(Icons.star_rounded, color: Color(0xFFFFC48B), size: 24),
          ),
          const Positioned(
            left: 116,
            top: 7,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFFFFD5EA),
              size: 21,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _SegmentPill(
                label: '最新',
                selected: !showArchive,
                onTap: () => onChanged(false),
              ),
              const SizedBox(width: 12),
              _SegmentPill(
                label: '往期',
                selected: showArchive,
                onTap: () => onChanged(true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComicSearchNotice extends StatelessWidget {
  const _ComicSearchNotice({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _comicLine),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: _comicPurple, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '搜索：$query',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _comicDeep,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Text(
            '再次搜索可清除',
            style: TextStyle(
              color: _comicMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentPill extends StatelessWidget {
  const _SegmentPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 54,
        width: 82,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _comicPurple : Colors.white.withValues(alpha: .82),
          borderRadius: BorderRadius.circular(22),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _comicPurple.withValues(alpha: .24),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _comicMuted,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ComicEpisodeList extends StatelessWidget {
  const _ComicEpisodeList({
    required this.comics,
    required this.archiveMode,
    required this.onOpenComic,
  });

  final List<AppDailyComic> comics;
  final bool archiveMode;
  final ValueChanged<AppDailyComic> onOpenComic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _comicLine),
        boxShadow: const [
          BoxShadow(color: _comicShadow, blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          for (var index = 0; index < comics.length; index++) ...[
            _ComicEpisodeTile(
              comic: comics[index],
              index: index,
              archiveMode: archiveMode,
              onTap: () => onOpenComic(comics[index]),
            ),
            if (index != comics.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _ComicEpisodeTile extends StatelessWidget {
  const _ComicEpisodeTile({
    required this.comic,
    required this.index,
    required this.archiveMode,
    required this.onTap,
  });

  final AppDailyComic comic;
  final int index;
  final bool archiveMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final thumbnail = comic.images.isEmpty ? null : comic.images.first;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        constraints: const BoxConstraints(minHeight: 116),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 104,
                height: 104,
                child: thumbnail == null
                    ? const _ComicCoverPlaceholder()
                    : _NetworkComicImage(
                        imageUrl: thumbnail.imageUrl,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _episodeListTitle(comic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _comicDeep,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _formatDateYmd(comic.publishDate),
                    style: const TextStyle(
                      color: _comicMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (!archiveMode && index == 2)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFFFF9A73),
                  size: 26,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ComicReaderScreen extends StatelessWidget {
  const _ComicReaderScreen({
    required this.comic,
    required this.onBack,
    required this.onGoArchive,
  });

  final AppDailyComic comic;
  final VoidCallback onBack;
  final VoidCallback onGoArchive;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _comicWarm,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0x20FFFFFF), Color(0x12FFF3FA), Color(0x18FFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, .48, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _ComicReaderTopBar(title: _episodeTitle(comic), onBack: onBack),
              Expanded(
                child: _ComicReaderPager(
                  comic: comic,
                  onGoArchive: onGoArchive,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComicReaderTopBar extends StatelessWidget {
  const _ComicReaderTopBar({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            _CircleButton(
              icon: Icons.chevron_left_rounded,
              onTap: onBack,
              iconColor: const Color(0xFF9A93AE),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  color: _comicMuted,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComicReaderPager extends StatefulWidget {
  const _ComicReaderPager({required this.comic, required this.onGoArchive});

  final AppDailyComic comic;
  final VoidCallback onGoArchive;

  @override
  State<_ComicReaderPager> createState() => _ComicReaderPagerState();
}

class _ComicReaderPagerState extends State<_ComicReaderPager> {
  late final PageController _pageController;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.comic.images;
    final totalPages = images.length + 1;
    final endPage = _page >= images.length;

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: totalPages,
            onPageChanged: (value) => setState(() => _page = value),
            itemBuilder: (context, index) {
              if (index >= images.length) {
                return _ComicEndPanel(onGoArchive: widget.onGoArchive);
              }
              return _ReaderImagePage(image: images[index]);
            },
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: endPage
              ? const SizedBox(key: ValueKey('end'), height: 68)
              : _ReaderBottomPager(
                  key: const ValueKey('pager'),
                  index: _page,
                  total: images.length,
                  onPrevious: _page == 0 ? null : () => _jumpTo(_page - 1),
                  onNext: () => _jumpTo(_page + 1),
                ),
        ),
      ],
    );
  }

  void _jumpTo(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }
}

class _ReaderImagePage extends StatelessWidget {
  const _ReaderImagePage({required this.image});

  final AppDailyComicImage image;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 34).clamp(260.0, 390.0);
        return Center(
          child: SizedBox(
            width: width.toDouble(),
            child: AspectRatio(
              aspectRatio: .68,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFB6A98B)),
                  ),
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: _NetworkComicImage(
                      imageUrl: image.imageUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReaderBottomPager extends StatelessWidget {
  const _ReaderBottomPager({
    super.key,
    required this.index,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  final int index;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 68,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Row(
            children: [
              _PagerButton(
                icon: Icons.chevron_left_rounded,
                enabled: onPrevious != null,
                onTap: onPrevious,
              ),
              Expanded(
                child: Text(
                  '${index + 1}/$total',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _comicDeep,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _PagerButton(
                icon: Icons.chevron_right_rounded,
                enabled: true,
                onTap: onNext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComicEndPanel extends StatelessWidget {
  const _ComicEndPanel({required this.onGoArchive});

  final VoidCallback onGoArchive;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 104,
              height: 92,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: -.32,
                    child: Container(
                      width: 92,
                      height: 30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0xFFE7D9FF),
                          width: 7,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCDB8FF),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _comicPurple.withValues(alpha: .2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                  ),
                  const Positioned(
                    right: 3,
                    top: 8,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFFFFD99D),
                      size: 17,
                    ),
                  ),
                  const Positioned(
                    left: 4,
                    bottom: 18,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFFFFD99D),
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              '已经是最后一话啦',
              style: TextStyle(
                color: _comicMuted,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 142,
              height: 48,
              child: FilledButton(
                onPressed: onGoArchive,
                style: FilledButton.styleFrom(
                  backgroundColor: _comicPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  '去看往期',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComicLoadingList extends StatelessWidget {
  const _ComicLoadingList();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _comicLine),
      ),
      child: Column(
        children: List.generate(
          3,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index == 2 ? 0 : 14),
            child: Row(
              children: [
                const _SkeletonBox(width: 104, height: 104, radius: 18),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _SkeletonBox(width: 160, height: 18, radius: 9),
                      SizedBox(height: 14),
                      _SkeletonBox(width: 100, height: 14, radius: 7),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComicErrorCard extends StatelessWidget {
  const _ComicErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _ComicStateCard(
      icon: Icons.cloud_off_outlined,
      title: '漫画加载失败',
      message: message,
      actionLabel: '重试',
      onAction: onRetry,
    );
  }
}

class _ComicEmptyCard extends StatelessWidget {
  const _ComicEmptyCard({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _ComicStateCard(
      icon: Icons.auto_stories_outlined,
      title: title,
      message: message,
      actionLabel: '刷新',
      onAction: onRetry,
    );
  }
}

class _ComicStateCard extends StatelessWidget {
  const _ComicStateCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _comicLine),
        boxShadow: const [
          BoxShadow(color: _comicShadow, blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.softPink,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _comicPurple, size: 34),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              color: _comicDeep,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _comicMuted,
              fontSize: 14,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: _comicPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _NetworkComicImage extends StatelessWidget {
  const _NetworkComicImage({required this.imageUrl, required this.fit});

  final String imageUrl;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      DailyComicService.instance.resolveAssetUrl(imageUrl),
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          return child;
        }
        return const _ComicCoverPlaceholder();
      },
      errorBuilder: (context, error, stackTrace) {
        return const _ComicImageError();
      },
    );
  }
}

class _ComicCoverPlaceholder extends StatelessWidget {
  const _ComicCoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE9F7FF), Color(0xFFFFEEF7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: const [
          Positioned(
            left: 16,
            top: 14,
            child: Icon(Icons.cloud_rounded, color: Colors.white, size: 34),
          ),
          Positioned(
            right: 14,
            top: 18,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFFFFD3A2),
              size: 18,
            ),
          ),
          Center(
            child: Icon(
              Icons.image_outlined,
              color: Color(0xFFB9A9D9),
              size: 34,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComicImageError extends StatelessWidget {
  const _ComicImageError();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF8FB),
      alignment: Alignment.center,
      child: const Icon(
        Icons.broken_image_outlined,
        color: Color(0xFFC2B7D6),
        size: 38,
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    required this.iconColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .7),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFEADDEB)),
        ),
        child: Icon(
          icon,
          size: 23,
          color: enabled ? _comicDeep : const Color(0xFFD8D2E3),
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F0FA),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

String _episodeTitle(AppDailyComic comic) {
  final title = comic.title.trim();
  return title.isEmpty ? '未命名漫画' : title;
}

String _episodeListTitle(AppDailyComic comic) {
  final title = comic.title.trim();
  return title.isEmpty ? '未命名漫画' : title;
}

String _formatDateYmd(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

String _friendlyComicError(Object? error) {
  final message = error.toString().replaceFirst('Bad state: ', '');
  if (message.contains('无法连接') || message.contains('SocketException')) {
    return '手机暂时连不上漫画服务，请检查网络、后端服务和 XIAOTAI_API_BASE_URL 配置。';
  }
  if (message.contains('超时') || message.contains('TimeoutException')) {
    return '漫画服务响应超时，请确认项目后端正在运行后再重试。';
  }
  return message;
}
