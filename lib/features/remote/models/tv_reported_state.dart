import '../../../core/protocol/android_tv/android_tv_remote_client.dart';

/// Reports belong to one connection and are never carried into a new session.
class TvReportedState {
  const TvReportedState({this.power, this.volume, this.powerAt, this.volumeAt});
  final bool? power;
  final AndroidTvVolumeInfo? volume;
  final DateTime? powerAt;
  final DateTime? volumeAt;
  String describe(DateTime now) {
    final parts = <String>[];
    if (power != null && powerAt != null) {
      parts.add('${_prefix(now, powerAt!)}TV ${power! ? 'on' : 'standby'}');
    }
    if (volume != null &&
        volumeAt != null &&
        volume!.max > 0 &&
        volume!.level >= 0 &&
        volume!.level <= volume!.max) {
      parts.add(
        '${_prefix(now, volumeAt!)}${volume!.muted ? 'Muted' : 'Volume ${volume!.level}/${volume!.max}'}',
      );
    }
    return parts.isEmpty
        ? 'TV power and volume not reported'
        : parts.join(' · ');
  }

  static String _prefix(DateTime now, DateTime at) =>
      now.difference(at) > const Duration(seconds: 30) ? 'Last report: ' : '';
}
