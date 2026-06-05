import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/music/music_service.dart';
import '../../../core/theme/app_colors.dart';

const _musicAccent = Color(0xFF9A6DEB);
const _musicInk = Color(0xFF111833);
const _musicMuted = Color(0xFF8F93A8);
const _musicPanel = Colors.transparent;
const _musicShadow = Color(0x1A8D6BC2);

class MusicPlayerPage extends StatefulWidget {
  const MusicPlayerPage({super.key});

  @override
  State<MusicPlayerPage> createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends State<MusicPlayerPage> {
  late Future<AppMusicPage> _tracksFuture;
  final _player = AudioPlayer();
  final _placeholderPositionController = StreamController<Duration>.broadcast();
  AppMusicTrack? _currentTrack;
  Timer? _placeholderTimer;
  Duration _placeholderPosition = Duration.zero;
  String? _placeholderTrackId;
  bool _loadingTrack = false;
  bool _playPauseBusy = false;
  bool _showPlaylist = false;
  bool _liked = false;
  bool _placeholderPlaying = false;
  String _playlistQuery = '';

  @override
  void initState() {
    super.initState();
    _tracksFuture = MusicService.instance.fetchTracks();
  }

  @override
  void dispose() {
    _placeholderTimer?.cancel();
    _placeholderPositionController.close();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _musicPanel,
      body: FutureBuilder<AppMusicPage>(
        future: _tracksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _currentTrack == null) {
            return const _MusicLoadingShell();
          }
          final tracks = _visibleTracks(snapshot);
          if (tracks.isEmpty) {
            return _MusicEmptyShell(
              onBack: _handleBack,
              onRefresh: _refreshTracks,
            );
          }
          final current = _resolveCurrentTrack(tracks);
          final usingPlaceholder = _isPlaceholderTrack(current);
          return _MusicShell(
            showPlaylist: _showPlaylist,
            currentTrack: current,
            tracks: tracks,
            playlistQuery: _playlistQuery,
            player: _player,
            loadingTrack: _loadingTrack,
            liked: _liked,
            usingPlaceholder: usingPlaceholder,
            placeholderPlaying: _placeholderPlaying,
            placeholderPosition: _placeholderPosition,
            placeholderPositionStream: _placeholderPositionController.stream,
            onBack: _handleBack,
            onMore: _showReservedMenu,
            onPlaylistSearch: _openPlaylistSearch,
            onPlaylistRefresh: _refreshTracks,
            onShowPlayer: () => setState(() => _showPlaylist = false),
            onTrackTap: _playTrack,
            onPlayPause: _togglePlayback,
            onPrevious: () => _skipTrack(tracks, -1),
            onNext: () => _skipTrack(tracks, 1),
            onSeek: (position) => _seekPlayback(current, position),
            onToggleLoop: _toggleLoop,
            onToggleLike: () => setState(() => _liked = !_liked),
            onReservedAction: _showReservedMenu,
          );
        },
      ),
    );
  }

  List<AppMusicTrack> _visibleTracks(AsyncSnapshot<AppMusicPage> snapshot) {
    return snapshot.data?.items ?? const <AppMusicTrack>[];
  }

  AppMusicTrack _resolveCurrentTrack(List<AppMusicTrack> tracks) {
    final current = _currentTrack;
    if (current != null) {
      final index = tracks.indexWhere((track) => track.id == current.id);
      if (index != -1) {
        return tracks[index];
      }
    }
    _currentTrack = tracks.first;
    return tracks.first;
  }

  void _handleBack() {
    if (_showPlaylist) {
      setState(() => _showPlaylist = false);
      return;
    }
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.treasureBox);
  }

  Future<void> _openPlaylistSearch() async {
    final controller = TextEditingController(text: _playlistQuery);
    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('搜索歌曲'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入歌名或歌手',
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
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (query == null || !mounted) {
      return;
    }
    setState(() => _playlistQuery = query);
  }

  void _refreshTracks() {
    setState(() {
      _tracksFuture = MusicService.instance.fetchTracks();
      _playlistQuery = '';
    });
    _showTip('已刷新曲库');
  }

  Future<void> _togglePlayback() async {
    if (_playPauseBusy) {
      return;
    }
    final track = _currentTrack;
    if (track == null) {
      return;
    }
    if (_isPlaceholderTrack(track)) {
      if (_placeholderPlaying) {
        _pausePlaceholderPlayback();
      } else {
        _startPlaceholderPlayback(track);
      }
      return;
    }
    _playPauseBusy = true;
    try {
      if (_player.audioSource == null) {
        await _playTrack(track);
        return;
      }
      if (_player.playing) {
        await _player.pause();
      } else {
        unawaited(_player.play());
      }
    } finally {
      _playPauseBusy = false;
    }
  }

  Future<void> _playTrack(AppMusicTrack track) async {
    if (_loadingTrack) {
      return;
    }
    setState(() {
      _loadingTrack = true;
      _currentTrack = track;
      _showPlaylist = false;
    });
    try {
      if (_isPlaceholderTrack(track)) {
        _startPlaceholderPlayback(track, resetIfTrackChanged: true);
        return;
      }
      _stopPlaceholderPlayback();
      final url = MusicService.instance.resolveAssetUrl(track.audioUrl);
      await _player.setUrl(url);
      unawaited(_player.play());
    } catch (error) {
      if (mounted) {
        _showTip('播放失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _loadingTrack = false);
      }
    }
  }

  Future<void> _skipTrack(List<AppMusicTrack> tracks, int offset) async {
    final current = _currentTrack ?? tracks.first;
    final index = tracks.indexWhere((track) => track.id == current.id);
    final safeIndex = index == -1 ? 0 : index;
    final nextIndex = (safeIndex + offset) % tracks.length;
    await _playTrack(tracks[nextIndex < 0 ? tracks.length - 1 : nextIndex]);
  }

  Future<void> _toggleLoop() async {
    final next = _player.loopMode == LoopMode.one ? LoopMode.off : LoopMode.one;
    await _player.setLoopMode(next);
  }

  Future<void> _seekPlayback(AppMusicTrack track, Duration position) async {
    if (!_isPlaceholderTrack(track)) {
      await _player.seek(position);
      return;
    }
    final duration = _durationFor(track);
    final clampedMs = position.inMilliseconds.clamp(0, duration.inMilliseconds);
    final clamped = Duration(milliseconds: clampedMs);
    setState(() {
      _placeholderTrackId = track.id;
      _placeholderPosition = clamped;
    });
    _placeholderPositionController.add(_placeholderPosition);
  }

  void _startPlaceholderPlayback(
    AppMusicTrack track, {
    bool resetIfTrackChanged = false,
  }) {
    final duration = _durationFor(track);
    final changed = _placeholderTrackId != track.id;
    _placeholderTimer?.cancel();
    if (changed || resetIfTrackChanged || _placeholderPosition >= duration) {
      _placeholderPosition = Duration.zero;
    }
    _placeholderTrackId = track.id;
    _placeholderPlaying = true;
    _placeholderPositionController.add(_placeholderPosition);
    _placeholderTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) {
      final duration = _durationFor(track);
      final next = _placeholderPosition + const Duration(milliseconds: 500);
      if (next >= duration) {
        if (_player.loopMode == LoopMode.one) {
          _placeholderPosition = Duration.zero;
        } else {
          _placeholderPosition = duration;
          _placeholderPlaying = false;
          timer.cancel();
        }
      } else {
        _placeholderPosition = next;
      }
      if (mounted) {
        setState(() {});
      }
      _placeholderPositionController.add(_placeholderPosition);
    });
    if (mounted) {
      setState(() {});
    }
  }

  void _pausePlaceholderPlayback() {
    _placeholderTimer?.cancel();
    _placeholderTimer = null;
    setState(() => _placeholderPlaying = false);
    _placeholderPositionController.add(_placeholderPosition);
  }

  void _stopPlaceholderPlayback() {
    _placeholderTimer?.cancel();
    _placeholderTimer = null;
    if (_placeholderPlaying) {
      setState(() => _placeholderPlaying = false);
    } else {
      _placeholderPlaying = false;
    }
  }

  void _showReservedMenu() {
    final track = _currentTrack;
    if (track == null) {
      _showTip('暂无播放歌曲');
      return;
    }
    _showTip('${track.title} · ${track.artist}');
  }

  void _showTip(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MusicShell extends StatelessWidget {
  const _MusicShell({
    required this.showPlaylist,
    required this.currentTrack,
    required this.tracks,
    required this.playlistQuery,
    required this.player,
    required this.loadingTrack,
    required this.liked,
    required this.usingPlaceholder,
    required this.placeholderPlaying,
    required this.placeholderPosition,
    required this.placeholderPositionStream,
    required this.onBack,
    required this.onMore,
    required this.onPlaylistSearch,
    required this.onPlaylistRefresh,
    required this.onShowPlayer,
    required this.onTrackTap,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onSeek,
    required this.onToggleLoop,
    required this.onToggleLike,
    required this.onReservedAction,
  });

  final bool showPlaylist;
  final AppMusicTrack currentTrack;
  final List<AppMusicTrack> tracks;
  final String playlistQuery;
  final AudioPlayer player;
  final bool loadingTrack;
  final bool liked;
  final bool usingPlaceholder;
  final bool placeholderPlaying;
  final Duration placeholderPosition;
  final Stream<Duration> placeholderPositionStream;
  final VoidCallback onBack;
  final VoidCallback onMore;
  final VoidCallback onPlaylistSearch;
  final VoidCallback onPlaylistRefresh;
  final VoidCallback onShowPlayer;
  final ValueChanged<AppMusicTrack> onTrackTap;
  final Future<void> Function() onPlayPause;
  final Future<void> Function() onPrevious;
  final Future<void> Function() onNext;
  final Future<void> Function(Duration position) onSeek;
  final Future<void> Function() onToggleLoop;
  final VoidCallback onToggleLike;
  final VoidCallback onReservedAction;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x20FFFFFF), Color(0x14FFF3FA), Color(0x18F8F2FF)],
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: showPlaylist
            ? _PlaylistPage(
                key: const ValueKey('music-playlist'),
                currentTrack: currentTrack,
                tracks: tracks,
                query: playlistQuery,
                onBack: onBack,
                onMore: onMore,
                onSearch: onPlaylistSearch,
                onRefresh: onPlaylistRefresh,
                onTrackTap: onTrackTap,
                onReservedAction: onReservedAction,
              )
            : _NowPlayingPage(
                key: const ValueKey('music-now-playing'),
                track: currentTrack,
                tracks: tracks,
                player: player,
                loadingTrack: loadingTrack,
                liked: liked,
                usingPlaceholder: usingPlaceholder,
                placeholderPlaying: placeholderPlaying,
                placeholderPosition: placeholderPosition,
                placeholderPositionStream: placeholderPositionStream,
                onBack: onBack,
                onMore: onMore,
                onPlayPause: onPlayPause,
                onPrevious: onPrevious,
                onNext: onNext,
                onSeek: onSeek,
                onToggleLoop: onToggleLoop,
                onToggleLike: onToggleLike,
              ),
      ),
    );
  }
}

