import 'package:flutter/material.dart';

import '../brand.dart';
import '../controller.dart';
import '../sounds.dart';
import '../strings.dart';

/// Bottom sheet to pick the ambient focus sound and its volume.
Future<void> showSoundSheet(BuildContext context, PomodoroController c) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Brand.surface,
    showDragHandle: true,
    builder:
        (_) => ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final current = AmbientSoundInfo.parse(c.settings.ambientSound);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('focusSound'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('focusSoundSubtitle'),
                      style: const TextStyle(color: Brand.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.15,
                      children: [
                        for (final sound in AmbientSound.values)
                          _SoundTile(
                            sound: sound,
                            selected: sound == current,
                            onTap: () => c.chooseSound(sound),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.volume_down_rounded),
                        Expanded(
                          child: Slider(
                            value: c.settings.soundVolume.toDouble(),
                            max: 100,
                            divisions: 20,
                            label: '${c.settings.soundVolume}',
                            semanticFormatterCallback:
                                (v) => '${context.tr('volume')} ${v.round()}',
                            onChanged:
                                current == AmbientSound.none
                                    ? null
                                    : (v) => c.updateSettings(
                                      c.settings.copyWith(
                                        soundVolume: v.round(),
                                      ),
                                    ),
                            onChangeEnd: (_) => c.chooseSound(current),
                          ),
                        ),
                        const Icon(Icons.volume_up_rounded),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
  );
}

class _SoundTile extends StatelessWidget {
  const _SoundTile({
    required this.sound,
    required this.selected,
    required this.onTap,
  });

  final AmbientSound sound;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: selected ? Brand.indigo.withAlpha(70) : Brand.surfaceHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? Brand.cyan : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                sound.icon,
                color: selected ? Brand.cyan : Brand.textSecondary,
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  context.tr(sound.labelKey),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
