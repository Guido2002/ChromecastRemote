import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/storage/secure_store.dart';

class TvPreferences {
  const TvPreferences({
    this.room = '',
    this.eyesUp = false,
    this.power = true,
    this.volume = true,
  });
  final String room;
  final bool eyesUp;
  final bool power;
  final bool volume;
  Map<String, dynamic> toJson() => {
    'room': room,
    'eyesUp': eyesUp,
    'power': power,
    'volume': volume,
  };
  factory TvPreferences.fromJson(Map<String, dynamic> value) => TvPreferences(
    room: value['room'] is String ? (value['room'] as String).trim() : '',
    eyesUp: value['eyesUp'] == true,
    power: value['power'] != false,
    volume: value['volume'] != false,
  );
}

class TvPreferenceStore extends ChangeNotifier {
  TvPreferenceStore(this.storage);
  final SecureStore storage;
  final Map<String, TvPreferences> _cache = {};
  TvPreferences cached(String id) => _cache[id] ?? const TvPreferences();
  Future<TvPreferences> load(String id) async {
    final raw = await storage.read('tv_controls_v1:${Uri.encodeComponent(id)}');
    var value = const TvPreferences();
    try {
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          value = TvPreferences.fromJson(decoded);
        }
      }
    } on FormatException {
      /* Defaults retain access to all controls. */
    }
    _cache[id] = value;
    return value;
  }

  Future<void> save(String id, TvPreferences value) async {
    await storage.write(
      'tv_controls_v1:${Uri.encodeComponent(id)}',
      jsonEncode(value.toJson()),
    );
    _cache[id] = value;
    notifyListeners();
  }
}
