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
  static String get notebookName => _tr ? 'Defter adı' : 'Notebook name';
  static String get paper => _tr ? 'Kâğıt' : 'Paper';
  static String get nameOptional => _tr
      ? 'Boş bırakırsan tarihle adlandırılır'
      : 'Leave empty to name it by date';

  static String get benchmark => _tr ? 'Performans ölçümü' : 'Benchmark';
  static String get benchmarkSubtitle => _tr
      ? 'Kalem ve kayıt hızını bu cihazda ölçer'
      : 'Measures pen and save speed on this device';
  static String get benchmarkStart => _tr ? 'Ölçümü başlat' : 'Start';
  static String get benchmarkRunning =>
      _tr ? 'Ölçülüyor, ekrana dokunma' : 'Measuring, please don\'t touch';
  static String get benchmarkCopy => _tr ? 'Sonuçları kopyala' : 'Copy results';
  static String get benchmarkCopied =>
      _tr ? 'Sonuçlar panoya kopyalandı' : 'Results copied to clipboard';
  static String get benchmarkIntro => _tr
      ? 'Örnek notlar üretip yazma sırasındaki kare sürelerini, çizgi '
            'hesabını ve kayıt/açılış sürelerini ölçer. Yaklaşık bir dakika '
            'sürer; notlarına dokunmaz.'
      : 'Generates sample notes and measures frame times while writing, '
            'stroke outline cost, and save/open times. Takes about a minute; '
            'your notes are not touched.';

  // Trash
  static String get trash => _tr ? 'Çöp kutusu' : 'Trash';
  static String get trashSubtitle => _tr
      ? 'Silinen notları geri al veya kalıcı olarak sil'
      : 'Restore deleted notes or remove them for good';
  static String get trashEmpty =>
      _tr ? 'Çöp kutusu boş' : 'The trash is empty';
  static String get restore => _tr ? 'Geri al' : 'Restore';
  static String get deleteForever =>
      _tr ? 'Kalıcı olarak sil' : 'Delete forever';
  static String get emptyTrash => _tr ? 'Çöpü boşalt' : 'Empty trash';
  static String get emptyTrashConfirm => _tr
      ? 'Çöp kutusundaki tüm notlar kalıcı olarak silinecek.'
      : 'Every note in the trash will be deleted for good.';
  static String get cancel => _tr ? 'Vazgeç' : 'Cancel';

  // Favourites
  static String get favorites => _tr ? 'Favoriler' : 'Favorites';
  static String get addToFavorites =>
      _tr ? 'Favorilere ekle' : 'Add to favorites';
  static String get removeFromFavorites =>
      _tr ? 'Favorilerden çıkar' : 'Remove from favorites';
  static String get noFavorites => _tr
      ? 'Henüz favori not yok. Bir notu seçip yıldıza dokun.'
      : 'No favorites yet. Select a note and tap the star.';

  // Search
  static String get search => _tr ? 'Ara' : 'Search';
  static String get searchHint =>
      _tr ? 'Not adı veya içerik ara' : 'Search note names and text';
  static String get searchNoResults =>
      _tr ? 'Sonuç bulunamadı' : 'No results';
  static String get searchIndexing =>
      _tr ? 'Notlar taranıyor…' : 'Indexing notes…';

  // Tools
  static String get eraserSize => _tr ? 'Silgi boyutu' : 'Eraser size';
}
