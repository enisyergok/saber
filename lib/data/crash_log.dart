import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Notes kept on the device to find out why the app closed: the last
/// uncaught Android error, notes written before risky steps, and what
/// Android recorded about how the app's last runs ended. Nothing is sent
/// anywhere.
abstract class CrashLog {
  static const _channel = MethodChannel('defter/crash');

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Writes [text] to the notes (before a step that might close the app).
  static Future<void> mark(String text) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('mark', {'text': text});
    } catch (_) {
      // notes are best-effort
    }
  }

  /// Everything kept, as text; empty when there is nothing.
  static Future<String> read() async {
    if (!_supported) return '';
    try {
      return await _channel.invokeMethod<String>('read') ?? '';
    } catch (e) {
      return '$e';
    }
  }

  static Future<void> clear() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('clear');
    } catch (_) {}
  }
}
