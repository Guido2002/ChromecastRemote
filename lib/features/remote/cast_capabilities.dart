import 'dart:async';
import 'package:flutter/services.dart';

class CastCapabilities {
  const CastCapabilities({
    required this.deviceId,
    required this.mediaSessionId,
    required this.seek,
    required this.pause,
  });
  final String deviceId;
  final int mediaSessionId;
  final bool seek;
  final bool pause;
  bool matches(String id, int? media) =>
      deviceId == id && mediaSessionId == media;
  static CastCapabilities? parse(Object? value) {
    if (value is! Map ||
        value['deviceId'] is! String ||
        value['mediaSessionId'] is! int ||
        value['seek'] is! bool ||
        value['pause'] is! bool) {
      return null;
    }
    return CastCapabilities(
      deviceId: value['deviceId'] as String,
      mediaSessionId: value['mediaSessionId'] as int,
      seek: value['seek'] as bool,
      pause: value['pause'] as bool,
    );
  }

  static const _channel = MethodChannel('chromecast_remote/cast_capabilities');
  static Future<CastCapabilities?> read() async {
    try {
      return parse(
        await _channel
            .invokeMethod<Object?>('read')
            .timeout(const Duration(seconds: 2)),
      );
    } on TimeoutException {
      return null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

/// A live range must be reported; duration alone never grants seek support.
class CastSeekWindow {
  const CastSeekWindow(this.start, this.end);
  final Duration start;
  final Duration end;
  Duration clamp(Duration position) => position < start
      ? start
      : position > end
      ? end
      : position;
  static CastSeekWindow? resolve({
    required bool seekSupported,
    required bool live,
    Duration? duration,
    Duration? liveStart,
    Duration? liveEnd,
  }) {
    if (!seekSupported) return null;
    if (live) {
      if (liveStart == null ||
          liveEnd == null ||
          liveStart < Duration.zero ||
          liveEnd <= liveStart) {
        return null;
      }
      return CastSeekWindow(liveStart, liveEnd);
    }
    return duration != null && duration > Duration.zero
        ? CastSeekWindow(Duration.zero, duration)
        : null;
  }
}
