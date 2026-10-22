import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../brand.dart';
import '../controller.dart';
import '../strings.dart';
import '../widgets.dart';

void openFullscreenTimer(BuildContext context, PomodoroController controller) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => FullscreenTimerPage(controller: controller),
      transitionsBuilder:
          (_, animation, __, child) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: 0.96, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          ),
    ),
  );
}

/// Distraction-free countdown that fills the whole screen. Controls fade out
/// while the timer runs and come back on tap.
class FullscreenTimerPage extends StatefulWidget {
  const FullscreenTimerPage({super.key, required this.controller});

  final PomodoroController controller;

  @override
  State<FullscreenTimerPage> createState() => _FullscreenTimerPageState();
}

class _FullscreenTimerPageState extends State<FullscreenTimerPage> {
  bool _controlsVisible = true;
  bool _wasRunning = false;
  Timer? _hideTimer;

  PomodoroController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _wasRunning = c.isRunning;
    c.addListener(_onControllerChanged);
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    c.removeListener(_onControllerChanged);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onControllerChanged() {
    if (c.isRunning == _wasRunning) return;
    _wasRunning = c.isRunning;
    if (!c.isRunning) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = true);
    } else {
      _scheduleHide();
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!c.isRunning) return;
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && c.isRunning) setState(() => _controlsVisible = false);
    });
  }

  void _onTap() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  /// Runs a control action and keeps the controls on screen a bit longer.
  void _act(VoidCallback action) {
    action();
    _scheduleHide();
  }

  String _format(int seconds) {
    final h = seconds ~/ 3600;
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final colors = [
          for (final color in c.mode.gradient)
            Color.lerp(color, Colors.black, 0.45)!,
        ];

        return Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
              ),
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final landscape = box.maxWidth > box.maxHeight;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child:
                              landscape
                                  ? _buildLandscape(context, box)
                                  : _buildPortrait(context, box),
                        ),
                        _buildTopBar(context),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: landscape ? 8 : 24,
                          child: _buildControls(context),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _caption(BuildContext context) {
    final task = c.activeTask?.title;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.tr(c.mode.labelKey).toUpperCase(),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        if (task != null) ...[
          const SizedBox(height: 6),
          Text(
            task,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 15),
          ),
        ],
      ],
    );
  }

  Widget _time(double maxWidth) {
    return SizedBox(
      width: maxWidth,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          _format(c.remainingSeconds),
          style: const TextStyle(
            fontSize: 200,
            height: 1,
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }

  Widget _buildPortrait(BuildContext context, BoxConstraints box) {
    final ring = (box.maxWidth * 0.86).clamp(200.0, box.maxHeight * 0.6);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _caption(context),
        const SizedBox(height: 28),
        Semantics(
          label:
              '${context.tr(c.mode.labelKey)} ${_format(c.remainingSeconds)}',
          child: TimerRing(
            progress: c.progress,
            size: ring,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: ring * 0.14),
              child: _time(ring * 0.72),
            ),
          ),
        ),
        const SizedBox(height: 90),
      ],
    );
  }

  Widget _buildLandscape(BuildContext context, BoxConstraints box) {
    final width = box.maxWidth * 0.78;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _caption(context),
        const SizedBox(height: 8),
        SizedBox(height: box.maxHeight * 0.5, child: _time(width)),
        const SizedBox(height: 16),
        SizedBox(
          width: width,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: c.progress),
              duration: const Duration(milliseconds: 400),
              builder:
                  (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    color: Brand.cyan,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 64),
      ],
    );
  }

  Widget _fade({required Widget child}) {
    return IgnorePointer(
      ignoring: !_controlsVisible,
      child: AnimatedOpacity(
        opacity: _controlsVisible ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        child: child,
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 4,
      left: 4,
      right: 4,
      child: _fade(
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              tooltip: context.tr('exitFullscreen'),
              color: Colors.white,
              iconSize: 30,
              icon: const Icon(Icons.fullscreen_exit_rounded),
            ),
            const Spacer(),
            if (c.isRunning)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  context.tr('fullscreenHint'),
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    final min = context.tr('minutesShort');
    final round = IconButton.styleFrom(
      backgroundColor: Colors.white.withAlpha(30),
      foregroundColor: Colors.white,
      minimumSize: const Size(52, 52),
    );

    return _fade(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          TextButton(
            onPressed: () => _act(() => c.extend(1)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withAlpha(30),
              minimumSize: const Size(64, 52),
              shape: const StadiumBorder(),
            ),
            child: Text('+1 $min'),
          ),
          IconButton(
            onPressed: c.isPristine ? null : () => _act(c.reset),
            tooltip: context.tr('reset'),
            style: round,
            icon: const Icon(Icons.refresh_rounded),
          ),
          SizedBox.square(
            dimension: 76,
            child: IconButton.filled(
              onPressed: () => _act(c.toggle),
              tooltip: context.tr(c.isRunning ? 'pause' : 'start'),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: c.mode.gradient.last,
              ),
              iconSize: 40,
              icon: Icon(
                c.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _act(c.skip),
            tooltip: context.tr('skip'),
            style: round,
            icon: const Icon(Icons.skip_next_rounded),
          ),
          TextButton(
            onPressed: () => _act(() => c.extend(5)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withAlpha(30),
              minimumSize: const Size(64, 52),
              shape: const StadiumBorder(),
            ),
            child: Text('+5 $min'),
          ),
        ],
      ),
    );
  }
}
