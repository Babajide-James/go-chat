import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionChangeController =
      StreamController<bool>.broadcast();

  ConnectivityService() {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> result) {
      _connectionChangeController.add(_hasConnection(result));
    });
  }

  Stream<bool> get connectionChange => _connectionChangeController.stream;

  Future<bool> get isConnected async {
    final result = await _connectivity.checkConnectivity();
    return _hasConnection(result);
  }

  bool _hasConnection(List<ConnectivityResult> result) {
    if (result.contains(ConnectivityResult.none)) {
      return false;
    }
    return true;
  }

  void dispose() {
    _connectionChangeController.close();
  }
}
