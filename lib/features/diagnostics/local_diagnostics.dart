import 'package:flutter/foundation.dart';

enum RemoteMetric { firstFrame, connection, commandDispatch }

class RemoteMeasurement {
  const RemoteMeasurement(this.metric, this.duration, this.success);
  final RemoteMetric metric;
  final Duration duration;
  final bool success;
}

class LocalDiagnostics extends ValueNotifier<List<RemoteMeasurement>> {
  LocalDiagnostics() : super(const []);
  static final instance = LocalDiagnostics();
  void record(RemoteMetric metric, Duration duration, {required bool success}) {
    if (duration.isNegative) return;
    final next = [...value, RemoteMeasurement(metric, duration, success)];
    value = List.unmodifiable(
      next.length > 100 ? next.sublist(next.length - 100) : next,
    );
  }

  void clear() => value = const [];
  String report() {
    final lines = <String>[
      'Local remote measurements',
      'Request dispatch is not TV execution latency.',
      'Samples are held in memory only.',
    ];
    for (final metric in RemoteMetric.values) {
      final samples = value.where((sample) => sample.metric == metric).toList();
      final durations =
          samples
              .map((sample) => sample.duration.inMicroseconds / 1000)
              .toList()
            ..sort();
      if (samples.isEmpty) {
        lines.add('${metric.name}: no samples');
        continue;
      }
      final median = durations[(durations.length / 2).floor()];
      final p95 =
          durations[((durations.length * 0.95).ceil() - 1).clamp(
            0,
            durations.length - 1,
          )];
      lines.add(
        '${metric.name}: n=${samples.length}, successful=${samples.where((sample) => sample.success).length}, median=${median.toStringAsFixed(1)} ms, p95=${p95.toStringAsFixed(1)} ms',
      );
    }
    return lines.join('\n');
  }
}
