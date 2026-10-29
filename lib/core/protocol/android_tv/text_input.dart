import 'dart:async';

import 'proto/remotemessage.pb.dart';

/// Opaque permission to address one TV-reported input session. A replacement
/// token invalidates every outstanding composer without retaining field text.
class AndroidTvTextSession {
  const AndroidTvTextSession._(this.imeCounter, this.fieldCounter);
  final int imeCounter;
  final int fieldCounter;
}

/// Tracks only input routing metadata. TV field values are deliberately ignored.
class AndroidTvTextInput {
  static const maxCodePoints = 2000;
  final _changes = StreamController<AndroidTvTextSession?>.broadcast();
  AndroidTvTextSession? _session;
  String? _app;

  AndroidTvTextSession? get session => _session;
  Stream<AndroidTvTextSession?> get changes => _changes.stream;

  void updateCounters(int imeCounter, int fieldCounter) {
    if (_session?.imeCounter == imeCounter &&
        _session?.fieldCounter == fieldCounter) {
      return;
    }
    _session = AndroidTvTextSession._(imeCounter, fieldCounter);
    _changes.add(_session);
  }

  void updateApp(String? package) {
    if (package == _app) return;
    _app = package;
    _invalidate();
  }

  void reset() {
    _app = null;
    _invalidate();
  }

  void _invalidate() {
    if (_session == null) return;
    _session = null;
    _changes.add(null);
  }

  bool accepts(AndroidTvTextSession token) => identical(token, _session);

  RemoteMessage? createRequest(String text, AndroidTvTextSession token) {
    if (!accepts(token) || text.isEmpty || text.contains('\u0000')) return null;
    final length = text.runes.length;
    if (length > maxCodePoints) return null;
    // The reference sender uses Unicode code points minus one for both offsets.
    // This is a discrete text request, not a mirrored editor or cursor sync.
    return RemoteMessage()
      ..remoteImeBatchEdit = RemoteImeBatchEdit(
        imeCounter: token.imeCounter,
        fieldCounter: token.fieldCounter,
        editInfo: [
          RemoteEditInfo(
            insert: 1,
            textFieldStatus: RemoteImeObject(
              start: length - 1,
              end: length - 1,
              value: text,
            ),
          ),
        ],
      );
  }

  Future<void> dispose() => _changes.close();
}
