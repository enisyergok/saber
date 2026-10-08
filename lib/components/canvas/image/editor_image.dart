import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:fast_image_resizer/fast_image_resizer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:saber/components/canvas/_asset_cache.dart';
import 'package:saber/components/canvas/canvas_image.dart';
import 'package:saber/components/canvas/invert_widget.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/pdf/pdf_crop.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:sbn/change.dart';

part 'png_editor_image.dart';
part 'pdf_editor_image.dart';
part 'svg_editor_image.dart';

/// The data for an image in the editor.
/// This is listenable for changes to the image's position ([dstRect]).
sealed class EditorImage extends ChangeNotifier {
  /// id for this image, unique within a note
  int id;

  /// The image's file extension, e.g. [".jpg"].
  /// This is used when "downloading" the image to the user's photo gallery.
  final String extension;

  final AssetCache assetCache;

  var _isThumbnail = false;
  bool get isThumbnail => _isThumbnail;
  @mustCallSuper
  set isThumbnail(bool isThumbnail) {
    _isThumbnail = isThumbnail;
  }

  int pageIndex;
  void Function(EditorImage, Rect)? onMoveImage;
  void Function(EditorImage)? onDeleteImage;
  void Function()? onMiscChange;
  final VoidCallback? onLoad;

  Rect srcRect = .zero;

  late var _dstRect = Rect.fromLTWH(
    0,
    0,
    CanvasImage.minImageSize,
    CanvasImage.minImageSize,
  );
  Rect get dstRect => _dstRect;
  set dstRect(Rect dstRect) {
    _dstRect = dstRect;
    if (_dstRect.width < CanvasImage.minImageSize ||
        _dstRect.height < CanvasImage.minImageSize) {
      final scale = max(
        CanvasImage.minImageSize / _dstRect.width,
        CanvasImage.minImageSize / _dstRect.height,
      );
      _dstRect = .fromLTWH(
        _dstRect.left,
        _dstRect.top,
        _dstRect.width * scale,
        _dstRect.height * scale,
      );
    }
    notifyListeners();
  }

  /// Defines the aspect ratio of the image.
  Size naturalSize;

  /// The size of the page this image is on,
  /// used to make sure the image isn't too big.
  Size? pageSize;

  /// If the image is new, it will be [active] (draggable) when loaded
  var newImage = false;

  /// Whether this image is inverted if Prefs.editorAutoInvert.value
  bool invertible;

  /// The BoxFit used if this is a page's background image
  BoxFit backgroundFit;

  @protected
  new({
    required this.id,
    required this.assetCache,
    required this.extension,
    required this.pageIndex,
    required this.pageSize,
    this.naturalSize = .zero,
    this.invertible = true,
    this.backgroundFit = .contain,
    required this.onMoveImage,
    required this.onDeleteImage,
    required this.onMiscChange,
    this.onLoad,
    this.newImage = true,
    this._dstRect = .zero,
    this.srcRect = .zero,
    this._isThumbnail = false,
  }) : assert(extension.startsWith('.'));

  factory fromJson(
    Map<String, dynamic> json, {
    required List<Uint8List>? inlineAssets,
    bool isThumbnail = false,
    required String sbnPath,
    required AssetCache assetCache,
  }) {
    final extension = json['e'] as String?;
    final EditorImage image;
    if (extension == '.svg') {
      image = SvgEditorImage.fromJson(
        json,
        inlineAssets: inlineAssets,
        isThumbnail: isThumbnail,
        sbnPath: sbnPath,
        assetCache: assetCache,
      );
    } else if (extension == '.pdf') {
      image = PdfEditorImage.fromJson(
        json,
        inlineAssets: inlineAssets,
        isThumbnail: isThumbnail,
        sbnPath: sbnPath,
        assetCache: assetCache,
      );
    } else {
      image = PngEditorImage.fromJson(
        json,
        inlineAssets: inlineAssets,
        isThumbnail: isThumbnail,
        sbnPath: sbnPath,
        assetCache: assetCache,
      );
    }
    final turns = json['r'];
    if (turns is int) image._quarterTurns = turns % 4;
    final cutLeft = json['kl'], cutTop = json['kt'];
    final cutRight = json['kr'], cutBottom = json['kb'];
    if (cutLeft is num &&
        cutTop is num &&
        cutRight is num &&
        cutBottom is num) {
      final saved = Rect.fromLTRB(
        cutLeft.toDouble(),
        cutTop.toDouble(),
        cutRight.toDouble(),
        cutBottom.toDouble(),
      );
      if (isValidCut(saved)) image._cut = saved;
    }
    return image;
  }