class _NowPlayingPage extends StatelessWidget {
  const _NowPlayingPage({
    super.key,
    required this.track,
    required this.tracks,
    required this.player,
    required this.loadingTrack,
    required this.liked,
    required this.usingPlaceholder,
    required this.placeholderPlaying,
    required this.placeholderPosition,
    required this.placeholderPositionStream,
    required this.onBack,
    required this.onMore,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onSeek,
    required this.onToggleLoop,
    required this.onToggleLike,
  });

  final AppMusicTrack track;
  final List<AppMusicTrack> tracks;
  final AudioPlayer player;
  final bool loadingTrack;
  final bool liked;
  final bool usingPlaceholder;
  final bool placeholderPlaying;
  final Duration placeholderPosition;
  final Stream<Duration> placeholderPositionStream;
  final VoidCallback onBack;
  final VoidCallback onMore;
  final Future<void> Function() onPlayPause;
  final Future<void> Function() onPrevious;
  final Future<void> Function() onNext;
  final Future<void> Function(Duration position) onSeek;
  final Future<void> Function() onToggleLoop;
  final VoidCallback onToggleLike;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final artSize = math.min(width - 70, 390.0);
    final bottomPadding = 42 + MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _MusicTopBar(onBack: onBack, onMore: onMore),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(30, 30, 30, bottomPadding),
              children: [
                Center(
                  child: _AlbumArtwork(
                    track: track,
                    size: artSize,
                    rounded: 34,
                  ),
                ),
                const SizedBox(height: 34),
                _TrackTitleBlock(
                  track: track,
                  liked: liked,
                  onToggleLike: onToggleLike,
                ),
                const SizedBox(height: 30),
                _CurrentLyricLine(
                  track: track,
                  player: player,
                  usingPlaceholder: usingPlaceholder,
                  placeholderPosition: placeholderPosition,
                  placeholderPositionStream: placeholderPositionStream,
                ),
                const SizedBox(height: 25),
                _MusicProgressBar(
                  track: track,
                  player: player,
                  usingPlaceholder: usingPlaceholder,
                  placeholderPosition: placeholderPosition,
                  placeholderPositionStream: placeholderPositionStream,
                  onSeek: onSeek,
                ),
                const SizedBox(height: 20),
                _PrimaryControls(
                  player: player,
                  loadingTrack: loadingTrack,
                  liked: liked,
                  usingPlaceholder: usingPlaceholder,
                  placeholderPlaying: placeholderPlaying,
                  onToggleLike: onToggleLike,
                  onPrevious: onPrevious,
                  onNext: onNext,
                  onPlayPause: onPlayPause,
                  onToggleLoop: onToggleLoop,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistPage extends StatelessWidget {
  const _PlaylistPage({
    super.key,
    required this.currentTrack,
    required this.tracks,
    required this.query,
    required this.onBack,
    required this.onMore,
    required this.onSearch,
    required this.onRefresh,
    required this.onTrackTap,
    required this.onReservedAction,
  });

  final AppMusicTrack currentTrack;
  final List<AppMusicTrack> tracks;
  final String query;
  final VoidCallback onBack;
  final VoidCallback onMore;
  final VoidCallback onSearch;
  final VoidCallback onRefresh;
  final ValueChanged<AppMusicTrack> onTrackTap;
  final VoidCallback onReservedAction;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = 42 + MediaQuery.paddingOf(context).bottom;
    final trimmedQuery = query.trim();
    final visibleTracks = trimmedQuery.isEmpty
        ? tracks
        : tracks
              .where(
                (track) =>
                    track.title.contains(trimmedQuery) ||
                    (track.artist ?? '').contains(trimmedQuery) ||
                    (track.album ?? '').contains(trimmedQuery),
              )
              .toList();
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _MusicTopBar(title: '播放列表', onBack: onBack, onMore: onMore),
          Padding(
            padding: const EdgeInsets.fromLTRB(34, 18, 34, 8),
            child: Row(
              children: [
                _TinyModeIcon(icon: Icons.album_outlined, selected: true),
                const SizedBox(width: 10),
                _TinyModeIcon(icon: Icons.menu_book_outlined, selected: false),
                const Spacer(),
                _CircleToolButton(
                  icon: Icons.search_rounded,
                  onTap: onSearch,
                  faded: true,
                ),
                const SizedBox(width: 13),
                _CircleToolButton(
                  icon: Icons.refresh_rounded,
                  onTap: onRefresh,
                  faded: true,
                ),
              ],
            ),
          ),
          if (trimmedQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(34, 0, 34, 8),
              child: _PlaylistSearchNotice(query: trimmedQuery),
            ),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(26, 8, 26, bottomPadding),
              itemCount: visibleTracks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final track = visibleTracks[index];
                final selected = track.id == currentTrack.id;
                return _PlaylistRow(
                  track: track,
                  index: index,
                  selected: selected,
                  dimmed: index == visibleTracks.length - 1,
                  onTap: () => onTrackTap(track),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MusicTopBar extends StatelessWidget {
  const _MusicTopBar({required this.onBack, required this.onMore, this.title});

  final String? title;
  final VoidCallback onBack;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (title != null)
            Text(
              title!,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          Positioned(left: 24, child: _MusicBackButton(onTap: onBack)),
          Positioned(
            right: 27,
            child: _CircleToolButton(
              icon: Icons.more_horiz_rounded,
              onTap: onMore,
              size: 30,
              iconSize: 18,
              faded: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistSearchNotice extends StatelessWidget {
  const _PlaylistSearchNotice({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .74),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: _musicAccent, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '搜索：$query',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _musicInk,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentLyricLine extends StatelessWidget {
  const _CurrentLyricLine({
    required this.track,
    required this.player,
    required this.usingPlaceholder,
    required this.placeholderPosition,
    required this.placeholderPositionStream,
  });

  final AppMusicTrack track;
  final AudioPlayer player;
  final bool usingPlaceholder;
  final Duration placeholderPosition;
  final Stream<Duration> placeholderPositionStream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: usingPlaceholder
          ? placeholderPositionStream
          : player.positionStream,
      builder: (context, snapshot) {
        final rawPosition =
            snapshot.data ??
            (usingPlaceholder ? placeholderPosition : Duration.zero);
        final position = rawPosition > Duration.zero
            ? rawPosition
            : Duration.zero;
        final lyric = _lyricAt(track, position);
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            lyric,
            key: ValueKey('${track.id}_$lyric'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _musicMuted,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        );
      },
    );
  }
}

class _TrackTitleBlock extends StatelessWidget {
  const _TrackTitleBlock({
    required this.track,
    required this.liked,
    required this.onToggleLike,
  });

  final AppMusicTrack track;
  final bool liked;
  final VoidCallback onToggleLike;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _artist(track),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _musicInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onToggleLike,
          child: SizedBox(
            width: 56,
            child: Column(
              children: [
                Icon(
                  liked ? Icons.favorite_rounded : Icons.favorite_border,
                  color: const Color(0xFFE9A4B6),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AlbumArtwork extends StatelessWidget {
  const _AlbumArtwork({
    required this.track,
    required this.size,
    required this.rounded,
  });

  final AppMusicTrack track;
  final double size;
  final double rounded;

  @override
  Widget build(BuildContext context) {
    final coverUrl = _coverUrl(track);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFECE7FF),
        borderRadius: BorderRadius.circular(rounded),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .12),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: coverUrl == null
          ? const _AlbumPlaceholder()
          : Image.network(
              coverUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _AlbumPlaceholder(),
            ),
    );
  }
}

class _AlbumPlaceholder extends StatelessWidget {
  const _AlbumPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3EFFF), Color(0xFFFFF4FA)],
        ),
      ),
      child: Center(
        child: Icon(Icons.music_note_rounded, color: _musicAccent, size: 44),
      ),
    );
  }
}

class _MusicProgressBar extends StatelessWidget {
  const _MusicProgressBar({
    required this.track,
    required this.player,
    required this.usingPlaceholder,
    required this.placeholderPosition,
    required this.placeholderPositionStream,
    required this.onSeek,
  });

  final AppMusicTrack track;
  final AudioPlayer player;
  final bool usingPlaceholder;
  final Duration placeholderPosition;
  final Stream<Duration> placeholderPositionStream;
  final Future<void> Function(Duration position) onSeek;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: usingPlaceholder
          ? placeholderPositionStream
          : player.positionStream,
      builder: (context, snapshot) {
        final realDuration = player.duration ?? Duration.zero;
        final duration = realDuration > Duration.zero
            ? realDuration
            : _durationFor(track);
        final rawPosition =
            snapshot.data ??
            (usingPlaceholder ? placeholderPosition : Duration.zero);
        final position = rawPosition > Duration.zero
            ? rawPosition
            : Duration.zero;
        final maxMs = math.max(duration.inMilliseconds, 1);
        final value = position.inMilliseconds.clamp(0, maxMs).toDouble();
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: _musicAccent,
                inactiveTrackColor: const Color(0xFFE4E0EB),
                thumbColor: _musicAccent,
                overlayColor: _musicAccent.withValues(alpha: .12),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: value,
                max: maxMs.toDouble(),
                onChanged: (next) {
                  onSeek(Duration(milliseconds: next.round()));
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(position),
                  style: const TextStyle(
                    color: _musicMuted,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: const TextStyle(
                    color: _musicMuted,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _PrimaryControls extends StatelessWidget {
  const _PrimaryControls({
    required this.player,
    required this.loadingTrack,
    required this.liked,
    required this.usingPlaceholder,
    required this.placeholderPlaying,
    required this.onToggleLike,
    required this.onPrevious,
    required this.onNext,
    required this.onPlayPause,
    required this.onToggleLoop,
  });

  final AudioPlayer player;
  final bool loadingTrack;
  final bool liked;
  final bool usingPlaceholder;
  final bool placeholderPlaying;
  final VoidCallback onToggleLike;
  final Future<void> Function() onPrevious;
  final Future<void> Function() onNext;
  final Future<void> Function() onPlayPause;
  final Future<void> Function() onToggleLoop;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ControlIconButton(
          icon: liked ? Icons.favorite_rounded : Icons.favorite_border,
          color: liked ? const Color(0xFFCE5E82) : _musicMuted,
          onTap: onToggleLike,
        ),
        _ControlIconButton(
          icon: Icons.skip_previous_rounded,
          color: _musicInk,
          iconSize: 38,
          onTap: onPrevious,
        ),
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (context, snapshot) {
            final playing = usingPlaceholder
                ? placeholderPlaying
                : (snapshot.data?.playing ?? player.playing);
            return InkWell(
              borderRadius: BorderRadius.circular(42),
              onTap: loadingTrack ? null : onPlayPause,
              child: Container(
                width: 68,
                height: 68,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3D7EB),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE9BBD6).withValues(alpha: .45),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: loadingTrack
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: _musicInk,
                        ),
                      )
                    : Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: _musicInk,
                        size: 42,
                      ),
              ),
            );
          },
        ),
        _ControlIconButton(
          icon: Icons.skip_next_rounded,
          color: _musicInk,
          iconSize: 38,
          onTap: onNext,
        ),
        StreamBuilder<LoopMode>(
          stream: player.loopModeStream,
          builder: (context, snapshot) {
            final looping = (snapshot.data ?? player.loopMode) == LoopMode.one;
            return _ControlIconButton(
              icon: looping ? Icons.repeat_one_rounded : Icons.repeat_rounded,
              color: looping ? _musicAccent : _musicMuted,
              onTap: onToggleLoop,
            );
          },
        ),
      ],
    );
  }
}

class _ControlIconButton extends StatelessWidget {
  const _ControlIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.iconSize = 29,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: SizedBox(
        width: 50,
        height: 50,
        child: Icon(icon, color: color, size: iconSize),
      ),
    );
  }
}

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({
    required this.track,
    required this.index,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final AppMusicTrack track;
  final int index;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final opacity = dimmed ? .35 : 1.0;
    return Opacity(
      opacity: opacity,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: selected ? 84 : 68),
          padding: EdgeInsets.fromLTRB(
            16,
            selected ? 13 : 9,
            14,
            selected ? 13 : 9,
          ),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: .88)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _musicShadow,
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              _AlbumArtwork(
                track: track,
                size: selected ? 58 : 54,
                rounded: 10,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _musicInk,
                        fontSize: selected ? 17 : 16,
                        fontWeight: selected
                            ? FontWeight.w900
                            : FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _artist(track),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _musicMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              selected
                  ? const Row(
                      children: [
                        Icon(
                          Icons.pause_rounded,
                          color: _musicAccent,
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Icon(
                          Icons.remove_rounded,
                          color: _musicAccent,
                          size: 24,
                        ),
                      ],
                    )
                  : Text(
                      _trackDurationLabel(track),
                      style: const TextStyle(
                        color: _musicMuted,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TinyModeIcon extends StatelessWidget {
  const _TinyModeIcon({required this.icon, required this.selected});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFFE8DDF9)
            : Colors.white.withValues(alpha: .45),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: selected ? _musicAccent : AppColors.textTertiary,
        size: 15,
      ),
    );
  }
}

class _CircleToolButton extends StatelessWidget {
  const _CircleToolButton({
    required this.icon,
    required this.onTap,
    this.size = 34,
    this.iconSize = 22,
    this.faded = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(size / 2),
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: faded
              ? const Color(0xFFE9E2F3).withValues(alpha: .6)
              : Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: faded ? const Color(0xFF9488AA) : _musicInk,
          size: iconSize,
        ),
      ),
    );
  }
}

