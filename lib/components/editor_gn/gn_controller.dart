import 'package:flutter/widgets.dart';
import 'package:saber/data/tools/pen.dart';

/// The panels that open under the editor's top bar.
enum GnPanel { none, penSettings, color, stickers, export, more }

/// Which panel is open in the editor's top bar, and where each panel's
/// button is, so the panel can open right under it.
class GnController extends ChangeNotifier {
  GnPanel _panel = GnPanel.none;
  GnPanel get panel => _panel;

  /// Where the pen button sat before the shape pen was picked, so picking it
  /// again goes back to the pen that was in use.
  Pen? penBeforeShape;

  final Map<GnPanel, LayerLink> links = {
    for (final panel in GnPanel.values) panel: LayerLink(),
  };

  /// The bottom of the top bar, where the tool strip hangs from.
  final barLink = LayerLink();

  void toggle(GnPanel panel) {
    _panel = _panel == panel ? GnPanel.none : panel;
    notifyListeners();
  }

  void close() {
    if (_panel == GnPanel.none) return;
    _panel = GnPanel.none;
    notifyListeners();
  }
}
