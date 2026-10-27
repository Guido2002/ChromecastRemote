/// Android KeyEvent key codes used by the Android TV Remote Protocol v2.
///
/// Values from
/// https://android.googlesource.com/platform/frameworks/native/+/master/include/android/keycodes.h
abstract final class AndroidKeyCodes {
  static const int home = 3;
  static const int back = 4;
  static const int dpadUp = 19;
  static const int dpadDown = 20;
  static const int dpadLeft = 21;
  static const int dpadRight = 22;
  static const int dpadCenter = 23;
  static const int volumeUp = 24;
  static const int volumeDown = 25;
  static const int power = 26;
  static const int search = 84;
  static const int mediaPlayPause = 85;
  static const int mediaStop = 86;
  static const int mediaNext = 87;
  static const int mediaPrevious = 88;
  static const int mediaRewind = 89;
  static const int mediaFastForward = 90;
  static const int mediaPlay = 126;
  static const int mediaPause = 127;
  static const int mute = 164;
}

/// Feature flags exchanged in the RemoteConfigure handshake (code1).
///
/// Values from https://github.com/tronikos/androidtvremote2 remote.py.
abstract final class AndroidTvFeatures {
  static const int ping = 1;
  static const int key = 2;
  static const int ime = 4;
  static const int voice = 8;
  static const int power = 32;
  static const int volume = 64;
  static const int appLink = 512;

  /// Features this app requests: keys, power, volume, current-app tracking
  /// (via IME messages) and app links. Voice is not implemented.
  static const int requested = ping | key | ime | power | volume | appLink;
}
