import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/tools/stylus_action.dart';

void main() {
  group('StylusKeys', () {
    test('Android stylus button key codes are recognised', () {
      for (var code = 308; code <= 311; code++) {
        expect(StylusKeys.isStylusKey(0x1100000000 | code), isTrue);
      }
    });

    test('other keys are not', () {
      expect(StylusKeys.isStylusKey(0x1100000000 | 307), isFalse);
      expect(StylusKeys.isStylusKey(0x1100000000 | 312), isFalse);
      // same low bits but not the Android plane
      expect(StylusKeys.isStylusKey(0x100000000 | 308), isFalse);
      expect(StylusKeys.isStylusKey(308), isFalse);
      // a normal letter key
      expect(StylusKeys.isStylusKey(0x61), isFalse);
    });
  });

  group('StylusTapCounter', () {
    test('every press counts when one tap is needed', () {
      final counter = StylusTapCounter();
      expect(counter.press(0, needed: 1), isTrue);
      expect(counter.press(5000, needed: 1), isTrue);
    });

    test('two quick presses make a double tap', () {
      final counter = StylusTapCounter();
      expect(counter.press(0, needed: 2), isFalse);
      expect(counter.press(200, needed: 2), isTrue);
    });

    test('slow presses do not', () {
      final counter = StylusTapCounter();
      expect(counter.press(0, needed: 2), isFalse);
      expect(counter.press(900, needed: 2), isFalse);
      // the second slow press started a new count
      expect(counter.press(1000, needed: 2), isTrue);
    });

    test('a third press starts over', () {
      final counter = StylusTapCounter();
      expect(counter.press(0, needed: 2), isFalse);
      expect(counter.press(100, needed: 2), isTrue);
      expect(counter.press(200, needed: 2), isFalse);
      expect(counter.press(300, needed: 2), isTrue);
    });

    test('reset forgets the first press', () {
      final counter = StylusTapCounter();
      expect(counter.press(0, needed: 2), isFalse);
      counter.reset();
      expect(counter.press(100, needed: 2), isFalse);
    });
  });

  group('StylusAction', () {
    test('index round trip', () {
      for (final action in StylusAction.values) {
        expect(StylusAction.fromIndex(action.index), action);
      }
    });

    test('bad stored values fall back to the eraser', () {
      expect(StylusAction.fromIndex(-1), StylusAction.toggleEraser);
      expect(StylusAction.fromIndex(99), StylusAction.toggleEraser);
    });

    test('the default stored value is the eraser', () {
      expect(StylusAction.toggleEraser.index, 1);
    });
  });
}
