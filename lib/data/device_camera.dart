import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A photo that was just taken.
typedef DevicePhoto = ({Uint8List bytes, String extension});

/// Why a photo could not be taken.
enum DeviceCameraFailure {
  /// The device has no camera app.
  noCamera,

  /// The camera is already open for another photo.
  busy,

  /// The camera app could not be opened, or the photo could not be read.
  failed,
}

class DeviceCameraException implements Exception {
  const new(this.failure, [this.detail]);

  final DeviceCameraFailure failure;
  final String? detail;

  @override
  String toString() =>
      'DeviceCameraException(${failure.name}${detail == null ? '' : ': $detail'})';
}

/// Takes photos with the camera app of the device.
///
/// The camera app does the work: the app itself needs (and asks for) no
/// permission to use the camera, and only gets the photo that was taken.
abstract class DeviceCamera {
  static const channel = MethodChannel('defter/camera');

  /// Set in tests to pretend the device has (or lacks) a camera.
  @visibleForTesting
  static bool? availableOverride;

  /// Whether photos can be taken on this kind of device.
  static bool get isAvailable => availableOverride ?? Platform.isAndroid;

  /// Opens the camera and completes with the photo that was taken, or with
  /// null if the camera was closed without taking one.
  static Future<DevicePhoto?> takePhoto() async {
    final String? path;
    try {
      path = await channel.invokeMethod<String>('takePhoto');
    } on PlatformException catch (e) {
      throw DeviceCameraException(switch (e.code) {
        'no_camera' => .noCamera,
        'busy' => .busy,
        _ => .failed,
      }, e.message);
    } on MissingPluginException catch (e) {
      throw DeviceCameraException(.noCamera, e.message);
    }
    if (path == null || path.isEmpty) return null;

    final file = File(path);
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      final extension = path.toLowerCase().endsWith('.png') ? '.png' : '.jpg';
      return (bytes: bytes, extension: extension);
    } on FileSystemException catch (e) {
      throw DeviceCameraException(.failed, '$e');
    } finally {
      // The photo is part of the note from here on.
      try {
        await file.delete();
      } catch (_) {
        // It is in the app's cache, which the system clears by itself.
      }
    }
  }
}
