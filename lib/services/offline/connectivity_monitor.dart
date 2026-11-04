import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

abstract class ConnectivityMonitor {
  bool get isOnline;
  Stream<bool> get changes;
  void dispose();
}

/// Usa `navigator.onLine` no navegador, via connectivity_plus.
class PlatformConnectivityMonitor implements ConnectivityMonitor {
  PlatformConnectivityMonitor() {
    final connectivity = Connectivity();
    connectivity.checkConnectivity().then(_update);
    _subscription = connectivity.onConnectivityChanged.listen(_update);
  }

  final _controller = StreamController<bool>.broadcast();
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _online = true;

  void _update(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online == _online) return;
    _online = online;
    _controller.add(online);
  }

  @override
  bool get isOnline => _online;

  @override
  Stream<bool> get changes => _controller.stream;

  @override
  void dispose() {
    _subscription.cancel();
    _controller.close();
  }
}

class ManualConnectivity implements ConnectivityMonitor {
  ManualConnectivity({bool online = true}) : _online = online;

  final _controller = StreamController<bool>.broadcast();
  bool _online;

  void set(bool online) {
    if (online == _online) return;
    _online = online;
    _controller.add(online);
  }

  @override
  bool get isOnline => _online;

  @override
  Stream<bool> get changes => _controller.stream;

  @override
  void dispose() => _controller.close();
}
