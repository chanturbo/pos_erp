// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/app_config.dart';
import '../config/app_mode.dart';

class DiscoveredMaster {
  final String name;
  final String host;
  final int port;
  final DateTime lastSeen;

  const DiscoveredMaster({
    required this.name,
    required this.host,
    required this.port,
    required this.lastSeen,
  });

  DiscoveredMaster copyWith({
    String? name,
    String? host,
    int? port,
    DateTime? lastSeen,
  }) {
    return DiscoveredMaster(
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}

class MasterDiscoveryService {
  MasterDiscoveryService._();

  static final MasterDiscoveryService instance = MasterDiscoveryService._();

  static const int discoveryPort = 45454;
  static const Duration _broadcastInterval = Duration(seconds: 2);
  static const Duration _staleAfter = Duration(seconds: 8);

  RawDatagramSocket? _listener;
  RawDatagramSocket? _broadcaster;
  Timer? _broadcastTimer;
  Timer? _pruneTimer;
  final Map<String, DiscoveredMaster> _masters = {};
  final StreamController<List<DiscoveredMaster>> _streamController =
      StreamController<List<DiscoveredMaster>>.broadcast();

  Stream<List<DiscoveredMaster>> get stream => _streamController.stream;

  List<DiscoveredMaster> get masters {
    final items = _masters.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  Future<void> start() async {
    if (AppModeConfig.isStandalone) {
      _broadcastTimer?.cancel();
      _broadcastTimer = null;
      _pruneTimer?.cancel();
      _pruneTimer = null;
      _listener?.close();
      _listener = null;
      _broadcaster?.close();
      _broadcaster = null;
      _masters.clear();
      _push();
      return;
    }

    await _ensureListener();
    await _refreshBroadcastState();
    _push();
  }

  Future<void> refresh() async {
    await start();
  }

  Future<void> stop() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _pruneTimer?.cancel();
    _pruneTimer = null;
    _listener?.close();
    _listener = null;
    _broadcaster?.close();
    _broadcaster = null;
    _masters.clear();
    _push();
  }

  Future<void> _ensureListener() async {
    if (_listener != null) return;

    try {
      _listener = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
        reusePort: true,
      );
      _listener!.broadcastEnabled = true;
      _listener!.listen(_onSocketEvent);

      _pruneTimer ??= Timer.periodic(
        const Duration(seconds: 3),
        (_) => _pruneStale(),
      );
    } catch (e) {
      print('❌ MasterDiscovery listener error: $e');
    }
  }

  Future<void> _refreshBroadcastState() async {
    if (AppModeConfig.isMaster) {
      await _ensureBroadcaster();
      _broadcastTimer ??= Timer.periodic(
        _broadcastInterval,
        (_) => _broadcastPresence(),
      );
      await _broadcastPresence();
      return;
    }

    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _broadcaster?.close();
    _broadcaster = null;
  }

  Future<void> _ensureBroadcaster() async {
    if (_broadcaster != null) return;

    try {
      _broadcaster = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
        reusePort: true,
      );
      _broadcaster!.broadcastEnabled = true;
    } catch (e) {
      print('❌ MasterDiscovery broadcaster error: $e');
    }
  }

  Future<void> _broadcastPresence() async {
    final socket = _broadcaster;
    if (socket == null || !AppModeConfig.isMaster) return;

    try {
      final host = await AppConfig.getLocalIP();
      final payload = jsonEncode({
        'type': 'master_announce',
        'name': AppModeConfig.deviceName,
        'host': host,
        'port': AppConfig.defaultServerPort,
        'timestamp': DateTime.now().toIso8601String(),
      });

      socket.send(
        utf8.encode(payload),
        InternetAddress('255.255.255.255'),
        discoveryPort,
      );
    } catch (e) {
      print('❌ MasterDiscovery broadcast error: $e');
    }
  }

  void _onSocketEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;

    final socket = _listener;
    final dg = socket?.receive();
    if (dg == null) return;

    try {
      final payload = utf8.decode(dg.data);
      final map = jsonDecode(payload) as Map<String, dynamic>;
      if (map['type'] != 'master_announce') return;

      final host = (map['host'] as String?)?.trim().isNotEmpty == true
          ? map['host'] as String
          : dg.address.address;
      final name = (map['name'] as String?)?.trim().isNotEmpty == true
          ? map['name'] as String
          : host;
      final port = map['port'] as int? ?? AppConfig.defaultServerPort;
      final key = '$host:$port';

      _masters[key] = DiscoveredMaster(
        name: name,
        host: host,
        port: port,
        lastSeen: DateTime.now(),
      );
      _push();
    } catch (_) {
      // ignore malformed packets from other devices on the LAN
    }
  }

  void _pruneStale() {
    final now = DateTime.now();
    final staleKeys = _masters.entries
        .where((entry) => now.difference(entry.value.lastSeen) > _staleAfter)
        .map((entry) => entry.key)
        .toList();

    if (staleKeys.isEmpty) return;
    for (final key in staleKeys) {
      _masters.remove(key);
    }
    _push();
  }

  void _push() {
    if (_streamController.isClosed) return;
    _streamController.add(masters);
  }
}
