import 'package:flutter/material.dart';

import '../../../core/utils/time_utils.dart';

class HostControls extends StatelessWidget {
  const HostControls({
    super.key,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.playbackRate,
    required this.onPlay,
    required this.onPause,
    required this.onSeek,
    required this.onRateChanged,
  });

  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final double playbackRate;
  final Future<void> Function() onPlay;
  final Future<void> Function() onPause;
  final Future<void> Function(double seconds) onSeek;
  final Future<void> Function(double rate) onRateChanged;

  static const _rates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    final posSec = position.inMilliseconds / 1000.0;
    final durSec = duration.inMilliseconds > 0
        ? duration.inMilliseconds / 1000.0
        : 1.0;

    return Column(
      children: [
        Slider(
          value: posSec.clamp(0, durSec),
          max: durSec,
          onChanged: durSec > 0 ? (v) => onSeek(v) : null,
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: () => isPlaying ? onPause() : onPlay(),
            ),
            Text(
              '${TimeUtils.formatDuration(posSec)} / ${TimeUtils.formatDuration(durSec)}',
              style: const TextStyle(fontSize: 13),
            ),
            const Spacer(),
            DropdownButton<double>(
              value: _rates.contains(playbackRate) ? playbackRate : 1.0,
              underline: const SizedBox.shrink(),
              items: _rates
                  .map((r) => DropdownMenuItem(value: r, child: Text('${r}x')))
                  .toList(),
              onChanged: (rate) {
                if (rate != null) onRateChanged(rate);
              },
            ),
          ],
        ),
      ],
    );
  }
}
