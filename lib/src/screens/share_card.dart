import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../brand.dart';
import '../controller.dart';
import '../models.dart';
import '../strings.dart';

/// Shows a preview of this week's progress card and shares it as an image.
Future<void> showShareCard(BuildContext context, PomodoroController c) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ShareDialog(controller: c),
  );
}

class _ShareDialog extends StatefulWidget {
  const _ShareDialog({required this.controller});

  final PomodoroController controller;

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  final _boundary = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final render =
          _boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/sumera-progress.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      if (!mounted) return;
      final week = widget.controller.dayStats(7);
      final minutes = week.fold(0, (s, d) => s + d.minutes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: context
              .tr('shareText')
              .replaceAll('{duration}', AppStrings.duration(context, minutes)),
        ),
      );
    } catch (error) {
      debugPrint('Share failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Brand.surface,
      insetPadding: const EdgeInsets.all(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              key: _boundary,
              child: ProgressCard(controller: widget.controller),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.tr('close')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _share,
                    icon: const Icon(Icons.ios_share_rounded),
                    label: Text(context.tr('share')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The image people share: this week's focus time, a 7-day bar strip,
/// streak and stars.
class ProgressCard extends StatelessWidget {
  const ProgressCard({super.key, required this.controller});

  final PomodoroController controller;

  @override
  Widget build(BuildContext context) {
    final week = controller.dayStats(7);
    final minutes = week.fold(0, (s, d) => s + d.minutes);
    final pomodoros = week.fold(0, (s, d) => s + d.pomodoros);
    final peak = week.fold(0, (m, d) => math.max(m, d.minutes));

    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6C4DFF), Color(0xFF2D1F8C), Color(0xFF16123A)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/branding/emblem.png',
                    width: 30,
                    height: 30,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  kAppName,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              context.tr('shareThisWeek').toUpperCase(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                AppStrings.duration(context, minutes),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 70,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in week)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Container(
                          height:
                              peak == 0
                                  ? 4
                                  : math.max(4, 70 * d.minutes / peak),
                          decoration: BoxDecoration(
                            color:
                                d.day == dateOnly(DateTime.now())
                                    ? Brand.cyan
                                    : Colors.white.withAlpha(200),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _Metric(
                  icon: Icons.check_circle_rounded,
                  value: '$pomodoros',
                  label: context.tr('pomodoros'),
                ),
                _Metric(
                  icon: Icons.local_fire_department_rounded,
                  value: '${controller.streak}',
                  label: context.tr('streak'),
                ),
                _Metric(
                  icon: Icons.auto_awesome_rounded,
                  value: '${controller.totalPomodoros}',
                  label: context.tr('totalStars'),
                ),
              ],
            ),
            const Spacer(),
            Text(
              context.tr('shareFooter'),
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Brand.cyan, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
