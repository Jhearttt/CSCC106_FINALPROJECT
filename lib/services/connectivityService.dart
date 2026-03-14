import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Singleton that monitors network connectivity.
/// Usage:
///   ConnectivityService.instance.isOnline       // current status (bool)
///   ConnectivityService.instance.onStatusChange // stream of bool
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller =
  StreamController<bool>.broadcast();

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  Stream<bool> get onStatusChange => _controller.stream;

  StreamSubscription? _subscription;

  /// Call once from main() via SyncService.instance.init().
  Future<void> init() async {
    // checkConnectivity() returns List<ConnectivityResult> in v5+
    // and ConnectivityResult in v4 and below.
    // We use dynamic to handle both safely.
    final dynamic result = await _connectivity.checkConnectivity();
    _isOnline = _isConnectedDynamic(result);

    _subscription = _connectivity.onConnectivityChanged.listen((dynamic result) {
      final online = _isConnectedDynamic(result);
      if (online != _isOnline) {
        _isOnline = online;
        _controller.add(_isOnline);
      }
    });
  }

  bool _isConnectedDynamic(dynamic result) {
    if (result is List) {
      // v5+: returns List<ConnectivityResult>
      return result.any((r) =>
      r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet);
    } else if (result is ConnectivityResult) {
      // v4 and below: returns single ConnectivityResult
      return result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet;
    }
    return false;
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}