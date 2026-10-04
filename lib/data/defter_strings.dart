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

  // PDF
  static String get pdfTools => _tr ? 'PDF: ara ve içindekiler' : 'PDF: search and contents';
  static String get pdfSearchHint => _tr ? 'PDF içinde ara' : 'Search in the PDF';
  static String get pdfNoText => _tr
      ? 'Bu PDF\'te aranabilir metin yok (taranmış olabilir)'
      : 'This PDF has no searchable text (it may be a scan)';
  static String get pdfNoOutline =>
      _tr ? 'Bu PDF\'te içindekiler listesi yok' : 'This PDF has no table of contents';
  static String get pdfContents => _tr ? 'İçindekiler' : 'Contents';
  static String get pdfSearch => _tr ? 'Ara' : 'Search';
  static String pdfPageLabel(int page) => _tr ? 'Sayfa $page' : 'Page $page';

  // Handwriting recognition
  static String get recognize => _tr ? 'Yazıyı metne çevir' : 'Convert handwriting to text';
  static String get recognizing => _tr ? 'Yazı okunuyor…' : 'Reading handwriting…';
  static String get recognizeNoKey => _tr
      ? 'Önce Ayarlar > El yazısı tanıma bölümünden OpenRouter anahtarını gir.'
      : 'First enter your OpenRouter key in Settings > Handwriting recognition.';
  static String get recognizeEmpty =>
      _tr ? 'Okunabilir bir yazı bulunamadı' : 'No readable handwriting found';
  static String get recognizeNoStrokes => _tr
      ? 'Seçimde kalemle yazılmış bir şey yok'
      : 'There is no pen writing in the selection';
  static String get recognizeNote => _tr
      ? 'Seçilen yazı görüntü olarak OpenRouter\'a gönderilir.'
      : 'The selected writing is sent to OpenRouter as a picture.';
  static String get copy => _tr ? 'Kopyala' : 'Copy';
  static String get copied => _tr ? 'Kopyalandı' : 'Copied';
  static String get close => _tr ? 'Kapat' : 'Close';
  static String get save => _tr ? 'Kaydet' : 'Save';
  static String get handwritingSettings =>
      _tr ? 'El yazısı tanıma' : 'Handwriting recognition';
  static String get handwritingSettingsSubtitle => _tr
      ? 'OpenRouter anahtarı ve model'
      : 'OpenRouter key and model';
  static String get apiKey => _tr ? 'OpenRouter API anahtarı' : 'OpenRouter API key';
  static String get modelName => _tr ? 'Model' : 'Model';
  static String get resetDefault => _tr ? 'Varsayılana dön' : 'Reset to default';

  // Ask my notes
  static String get askNotes => _tr ? 'Notlarıma sor' : 'Ask my notes';
  static String get askHint =>
      _tr ? 'Notlarında ne arıyorsun?' : 'What are you looking for in your notes?';
  static String get askNoNotes => _tr
      ? 'Notlarında bununla ilgili bir şey bulamadım'
      : 'I found nothing about this in your notes';
  static String get askSources => _tr ? 'Kullanılan notlar' : 'Notes used';
  static String get askTypedOnly => _tr
      ? 'Yalnızca yazıyla girilen metin taranır; el yazısını önce metne çevir.'
      : 'Only typed text is searched; convert handwriting to text first.';
  static String get askSending => _tr
      ? 'Sorunla ilgili not parçaları OpenRouter\'a gönderilir.'
      : 'Relevant note excerpts are sent to OpenRouter with your question.';
  static String get ask => _tr ? 'Sor' : 'Ask';

  // Links
  static String get linkToNote => _tr ? 'Nota bağlantı ekle' : 'Link to a note';

  // Audio
  static String get recordings => _tr ? 'Ses kayıtları' : 'Audio recordings';
  static String get startRecording => _tr ? 'Kayda başla' : 'Start recording';
  static String get stopRecording => _tr ? 'Kaydı bitir' : 'Stop recording';
  static String get noRecordings =>
      _tr ? 'Bu notta ses kaydı yok' : 'No recordings in this note';
  static String get micDenied => _tr
      ? 'Mikrofon izni verilmedi. Telefon ayarlarından izin ver.'
      : 'Microphone permission was not granted. Allow it in the device settings.';
  static String get recordingsNote => _tr
      ? 'Kayıtlar yalnızca bu cihazda saklanır, senkronize edilmez.'
      : 'Recordings stay on this device and are not synced.';
  static String get play => _tr ? 'Oynat' : 'Play';
  static String get pause => _tr ? 'Duraklat' : 'Pause';
  static String get delete => _tr ? 'Sil' : 'Delete';

  // Sync status
  static String get syncStatus => _tr ? 'Senkron durumu' : 'Sync status';
  static String get syncStatusSubtitle => _tr
      ? 'Bekleyen dosyalar ve son aktarım'
      : 'Waiting files and the last transfer';
  static String syncOn(String user) =>
      _tr ? 'Nextcloud\'a bağlı: $user' : 'Connected to Nextcloud: $user';
  static String get syncOff =>
      _tr ? 'Senkron kapalı (giriş yapılmadı)' : 'Sync is off (not logged in)';
  static String get syncWaitingDownloads =>
      _tr ? 'İndirilmeyi bekleyen' : 'Waiting to download';
  static String get syncWaitingUploads =>
      _tr ? 'Yüklenmeyi bekleyen' : 'Waiting to upload';
  static String get syncLastTransfer =>
      _tr ? 'Son aktarım (bu oturum)' : 'Last transfer (this session)';
  static String get syncNone => _tr ? 'henüz yok' : 'none yet';
  static String get syncNow => _tr ? 'Şimdi eşitle' : 'Sync now';
  static String get syncExplain => _tr
      ? 'Notlar çevrimdışı da çalışır; internet gelince bekleyenler kendiliğinden gönderilir.'
      : 'Notes work offline; waiting files are sent when the internet returns.';

  // Arrows
  static String get shapeArrows => _tr ? 'Çizgilere ok ucu' : 'Arrowheads on lines';
  static String get shapeArrowsSubtitle => _tr
      ? 'Şekil kalemiyle çizdiğin düz çizgilerin ucuna ok ekler'
      : 'Adds an arrowhead to straight lines drawn with the shape pen';

  static String get opacity => _tr ? 'Saydamlık' : 'Opacity';

  // Pen prediction
  static String get penPrediction => _tr ? 'Kalem tahmini' : 'Pen prediction';
  static String get pageSidebar =>
      _tr ? 'Sayfa paneli' : 'Page sidebar';

  // Shapes
  static String get holdToSnap =>
      _tr ? 'Bekleyince şekli düzelt' : 'Hold to snap shapes';
  static String get holdToSnapSubtitle => _tr
      ? 'Bir şekil çizip kalemi bekletince çizgi düzgün şekle dönüşür'
      : 'Draw a shape and hold the pen still to straighten it';
  static String get holdDelay =>
      _tr ? 'Düzeltme için bekleme' : 'Hold time to snap';
  static String get holdDelaySubtitle => _tr
      ? 'Kalemin kaç saniye durması gerektiği'
      : 'How long the pen has to stay still';
  static String get advancedShapes =>
      _tr ? 'Gelişmiş şekil tanıma' : 'Improved shape recognition';
  static String get advancedShapesSubtitle => _tr
      ? 'Çokgen, elips ve yay tanır; döndürülmüş dikdörtgeni korur'
      : 'Recognises polygons, ellipses and arcs, and keeps rotated rectangles';
  static String get snapEndpoints =>
      _tr ? 'Şekil uçlarına yapış' : 'Snap to shape ends';
  static String get snapEndpointsSubtitle => _tr
      ? 'Çizgi uçları ve köşeler yakındaki şekillerin uçlarına oturur'
      : 'Line ends and corners snap to nearby shapes';

  static String get penPredictionSubtitle => _tr
      ? 'Hızlı yazarken çizginin kalemin ucundan geri kalmasını azaltır'
      : 'Reduces the line trailing behind the pen tip when writing fast';
}
