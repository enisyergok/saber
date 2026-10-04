import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/nextcloud/sync_status.dart';

void main() {
  test('how long ago is told in plain words', () {
    final now = DateTime(2026, 10, 4, 12);
    String ago(Duration d, {bool tr = true}) =>
        SyncStatus.ago(now.subtract(d), now, turkish: tr);
    expect(ago(const Duration(seconds: 10)), 'az önce');
    expect(ago(const Duration(minutes: 5)), '5 dk önce');
    expect(ago(const Duration(hours: 3)), '3 sa önce');
    expect(ago(const Duration(days: 4)), '4 gün önce');
    expect(ago(const Duration(minutes: 5), tr: false), '5 min ago');
  });
}
