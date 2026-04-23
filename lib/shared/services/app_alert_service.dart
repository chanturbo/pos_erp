import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appAlertServiceProvider = Provider<AppAlertService>((ref) {
  final service = AppAlertService();
  ref.onDispose(service.dispose);
  return service;
});

class AppAlertService {
  AppAlertService({AudioPlayer? player, bool enableAudio = true})
    : _player = enableAudio ? (player ?? AudioPlayer()) : null {
    _player?.setReleaseMode(ReleaseMode.stop);
  }

  static const String takeawayNewOrderAsset = 'audio/takeaway_new_order.wav';
  static const String kitchenNewTicketAsset = 'audio/kitchen_new_ticket.wav';

  final AudioPlayer? _player;

  Future<void> playTakeawayNewOrderAlert() async {
    await _playAssetOrFallback(
      assetPath: takeawayNewOrderAsset,
      macOsFallback: '/System/Library/Sounds/Ping.aiff',
      linuxFallback: '/usr/share/sounds/freedesktop/stereo/bell.oga',
    );
  }

  Future<void> playKitchenAlert() async {
    await _playAssetOrFallback(
      assetPath: kitchenNewTicketAsset,
      macOsFallback: '/System/Library/Sounds/Ping.aiff',
      linuxFallback: '/usr/share/sounds/freedesktop/stereo/bell.oga',
    );
  }

  Future<void> _playAssetOrFallback({
    required String assetPath,
    required String macOsFallback,
    required String linuxFallback,
  }) async {
    try {
      if (_player != null) {
        await _player.stop();
        await _player.play(AssetSource(assetPath));
        return;
      }
    } catch (_) {
      await _playPlatformFallback(
        macOsFallback: macOsFallback,
        linuxFallback: linuxFallback,
      );
      return;
    }

    await _playPlatformFallback(
      macOsFallback: macOsFallback,
      linuxFallback: linuxFallback,
    );
  }

  Future<void> _playPlatformFallback({
    required String macOsFallback,
    required String linuxFallback,
  }) async {
    if (Platform.isMacOS) {
      await Process.run('afplay', [macOsFallback]);
      return;
    }
    if (Platform.isLinux) {
      try {
        await Process.run('paplay', [linuxFallback]);
      } catch (_) {
        await Process.run('beep', []);
      }
      return;
    }
    if (Platform.isWindows) {
      await Process.run('PowerShell', [
        '-Command',
        '[console]::beep(880,250); Start-Sleep -Milliseconds 80; [console]::beep(880,250)',
      ]);
      return;
    }
    await SystemSound.play(SystemSoundType.alert);
  }

  Future<void> dispose() async {
    await _player?.dispose();
  }
}
