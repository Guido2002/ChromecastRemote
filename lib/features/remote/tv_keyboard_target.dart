import '../../core/protocol/android_tv/text_input.dart';
import 'remote_controller.dart';

/// Keeps the composer tied to a single selected television and input field.
abstract interface class TvKeyboardTarget {
  String get deviceName;
  RemoteConnectionState get connectionState;
  Stream<RemoteConnectionState> get connectionStates;
  bool get textInputSupported;
  bool get textEnterSupported;
  AndroidTvTextSession? get textSession;
  Stream<AndroidTvTextSession?> get textSessions;
  bool sendText(String text, AndroidTvTextSession session);
  bool sendTextEnter(AndroidTvTextSession session);
}
