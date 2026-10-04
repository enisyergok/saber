import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/toolbar/quick_style_bar.dart';

void main() {
  test('opacity cycles through the presets and wraps', () {
    expect(QuickStyleBar.nextOpacity(1), 0.6);
    expect(QuickStyleBar.nextOpacity(0.6), 0.3);
    expect(QuickStyleBar.nextOpacity(0.3), 1);
  });

  test('an odd opacity goes back to opaque', () {
    expect(QuickStyleBar.nextOpacity(0.8), 1);
  });

  test('values close to a preset count as that preset', () {
    expect(QuickStyleBar.nextOpacity(0.59), 0.3);
    expect(QuickStyleBar.nextOpacity(0.996), 0.6);
  });
}
