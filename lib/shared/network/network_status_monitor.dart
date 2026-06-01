import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

class NetworkStatusMonitor with WidgetsBindingObserver {
  NetworkStatusMonitor({
    this.checkInterval = const Duration(seconds: 8),
    this.timeout = const Duration(seconds: 3),
    List<Uri>? validationUrls,
    List<String>? fallbackHosts,
  }) : validationUrls =
           validationUrls ??
           [
             // Same intent as Android NET_CAPABILITY_VALIDATED: prove that
             // the connection reaches the internet, not only a local network.
             _googleGenerate204,
             _interrapidisimoHost,
           ],
       fallbackHosts =
           fallbackHosts ?? const ['www.google.com', 'interrapidisimo.com'];

  static final _googleGenerate204 = Uri.parse(
    'https://www.google.com/generate_204',
  );
  static final _interrapidisimoHost = Uri.parse(
    'https://www.interrapidisimo.com/',
  );

  final Duration checkInterval;
  final Duration timeout;
  final List<Uri> validationUrls;
  final List<String> fallbackHosts;

  final _statusController = StreamController<bool>.broadcast();
  Timer? _timer;
  bool? _lastStatus;
  bool _checking = false;

  Stream<bool> get status => _statusController.stream;
  bool? get currentStatus => _lastStatus;

  void start({bool? initialStatus}) {
    if (_timer != null) return;
    WidgetsBinding.instance.addObserver(this);
    if (initialStatus != null) _emit(initialStatus);
    _timer = Timer.periodic(checkInterval, (_) => unawaited(checkNow()));
    unawaited(Future<void>.delayed(const Duration(seconds: 1), checkNow));
  }

  Future<bool> checkNow() async {
    if (_checking) return _lastStatus ?? false;
    _checking = true;
    try {
      final connected = await hasInternetAccess();
      _emit(connected);
      return connected;
    } finally {
      _checking = false;
    }
  }

  Future<bool> hasInternetAccess() async {
    for (final url in validationUrls) {
      if (await _canReachUrl(url)) return true;
    }

    for (final host in fallbackHosts) {
      if (await _canResolveHost(host)) return true;
    }

    return false;
  }

  Future<bool> _canReachUrl(Uri url) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(url).timeout(timeout);
      request.followRedirects = false;
      final response = await request.close().timeout(timeout);
      await response.drain<void>().timeout(timeout);
      return response.statusCode >= 200 && response.statusCode < 400;
    } on Object {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _canResolveHost(String host) async {
    try {
      final addresses = await InternetAddress.lookup(host).timeout(timeout);
      return addresses.any((address) => address.rawAddress.isNotEmpty);
    } on Object {
      return false;
    }
  }

  void _emit(bool connected) {
    if (_lastStatus == connected) return;
    _lastStatus = connected;
    if (!_statusController.isClosed) {
      _statusController.add(connected);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(checkNow());
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
    unawaited(_statusController.close());
  }
}