  @mustBeOverridden
  @mustCallSuper
  Map<String, dynamic> toJson(OrderedAssetCache assets) => {
    'id': id,
    'e': extension,
    'i': pageIndex,
    'v': invertible,
    'f': backgroundFit.index,
    'x': dstRect.left,
    'y': dstRect.top,
    'w': dstRect.width,
    'h': dstRect.height,
    if (srcRect.left != 0) 'sx': srcRect.left,
    if (srcRect.top != 0) 'sy': srcRect.top,
    if (srcRect.width != 0) 'sw': srcRect.width,
    if (srcRect.height != 0) 'sh': srcRect.height,
    if (naturalSize.width != 0) 'nw': naturalSize.width,
    if (naturalSize.height != 0) 'nh': naturalSize.height,
    if (quarterTurns != 0) 'r': quarterTurns,
    if (isCut) ...{
      'kl': cutout.left,
      'kt': cutout.top,
      'kr': cutout.right,
      'kb': cutout.bottom,
    },
  };

  /// The whole picture.
  static const wholePicture = Rect.fromLTRB(0, 0, 1, 1);

  /// The least of the picture a crop may leave, as a fraction of each side.
  static const minCut = 0.05;

  /// Whether [cutout] is a part of the picture that can be shown: inside it,
  /// and not a sliver.
  static bool isValidCut(Rect crop) =>
      crop.left >= 0 &&
      crop.top >= 0 &&
      crop.right <= 1 &&
      crop.bottom <= 1 &&
      crop.width >= minCut - 1e-9 &&
      crop.height >= minCut - 1e-9;

  /// The part of the picture that is shown, as fractions of the picture's
  /// own (unturned) width and height. [dstRect] is the box of just that
  /// part: cutting a picture shows the same ink in the same place and
  /// leaves the rest out.
  Rect get cutout => _cut;
  Rect _cut = wholePicture;
  set cutout(Rect cutout) {
    if (cutout == _cut) return;
    _cut = cutout;
    notifyListeners();
  }

  bool get isCut => _cut != wholePicture;

  /// What [cutout] was before the cuts that the history has not been told
  /// about yet.
  Rect? _unreportedCutFrom;

  bool get hasUnreportedCut =>
      _unreportedCutFrom != null && _unreportedCutFrom != _cut;

  /// Cuts the picture down to [next] (fractions of the whole picture, in
  /// its own unturned frame; see [cutout]). The picture stays where it is:
  /// the part that is left keeps its place and its scale on the page, and
  /// the box shrinks (or grows, if a cut is being undone) to fit it.
  void cutTo(Rect next) {
    if (!isValidCut(next) || next == _cut) return;
    final old = _cut;
    final turns = _quarterTurns;
    // The box in the picture's own frame (not turned).
    final width = turns.isOdd ? dstRect.height : dstRect.width;
    final height = turns.isOdd ? dstRect.width : dstRect.height;
    // The size the whole picture would have at this scale.
    final wholeWidth = width / old.width;
    final wholeHeight = height / old.height;
    final x0 = (next.left - old.left) * wholeWidth;
    final y0 = (next.top - old.top) * wholeHeight;
    final x1 = (next.right - old.left) * wholeWidth;
    final y1 = (next.bottom - old.top) * wholeHeight;
    // The same points once the picture is turned.
    Offset turned(double x, double y) => switch (turns) {
      1 => Offset(height - y, x),
      2 => Offset(width - x, height - y),
      3 => Offset(y, width - x),
      _ => Offset(x, y),
    };
    final part = Rect.fromPoints(turned(x0, y0), turned(x1, y1));

    _unreportedCutFrom ??= old;
    _cut = next;
    // Also tells who listens.
    dstRect = part.shift(dstRect.topLeft);
  }

  /// The cuts made with [cutTo] since this was last asked, for the
  /// history item of the change that is being recorded.
  Change<Rect>? takeUnreportedCut() {
    final from = _unreportedCutFrom;
    _unreportedCutFrom = null;
    if (from == null || from == _cut) return null;
    return Change(previous: from, current: _cut);
  }

  /// How many quarter turns clockwise the picture is shown turned (0 to
  /// 3). [dstRect] is the box of the picture as it is shown, turned.
  int get quarterTurns => _quarterTurns;
  int _quarterTurns = 0;
  set quarterTurns(int turns) {
    final normal = turns % 4;
    if (normal == _quarterTurns) return;
    _quarterTurns = normal;
    notifyListeners();
  }