class _MusicBackButton extends StatelessWidget {
  const _MusicBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const CustomPaint(
          size: Size(10, 16),
          painter: _MusicBackChevronPainter(),
        ),
      ),
    );
  }
}

class _MusicBackChevronPainter extends CustomPainter {
  const _MusicBackChevronPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _musicInk
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MusicBackChevronPainter oldDelegate) => false;
}

class _MusicLoadingShell extends StatelessWidget {
  const _MusicLoadingShell();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x20FFFFFF), Color(0x14FFF3FA), Color(0x18F8F2FF)],
        ),
      ),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 168,
              height: 132,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .72),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: _musicShadow,
                    blurRadius: 22,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: const CircularProgressIndicator(color: _musicAccent),
            ),
          ),
        ),
      ),
    );
  }
}

class _MusicEmptyShell extends StatelessWidget {
  const _MusicEmptyShell({required this.onBack, required this.onRefresh});

  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x20FFFFFF), Color(0x14FFF3FA), Color(0x18F8F2FF)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _MusicBackButton(onTap: onBack),
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .76),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: _musicShadow,
                      blurRadius: 22,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.library_music_outlined,
                      color: _musicAccent,
                      size: 34,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '曲库暂无歌曲',
                      style: TextStyle(
                        color: _musicInk,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '请在管理端上传音乐后刷新',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _musicMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('刷新曲库'),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isPlaceholderTrack(AppMusicTrack track) {
  final audioUrl = track.audioUrl.trim();
  return audioUrl.isEmpty;
}

String? _coverUrl(AppMusicTrack track) {
  final coverUrl = track.coverUrl;
  if (coverUrl == null || coverUrl.isEmpty) {
    return null;
  }
  return MusicService.instance.resolveAssetUrl(coverUrl);
}

String _artist(AppMusicTrack track) {
  final artist = track.artist?.trim();
  if (artist == null || artist.isEmpty) {
    return '未知歌手';
  }
  return artist;
}

class _LyricLine {
  const _LyricLine({required this.time, required this.text});

  final Duration time;
  final String text;
}

String _lyricAt(AppMusicTrack track, Duration position) {
  final lines = _parseLyrics(track);
  if (lines.isEmpty) {
    return _lyricPreview(track);
  }
  var selected = lines.first;
  for (final line in lines) {
    if (line.time <= position) {
      selected = line;
    } else {
      break;
    }
  }
  return selected.text;
}

List<_LyricLine> _parseLyrics(AppMusicTrack track) {
  final lyrics = track.lyrics?.trim();
  if (lyrics == null || lyrics.isEmpty) {
    return const [];
  }
  final tagPattern = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');
  final parsed = <_LyricLine>[];
  for (final rawLine in lyrics.split(RegExp(r'\r?\n'))) {
    final matches = tagPattern.allMatches(rawLine).toList();
    if (matches.isEmpty) {
      continue;
    }
    final text = rawLine.replaceAll(tagPattern, '').trim();
    if (text.isEmpty) {
      continue;
    }
    for (final match in matches) {
      final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
      final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
      final fractionText = match.group(3);
      final milliseconds = fractionText == null
          ? 0
          : int.parse(fractionText.padRight(3, '0').substring(0, 3));
      parsed.add(
        _LyricLine(
          time: Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds,
          ),
          text: text,
        ),
      );
    }
  }
  parsed.sort((left, right) => left.time.compareTo(right.time));
  return parsed;
}

String _lyricPreview(AppMusicTrack track) {
  final lyrics = track.lyrics?.trim();
  if (lyrics == null || lyrics.isEmpty) {
    return '暂无歌词';
  }
  final tagPattern = RegExp(r'\[\d{1,2}:\d{2}(?:[.:]\d{1,3})?\]');
  final lines = lyrics
      .split(RegExp(r'\r?\n'))
      .map((line) => line.replaceAll(tagPattern, '').trim())
      .where((line) => line.isNotEmpty)
      .take(2)
      .toList();
  if (lines.isEmpty) {
    return '暂无歌词';
  }
  return lines.join('，');
}

Duration _durationFor(AppMusicTrack track) {
  final durationSeconds = track.durationSeconds;
  if (durationSeconds != null && durationSeconds > 0) {
    return Duration(seconds: durationSeconds);
  }
  return Duration.zero;
}

String _trackDurationLabel(AppMusicTrack track) {
  return _formatDuration(_durationFor(track));
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
