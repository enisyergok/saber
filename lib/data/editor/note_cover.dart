import 'dart:ui' as ui;

import 'package:bson/bson.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show MemoryImage;
import 'package:image/image.dart' as im;
import 'package:logging/logging.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/data/covers/cover_designs.dart';
import 'package:saber/data/editor/editor_core_info.dart';

/// The cover of a notebook: what its card shows on the home screen.
///
/// It belongs to the note but is not one of its pages. Inside the note
/// there is only paper; the cover is on the outside.
///
/// A cover is either one of the app's own [design]s with a [title] on it,
/// which is drawn whenever it is needed, or (for notebooks made when the
/// cover was still their first page) a small [picture] of what that page
/// looked like.
class NoteCover {
  NoteCover({this.designId, this.title = '', this.picture});

  /// For a cover of one of [CoverDesigns]: which one.
  String? designId;

  /// What is written on the cover. Empty for a cover without a title.
  String title;

  /// For a cover that is not one of the app's designs: the cover itself,
  /// as an encoded image no wider than [width].
  Uint8List? picture;

  CoverDesign? get design => CoverDesigns.byId(designId);

  /// Whether there is anything to show. (A design this version does not
  /// know and no picture: the card shows the first page, as for a note
  /// without a cover.)
  bool get isUsable => design != null || picture != null;

  /// The width a cover is drawn or kept at, in pixels: enough for a card
  /// on any screen.
  static const width = 720.0;

  /// A card's proportions (width to height), which a cover fills exactly.
  static const aspectRatio = 0.74;

  static ui.Size get size => const ui.Size(width, width / aspectRatio);

  /// What tells two states of a cover apart, so that its picture is only
  /// made again when it has changed.
  String get signature => '$designId|$title|${picture?.length}';

  /// The cover as an encoded image for the note's card.
  Future<Uint8List?> render() async {
    final design = this.design;
    if (design != null) return design.renderPng(size, title: title);
    return picture;
  }

  Map<String, dynamic> toJson() => {
    if (designId != null) 'd': designId,
    if (title.isNotEmpty) 't': title,
    if (picture != null) 'i': BsonBinary.from(picture!),
  };

  static NoteCover? fromJson(Object? json) {
    if (json is! Map) return null;
    final picture = switch (json['i']) {
      (final Uint8List bytes) => bytes,
      (final BsonBinary binary) => binary.byteList,
      (final List<dynamic> bytes) => Uint8List.fromList(bytes.cast<int>()),
      _ => null,
    };
    final designId = json['d'];
    final title = json['t'];
    final cover = NoteCover(
      designId: designId is String ? designId : null,
      title: title is String ? title : '',
      picture: picture == null || picture.isEmpty ? null : picture,
    );
    // Nothing that could be shown, now or by a later version: no cover.
    return cover.designId == null && cover.picture == null ? null : cover;
  }

  static final _log = Logger('NoteCover');

  // -- notebooks whose cover is still their first page -----------------------

  /// Whether the first page of [info] is a cover as earlier versions made
  /// it, going by what can be seen without opening the picture: a page
  /// with nothing on it but a picture as its background, which is a PNG
  /// that is never inverted (pictures that are added are, unless that is
  /// turned off by hand), followed by at least one more page.
  static bool mayHaveCoverPage(EditorCoreInfo info) {
    if (info.readOnly || info.cover != null || info.pages.length < 2) {
      return false;
    }
    final page = info.pages.first;
    final image = page.backgroundImage;
    return image is PngEditorImage &&
        !image.invertible &&
        image.extension == '.png' &&
        page.strokes.isEmpty &&
        page.images.isEmpty &&
        page.quill.controller.document.isEmpty();
  }

  /// Takes the cover of a notebook that still has it as its first page
  /// out of the pages and makes it the notebook's [EditorCoreInfo.cover].
  /// Returns whether it did.
  ///
  /// The page has to be a cover beyond doubt: besides what
  /// [mayHaveCoverPage] asks, its picture must be exactly as many pixels
  /// as the page is wide and high. Covers were drawn that way; a
  /// photograph or a scan never happens to be. Anything else is left as
  /// the page it is.
  static Future<bool> adoptCoverPage(EditorCoreInfo info) async {
    if (!mayHaveCoverPage(info)) return false;
    final page = info.pages.first;
    final image = page.backgroundImage! as PngEditorImage;
    try {
      final bytes = await _bytesOf(image);
      if (bytes == null) return false;

      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final Uint8List picture;
      try {
        if (descriptor.width != page.size.width.round() ||
            descriptor.height != page.size.height.round()) {
          return false;
        }
        picture = await _shrink(descriptor);
      } finally {
        descriptor.dispose();
        buffer.dispose();
      }

      info.cover = NoteCover(picture: picture);
      info.pages.removeAt(0).dispose();
      for (var i = 0; i < info.pages.length; i++) {
        info.pages[i].updatePageIndex(i);
      }
      final opensAt = info.initialPageIndex;
      if (opensAt != null && opensAt > 0) info.initialPageIndex = opensAt - 1;
      return true;
    } on Object catch (e, st) {
      // The notebook stays as it is, cover page and all.
      _log.warning('Could not take the cover out of the pages: $e', e, st);
      return false;
    }
  }

  static Future<Uint8List?> _bytesOf(PngEditorImage image) async {
    final file = image.assetFile;
    if (file != null) return file.existsSync() ? file.readAsBytes() : null;
    return switch (image.imageProvider) {
      (final MemoryImage memory) => memory.bytes,
      _ => null,
    };
  }

  /// The picture of [descriptor] at [width], as a JPEG (a cover is a
  /// picture to look at on a card: a few dozen kilobytes are enough, and
  /// they are saved with the note every time).
  static Future<Uint8List> _shrink(ui.ImageDescriptor descriptor) async {
    final targetWidth = descriptor.width > width
        ? width.round()
        : descriptor.width;
    final codec = await descriptor.instantiateCodec(targetWidth: targetWidth);
    final frame = await codec.getNextFrame();
    try {
      final rgba = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final small = im.Image.fromBytes(
        width: frame.image.width,
        height: frame.image.height,
        bytes: rgba!.buffer,
        order: im.ChannelOrder.rgba,
        numChannels: 4,
      );
      return await compute(_encodeJpeg, small);
    } finally {
      frame.image.dispose();
      codec.dispose();
    }
  }

  static Uint8List _encodeJpeg(im.Image image) =>
      im.encodeJpg(image, quality: 88);
}
