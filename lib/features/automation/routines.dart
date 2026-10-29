import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/storage/secure_store.dart';
import '../apps/app_launcher.dart';
import '../apps/tv_app.dart';
import '../remote/remote_controller.dart';

class HomeAssistantConfig {
  HomeAssistantConfig(String url, String value)
    : base = _parse(url),
      token = value.trim() {
    if (token.isEmpty || RegExp(r'\s').hasMatch(token)) {
      throw const FormatException('Enter a valid access token.');
    }
  }
  final Uri base;
  final String token;
  static Uri _parse(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !['http', 'https'].contains(uri.scheme)) {
      throw const FormatException(
        'Use your Home Assistant server URL without credentials or query parameters.',
      );
    }
    final ip = InternetAddress.tryParse(uri.host);
    final local =
        uri.host == 'localhost' ||
        uri.host.endsWith('.local') ||
        (ip != null &&
            (ip.isLoopback ||
                (ip.type == InternetAddressType.IPv4 &&
                    (ip.rawAddress[0] == 10 ||
                        (ip.rawAddress[0] == 192 && ip.rawAddress[1] == 168) ||
                        (ip.rawAddress[0] == 172 &&
                            ip.rawAddress[1] >= 16 &&
                            ip.rawAddress[1] <= 31)))));
    if (uri.scheme == 'http' && !local) {
      throw const FormatException(
        'Use HTTPS for a remote server. HTTP is allowed only for local addresses.',
      );
    }
    return uri.replace(
      path: uri.path.endsWith('/') ? uri.path : '${uri.path}/',
    );
  }
}

class TvAudioRoutine {
  const TvAudioRoutine({
    required this.id,
    required this.name,
    required this.tvId,
    required this.appId,
    required this.entity,
    required this.volume,
  });
  final String id, name, tvId, appId, entity;
  final double volume;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tv': tvId,
    'app': appId,
    'entity': entity,
    'volume': volume,
  };
  factory TvAudioRoutine.fromJson(Map<String, dynamic> value) {
    final routine = TvAudioRoutine(
      id: value['id'] as String,
      name: value['name'] as String,
      tvId: value['tv'] as String,
      appId: value['app'] as String,
      entity: value['entity'] as String,
      volume: (value['volume'] as num).toDouble(),
    );
    if (routine.name.trim().isEmpty ||
        !RegExp(r'^media_player\.[a-z0-9_]+$').hasMatch(routine.entity) ||
        !routine.volume.isFinite ||
        routine.volume < 0 ||
        routine.volume > 1) {
      throw const FormatException('Invalid routine.');
    }
    return routine;
  }
}

