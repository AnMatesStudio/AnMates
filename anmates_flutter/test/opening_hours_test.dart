import 'package:flutter_test/flutter_test.dart';
import 'package:anmates/utils/opening_hours.dart';

void main() {
  // 2026-06-08 is a Monday, 2026-06-13 a Saturday — used as deterministic clocks.
  DateTime mon(int h, [int m = 0]) => DateTime(2026, 6, 8, h, m);
  DateTime sat(int h, [int m = 0]) => DateTime(2026, 6, 13, h, m);

  group('parseOpeningHours', () {
    test('24/7 is always open', () {
      expect(parseOpeningHours('24/7', now: mon(3)).state, OpenNow.open);
    });

    test('simple all-week range — open inside, closed outside', () {
      final open = parseOpeningHours('Mo-Su 08:00-22:00', now: mon(12));
      expect(open.state, OpenNow.open);
      expect(open.label, contains('22:00'));

      expect(parseOpeningHours('Mo-Su 08:00-22:00', now: mon(23)).state, OpenNow.closed);
    });

    test('multiple day-rules pick the right one for the weekday', () {
      const spec = 'Mo-Fr 09:00-21:00; Sa-Su 10:00-22:00';
      final beforeOpen = parseOpeningHours(spec, now: sat(9));
      expect(beforeOpen.state, OpenNow.closed);
      expect(beforeOpen.label, contains('10:00'));
      expect(parseOpeningHours(spec, now: sat(11)).state, OpenNow.open);
    });

    test('split shifts — closed during the mid-afternoon gap', () {
      const spec = '10:00-14:00,17:00-22:00';
      expect(parseOpeningHours(spec, now: mon(12)).state, OpenNow.open);
      final gap = parseOpeningHours(spec, now: mon(15));
      expect(gap.state, OpenNow.closed);
      expect(gap.label, contains('17:00'));
    });

    test('overnight range stays open after midnight', () {
      expect(parseOpeningHours('Mo-Su 18:00-02:00', now: mon(1)).state, OpenNow.open);
    });

    test('bare time range applies to every day', () {
      expect(parseOpeningHours('08:00-22:00', now: sat(12)).state, OpenNow.open);
    });

    test('unparseable or empty → unknown', () {
      expect(parseOpeningHours(null).state, OpenNow.unknown);
      expect(parseOpeningHours('').state, OpenNow.unknown);
      expect(parseOpeningHours('lúc nào cũng mở cửa nhé').state, OpenNow.unknown);
    });
  });
}
