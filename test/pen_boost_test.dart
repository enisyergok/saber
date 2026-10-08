import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/tools/pen_boost.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('without a system that answers, the boost stays off and harmless', () async {
    await PenBoost.start();
    expect(PenBoost.isOn, isFalse);
    await PenBoost.stop();
    expect(PenBoost.isOn, isFalse);
  });
}