class RoutineStore {
  RoutineStore(this.storage);
  final SecureStore storage;
  Future<HomeAssistantConfig?> loadConfig() async {
    final raw = await storage.read('home_assistant_connection_v1');
    try {
      final value = raw == null ? null : jsonDecode(raw);
      if (value is Map && value['url'] is String && value['token'] is String) {
        return HomeAssistantConfig(
          value['url'] as String,
          value['token'] as String,
        );
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  Future<void> saveConfig(HomeAssistantConfig config) => storage.write(
    'home_assistant_connection_v1',
    jsonEncode({'url': config.base.toString(), 'token': config.token}),
  );
  Future<void> clearConfig() => storage.delete('home_assistant_connection_v1');
  Future<List<TvAudioRoutine>> load() async {
    final raw = await storage.read('tv_audio_routines_v1');
    final result = <TvAudioRoutine>[];
    try {
      final value = raw == null ? null : jsonDecode(raw);
      if (value is List) {
        for (final item in value.whereType<Map<String, dynamic>>()) {
          try {
            result.add(TvAudioRoutine.fromJson(item));
          } on FormatException {
            /* Skip invalid entries. */
          } on TypeError {
            /* Skip invalid entries. */
          }
        }
      }
    } on FormatException {
      return [];
    }
    return result;
  }

  Future<void> save(TvAudioRoutine routine) async {
    final all = await load()
      ..removeWhere((item) => item.id == routine.id);
    all.add(TvAudioRoutine.fromJson(routine.toJson()));
    await storage.write(
      'tv_audio_routines_v1',
      jsonEncode(all.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> remove(String id) async {
    final all = await load()
      ..removeWhere((item) => item.id == id);
    await storage.write(
      'tv_audio_routines_v1',
      jsonEncode(all.map((item) => item.toJson()).toList()),
    );
  }
}

class RoutineCancellation {
  bool cancelled = false;
  final _callbacks = <void Function()>{};
  void cancel() {
    cancelled = true;
    for (final callback in _callbacks.toList()) {
      callback();
    }
  }

  void check() {
    if (cancelled) throw const RoutineFailure('Cancelled.');
  }
}

class RoutineFailure implements Exception {
  const RoutineFailure(this.message);
  final String message;
}

class HomeAssistantClient {
  HomeAssistantClient(this.config, {this.timeout = const Duration(seconds: 5)});
  final HomeAssistantConfig config;
  final Duration timeout;
  Future<Object?> _request(
    String path,
    RoutineCancellation cancel, {
    Map<String, dynamic>? body,
  }) async {
    cancel.check();
    final client = HttpClient();
    void abort() => client.close(force: true);
    cancel._callbacks.add(abort);
    try {
      return await (() async {
        final request = await client.openUrl(
          body == null ? 'GET' : 'POST',
          config.base.resolve(path),
        );
        request.followRedirects = false;
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${config.token}',
        );
        request.headers.contentType = ContentType.json;
        if (body != null) request.write(jsonEncode(body));
        final response = await request.close();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw const RoutineFailure(
            'Home Assistant refused the request. Check the connection, token, and entity.',
          );
        }
        final bytes = <int>[];
        await for (final chunk in response) {
          bytes.addAll(chunk);
          if (bytes.length > 65536) {
            throw const RoutineFailure(
              'Home Assistant response was too large.',
            );
          }
        }
        cancel.check();
        return bytes.isEmpty ? null : jsonDecode(utf8.decode(bytes));
      })().timeout(timeout);
    } on RoutineFailure {
      rethrow;
    } catch (_) {
      cancel.check();
      throw const RoutineFailure(
        'Could not reach Home Assistant. Check the server and try again.',
      );
    } finally {
      cancel._callbacks.remove(abort);
      client.close(force: true);
    }
  }

  Future<void> testConnection() async {
    await _request('api/', RoutineCancellation());
  }

  Future<Map> state(String entity, RoutineCancellation cancel) async {
    if (!RegExp(r'^media_player\.[a-z0-9_]+$').hasMatch(entity)) {
      throw const RoutineFailure('Choose a media_player entity.');
    }
    final value = await _request(
      'api/states/${Uri.encodeComponent(entity)}',
      cancel,
    );
    if (value is! Map ||
        value['state'] == 'unavailable' ||
        value['state'] == 'unknown' ||
        value['attributes'] is! Map) {
      throw const RoutineFailure('The selected audio entity is unavailable.');
    }
    return value;
  }

  Future<void> setVolume(
    String entity,
    double volume,
    RoutineCancellation cancel,
  ) async {
    if (!RegExp(r'^media_player\.[a-z0-9_]+$').hasMatch(entity) ||
        !volume.isFinite ||
        volume < 0 ||
        volume > 1) {
      throw const RoutineFailure('Invalid audio preset.');
    }
    await _request(
      'api/services/media_player/volume_set',
      cancel,
      body: {'entity_id': entity, 'volume_level': volume},
    );
  }
}

enum RoutineOutcome { completed, unconfirmed, partial, cancelled, failed }

class RoutineResult {
  const RoutineResult(this.outcome, this.message);
  final RoutineOutcome outcome;
  final String message;
}

Future<RoutineResult> runTvAudioRoutine({
  required TvAudioRoutine routine,
  required TvApp app,
  required HomeAssistantClient audio,
  required AppLaunchTarget tv,
  required String tvId,
  required bool Function() isCurrentTarget,
  required RoutineCancellation cancellation,
  Duration pollInterval = const Duration(milliseconds: 250),
  Duration launchTimeout = const Duration(seconds: 4),
}) async {
  var requestedAudio = false;
  void check() {
    cancellation.check();
    if (tvId != routine.tvId ||
        app.id != routine.appId ||
        !isCurrentTarget() ||
        tv.connectionState != RemoteConnectionState.connected ||
        !tv.capabilities.contains(RemoteCapability.appLaunch)) {
      throw const RoutineFailure('TV selection or connection changed.');
    }
  }

  try {
    check();
    final current = await audio.state(routine.entity, cancellation);
    final features = (current['attributes'] as Map)['supported_features'];
    if (features is! num || features.toInt() & 4 == 0) {
      throw const RoutineFailure(
        'This audio entity does not report volume control support.',
      );
    }
    check();
    requestedAudio = true;
    await audio.setVolume(routine.entity, routine.volume, cancellation);
    var confirmed = false;
    for (var attempt = 0; attempt < 4; attempt++) {
      check();
      final state = await audio.state(routine.entity, cancellation);
      final reported = (state['attributes'] as Map)['volume_level'];
      if (reported is num && (reported - routine.volume).abs() <= 0.02) {
        confirmed = true;
        break;
      }
      if (attempt < 3) await Future<void>.delayed(pollInterval);
    }
    if (!confirmed) {
      return const RoutineResult(
        RoutineOutcome.partial,
        'Audio was requested but not confirmed. The TV app was not opened.',
      );
    }
    check();
    final launch = await launchTvApp(
      tv,
      app,
      confirmationTimeout: launchTimeout,
      isCurrentTarget: () => !cancellation.cancelled && isCurrentTarget(),
    );
    if (launch == AppLaunchOutcome.confirmed) {
      return const RoutineResult(
        RoutineOutcome.completed,
        'Audio preset confirmed and TV app is active.',
      );
    }
    if (launch == AppLaunchOutcome.unconfirmed) {
      return const RoutineResult(
        RoutineOutcome.unconfirmed,
        'Audio preset confirmed. TV app launch was requested but not confirmed.',
      );
    }
    return const RoutineResult(
      RoutineOutcome.partial,
      'Audio preset was applied, but TV app launch did not complete.',
    );
  } on RoutineFailure catch (error) {
    return RoutineResult(
      cancellation.cancelled
          ? RoutineOutcome.cancelled
          : requestedAudio
          ? RoutineOutcome.partial
          : RoutineOutcome.failed,
      '${error.message}${requestedAudio ? ' Audio volume may already have changed.' : ''}',
    );
  }
}