  /// Quarter turns made with [rotateQuarter] that the history has not
  /// been told about yet.
  int _unreportedTurns = 0;

  /// Turns the picture [turns] quarter turns clockwise about its middle.
  /// For an odd number of turns its box becomes as wide as it was high.
  void rotateQuarter([int turns = 1]) {
    if (turns % 4 == 0) return;
    _quarterTurns = (_quarterTurns + turns) % 4;
    _unreportedTurns += turns;
    if (turns.isOdd) {
      // Also tells who listens.
      dstRect = Rect.fromCenter(
        center: dstRect.center,
        width: dstRect.height,
        height: dstRect.width,
      );
    } else {
      notifyListeners();
    }
  }

  /// The quarter turns made since this was last asked, for the history
  /// item of the change that is being recorded.
  int takeUnreportedTurns() {
    final turns = _unreportedTurns;
    _unreportedTurns = 0;
    return turns;
  }

  /// The file on disk this picture is read from, or null if it is held in
  /// memory (a picture that was just added).
  File? get assetFile => null;

  /// Called when this picture's content has been put in [file] (the note
  /// was saved, or its files were moved): from now on it is read from
  /// there. A picture that is held in memory stays as it is.
  void assetSavedTo(File file) {}

  /// Images are loaded out after 5 seconds of not being visible.
  ///
  /// Set this to true to load out immediately.
  ///
  /// This is useful for tests that can't have pending timers.
  @visibleForTesting
  static var shouldLoadOutImmediately = false;

  Completer? _firstLoadCompleter;
  Completer<bool>? _shouldLoadOut;
  var _loadedIn = false;
  bool get loadedIn => _loadedIn;

  Future<void> firstLoad();

  /// Called when the image becomes visible,
  /// and often involves loading the image from disk.
  ///
  /// The [firstLoad] method is called the first time this is called.
  /// Subsequent calls will wait for the first load to complete.
  ///
  /// See also:
  /// * [loadOut], which unloads the image from memory
  /// * [precache], which adds the image to Flutter's image cache
  /// * [loadedIn], which is true after [loadIn] and false after [loadOut]
  @mustBeOverridden
  @mustCallSuper
  Future<void> loadIn() async {
    if (_shouldLoadOut?.isCompleted == false) _shouldLoadOut?.complete(false);

    if (_firstLoadCompleter == null) {
      _firstLoadCompleter = Completer();
      firstLoad().then(
        _firstLoadCompleter!.complete,
        onError: _firstLoadCompleter!.completeError,
      );
    } else if (!_firstLoadCompleter!.isCompleted) {
      await _firstLoadCompleter!.future;
    }

    _loadedIn = true;
  }

  /// Free up resources when the image is no longer visible.
  ///
  /// See also:
  /// * [loadIn], which will be called again when the image is visible again.
  /// * [loadedIn], which is true after [loadIn] and false after [loadOut]
  @mustBeOverridden
  @mustCallSuper
  Future<bool> loadOut() async {
    if (_shouldLoadOut == null) {
      _shouldLoadOut = Completer();
      if (shouldLoadOutImmediately) {
        _shouldLoadOut!.complete(true);
      } else {
        Future.delayed(const Duration(seconds: 5)).then((_) {
          // load out if [loadIn] isn't called again in 5 seconds
          if (_shouldLoadOut == null) return;
          if (_shouldLoadOut!.isCompleted) return;
          _shouldLoadOut!.complete(true);
        });
      }
    }

    final shouldLoadOut = await _shouldLoadOut!.future;
    _shouldLoadOut = null;
    if (shouldLoadOut) {
      _loadedIn = false;
    }
    return shouldLoadOut;
  }

  /// Adds the image to Flutter's image cache.
  Future<void> precache(BuildContext context);

  Widget buildImageWidget({
    required BuildContext context,
    required BoxFit? overrideBoxFit,
    required bool isBackground,
    required bool invert,
  });

  EditorImage copy();

  /// Resizes [before] to fit inside [max] while maintaining aspect ratio
  @visibleForTesting
  static Size resize(Size before, Size max) {
    double width = before.width,
        height = before.height,
        aspectRatio = width / height;

    if (width > max.width) {
      width = max.width;
      height = width / aspectRatio;
    }
    if (height > max.height) {
      height = max.height;
      width = height * aspectRatio;
    }

    return Size(width, height);
  }
}
