import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/storage/secure_store.dart';

/// Local button feedback, never an acknowledgement from the television.
class RemoteHaptics extends ChangeNotifier {
  RemoteHaptics(this.storage);
  static RemoteHaptics instance = RemoteHaptics(const FlutterSecureStore());
  final SecureStore storage;
  bool enabled = true;
  bool _touched = false;
  Future<void> load() async {
    try {
      final value = await storage.read('remote_haptics_v1');
      if (!_touched && value != null) {
        enabled = value != 'off';
        notifyListeners();
      }
    } catch (_) {
      /* Keep the default when storage is unavailable. */
    }
  }

  Future<void> setEnabled(bool value) async {
    _touched = true;
    final previous = enabled;
    enabled = value;
    notifyListeners();
    try {
      await storage.write('remote_haptics_v1', value ? 'on' : 'off');
    } catch (_) {
      enabled = previous;
      notifyListeners();
      rethrow;
    }
    if (value) await press();
  }

  Future<void> press({bool selection = false}) async {
    if (!enabled) return;
    try {
      if (selection) {
        await HapticFeedback.selectionClick();
      } else {
        await HapticFeedback.lightImpact();
      }
    } on PlatformException {
      /* Vibration is optional. */
    } on MissingPluginException {
      /* No haptic motor on this platform. */
    }
  }
}
