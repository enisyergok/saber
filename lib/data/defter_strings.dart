import 'package:saber/i18n/strings.g.dart';

/// Strings added by Defter that aren't part of the slang translations.
///
/// The slang files under `lib/i18n` are generated; keeping Defter's additions
/// here avoids regenerating them for every new label. Turkish and English are
/// provided; other locales fall back to English.
abstract class DefterStrings {
  static bool get _tr => LocaleSettings.currentLocale.languageCode == 'tr';

  static String get pages => _tr ? 'Sayfalar' : 'Pages';
  static String get allPages => _tr ? 'Tümü' : 'All';
  static String get bookmarks => _tr ? 'Yer imleri' : 'Bookmarks';
  static String get bookmark => _tr ? 'Yer imi' : 'Bookmark';
  static String get noBookmarks => _tr
      ? 'Henüz yer imi eklenmiş sayfa yok'
      : 'No bookmarked pages yet';
  static String get editPages =>
      _tr ? 'Sayfaları düzenle ve sırala' : 'Edit and reorder pages';
  static String get thickness => _tr ? 'Kalınlık' : 'Thickness';
  static String get paper => _tr ? 'Kâğıt' : 'Paper';
  static String get nameOptional => _tr
      ? 'Boş bırakırsan tarihle adlandırılır'
      : 'Leave empty to name it by date';
}
