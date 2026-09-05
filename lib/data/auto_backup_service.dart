import 'package:flutter/services.dart';

class AutoBackupService {
  static const _channel = MethodChannel('com.arctrack.arctrack/backup');

  Future<bool> get isEnabled async =>
      await _channel.invokeMethod<bool>('isEnabled') ?? false;

  Future<bool> chooseDestination(String json) async =>
      await _channel.invokeMethod<bool>('chooseDestination', {'json': json}) ??
      false;

  Future<bool> useExistingDestination(String json) async =>
      await _channel
          .invokeMethod<bool>('useExistingDestination', {'json': json}) ??
      false;

  Future<bool> write(String json) async =>
      await _channel.invokeMethod<bool>('write', {'json': json}) ?? false;

  Future<void> disable() => _channel.invokeMethod<void>('disable');
}
