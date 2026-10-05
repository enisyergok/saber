import 'package:flutter/material.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/pdf/pdf_crop.dart';

/// Lets the user cut the edges off an imported PDF page.
class PdfCropDialog extends StatefulWidget {
  const PdfCropDialog({
    super.key,
    required this.initial,
    required this.pageAspect,
    required this.onApply,
  });

  final PdfCrop initial;

  /// Width divided by height of the PDF page, for the preview.
  final double pageAspect;

  /// Called with the chosen crop and whether it is for all of the PDF's pages.
  final void Function(PdfCrop crop, bool allPages) onApply;

  @override
  State<PdfCropDialog> createState() => _PdfCropDialogState();
}

class _PdfCropDialogState extends State<PdfCropDialog> {
  late PdfCrop _crop = widget.initial;
  bool _allPages = false;

  Widget _slider(
    String label,
    double value,
    PdfCrop Function(double) update,
  ) {
    return Row(
      children: [
        SizedBox(width: 56, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(0, PdfCrop.max),
            max: PdfCrop.max,
            divisions: 40,
            label: '${(value * 100).round()}%',
            onChanged: (v) => _set(update(v)),
          ),
        ),
        SizedBox(width: 40, child: Text('${(value * 100).round()}%')),
      ],
    );
  }

  void _set(PdfCrop next) => setState(() => _crop = next.clamped());

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    final aspect = widget.pageAspect > 0 ? widget.pageAspect : 0.7;
    return AlertDialog(
      title: Text(DefterStrings.pdfCrop),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: SizedBox(
                  height: 120,
                  child: AspectRatio(
                    aspectRatio: aspect,
                    child: CustomPaint(
                      painter: _CropPreviewPainter(
                        crop: _crop,
                        outline: colors.outline,
                        kept: colors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _slider(DefterStrings.pdfCropLeft, _crop.left,
                  (v) => _crop.copyWith(left: v)),
              _slider(DefterStrings.pdfCropTop, _crop.top,
                  (v) => _crop.copyWith(top: v)),
              _slider(DefterStrings.pdfCropRight, _crop.right,
                  (v) => _crop.copyWith(right: v)),
              _slider(DefterStrings.pdfCropBottom, _crop.bottom,
                  (v) => _crop.copyWith(bottom: v)),
              Text(DefterStrings.pdfCropHint, style: TextTheme.of(context).bodySmall),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _allPages,
                title: Text(DefterStrings.pdfCropAllPages),
                onChanged: (v) => setState(() => _allPages = v ?? false),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(
          onPressed: () => _set(PdfCrop.none),
          child: Text(DefterStrings.pdfCropReset),
        ),
        FilledButton(
          onPressed: () {
            widget.onApply(_crop, _allPages);
            Navigator.pop(context);
          },
          child: Text(DefterStrings.pdfCropApply),
        ),
      ],
    );
  }
}

class _CropPreviewPainter extends CustomPainter {
  const _CropPreviewPainter({
    required this.crop,
    required this.outline,
    required this.kept,
  });

  final PdfCrop crop;
  final Color outline;
  final Color kept;

  @override
  void paint(Canvas canvas, Size size) {
    final page = Offset.zero & size;
    final region = Rect.fromLTRB(
      size.width * crop.left,
      size.height * crop.top,
      size.width * (1 - crop.right),
      size.height * (1 - crop.bottom),
    );
    canvas.drawRect(region, Paint()..color = kept.withValues(alpha: 0.25));
    canvas.drawRect(
      region,
      Paint()
        ..color = kept
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawRect(
      page,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_CropPreviewPainter old) =>
      old.crop != crop || old.outline != outline || old.kept != kept;
}
