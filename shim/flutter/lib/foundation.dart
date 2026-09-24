// Pure Dart foundation shim to run PlayTorrio scrapers without Flutter SDK.
// This replaces flutter/foundation.dart in headless server mode.
library foundation;

import 'dart:async';
import 'dart:isolate';

export 'dart:typed_data';
export 'dart:async';

const bool kDebugMode = false;
const bool kReleaseMode = true;
const bool kProfileMode = false;
const bool kIsWeb = false;

typedef VoidCallback = void Function();
typedef ComputeCallback<Q, R> = FutureOr<R> Function(Q message);

/// Runs [callback] in a real Dart isolate via [Isolate.run], matching Flutter's
/// compute() semantics. This keeps the server event loop unblocked during
/// heavy crypto (AES, HKDF, PoW solving used by several scrapers).
Future<R> compute<Q, R>(ComputeCallback<Q, R> callback, Q message, {String? debugLabel}) {
  return Isolate.run(() => callback(message));
}

void debugPrint(String? message, {int? wrapWidth}) {
  if (kDebugMode && message != null) {
    print(message);
  }
}

abstract class Listenable {
  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
}

class ChangeNotifier implements Listenable {
  final List<VoidCallback> _listeners = [];

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void notifyListeners() {
    for (final listener in List<VoidCallback>.from(_listeners)) {
      try {
        listener();
      } catch (_) {}
    }
  }

  void dispose() {
    _listeners.clear();
  }
}

class ValueNotifier<T> extends ChangeNotifier {
  T _value;
  ValueNotifier(this._value);

  T get value => _value;
  set value(T newValue) {
    if (_value == newValue) return;
    _value = newValue;
    notifyListeners();
  }
}
