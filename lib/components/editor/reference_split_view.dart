import 'package:flutter/material.dart';

/// Keeps the notebook mounted while a read-only reference is opened or resized.
class ReferenceSplitView extends StatefulWidget {
  const ReferenceSplitView({
    super.key,
    required this.notebook,
    this.reference,
    required this.resizeLabel,
    this.onLayoutChanged,
  });

  final Widget notebook;
  final Widget? reference;
  final String resizeLabel;
  final VoidCallback? onLayoutChanged;

  @override
  State<ReferenceSplitView> createState() => _ReferenceSplitViewState();
}

class _ReferenceSplitViewState extends State<ReferenceSplitView> {
  double _fraction = .45;
  Size? _lastSize;

  void _resize(double fraction) {
    setState(() => _fraction = fraction.clamp(.25, .65));
  }

  Widget _pane(Widget child) => LayoutBuilder(
    builder: (context, bounds) {
      final size = bounds.biggest;
      if (_lastSize != size) {
        _lastSize = size;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onLayoutChanged?.call();
        });
      }
      return ClipRect(
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(size: size),
          child: child,
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final horizontal = bounds.maxWidth >= 700;
      final extent = horizontal ? bounds.maxWidth : bounds.maxHeight;
      final available = (extent - 24).clamp(0.0, double.infinity);
      final reference = widget.reference;
      return Flex(
        direction: horizontal ? Axis.horizontal : Axis.vertical,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.ltr,
        children: [
          if (reference != null) ...[
            SizedBox(
              key: const ValueKey('reference-pane'),
              width: horizontal ? available * _fraction : null,
              height: horizontal ? null : available * _fraction,
              child: ClipRect(child: reference),
            ),
            Semantics(
              label: widget.resizeLabel,
              value: '${(_fraction * 100).round()}%',
              increasedValue:
                  '${((_fraction + .05).clamp(.25, .65) * 100).round()}%',
              decreasedValue:
                  '${((_fraction - .05).clamp(.25, .65) * 100).round()}%',
              onIncrease: () => _resize(_fraction + .05),
              onDecrease: () => _resize(_fraction - .05),
              child: MouseRegion(
                cursor: horizontal
                    ? SystemMouseCursors.resizeColumn
                    : SystemMouseCursors.resizeRow,
                child: GestureDetector(
                  key: const ValueKey('reference-divider'),
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: horizontal
                      ? (event) {
                          if (available > 0)
                            _resize(_fraction + event.delta.dx / available);
                        }
                      : null,
                  onVerticalDragUpdate: horizontal
                      ? null
                      : (event) {
                          if (available > 0)
                            _resize(_fraction + event.delta.dy / available);
                        },
                  child: SizedBox(
                    width: horizontal ? 24 : null,
                    height: horizontal ? null : 24,
                    child: ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      child: Center(
                        child: Icon(
                          horizontal ? Icons.drag_indicator : Icons.more_horiz,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          Expanded(
            key: const ValueKey('notebook-pane'),
            child: _pane(widget.notebook),
          ),
        ],
      );
    },
  );
}
