import 'package:saber/i18n/strings.g.dart';

/// Strings added by Defter that aren't part of the slang translations.
///
/// The slang files under `lib/i18n` are generated; keeping Defter's additions
/// here avoids regenerating them for every new label. Turkish and English are
/// provided; other locales fall back to English.
abstract class DefterStrings {
  static bool get _tr => LocaleSettings.currentLocale.languageCode == 'tr';
  static bool get isTr => _tr;

  static String get fountainPenName => _tr ? 'Dolma Kalem' : 'Fountain Pen';
  static String get ballpointPenName =>
      _tr ? 'Tükenmez Kalem' : 'Ballpoint Pen';
  // -- pen settings panel --------------------------------------------------
  static String get penSettingsTitle => _tr ? 'Kalem Ayarları' : 'Pen Settings';
  static String get calligraphyPen => _tr ? 'Kaligrafi Kalemi' : 'Calligraphy Pen';
  static String get styleFountain => _tr ? 'Dolma Kalem' : 'Fountain';
  static String get styleBallpoint => _tr ? 'Tükenmez' : 'Ballpoint';
  static String get styleBrush => _tr ? 'Fırça' : 'Brush';
  static String get stylePencil => _tr ? 'Kurşun Kalem' : 'Pencil';
  static String get styleMarker => _tr ? 'Marker' : 'Marker';
  static String get styleCalligraphy => _tr ? 'Kaligrafi' : 'Calligraphy';
  static String get preview => _tr ? 'Önizleme' : 'Preview';
  static String get basicSettings => _tr ? 'Temel Ayarlar' : 'Basic Settings';
  static String get reset => _tr ? 'Sıfırla' : 'Reset';
  static String get opacityLabel => _tr ? 'Opaklık' : 'Opacity';
  static String get tipSharpnessLabel => _tr ? 'Uç Keskinliği' : 'Tip Sharpness';
  static String get pressureSensitivityLabel =>
      _tr ? 'Basınç Duyarlılığı' : 'Pressure Sensitivity';
  static String get lineStabilizationLabel =>
      _tr ? 'Çizgi Stabilizasyonu' : 'Line Stabilization';
  static String get pressureCurve => _tr ? 'Basınç Eğrisi' : 'Pressure Curve';
  static String get pressureLight => _tr ? 'Hafif Basınç' : 'Light Pressure';
  static String get pressureMedium => _tr ? 'Orta Basınç' : 'Medium Pressure';
  static String get pressureFirm => _tr ? 'Sert Basınç' : 'Firm Pressure';
  static String get colorAndStyle => _tr ? 'Renk ve Stil' : 'Color and Style';
  static String get moreColors => _tr ? 'Diğer renkler' : 'More colors';
  static String get colorPicker => _tr ? 'Renk seçici' : 'Color picker';
  static String get engineeringTools =>
      _tr ? 'Mühendislik ve Teknik Araçlar' : 'Engineering and Technical Tools';
  static String get toolStraightLine => _tr ? 'Düz Çizgi' : 'Straight Line';
  static String get toolStraightLineHint => _tr ? 'Otomatik' : 'Automatic';
  static String get toolShapes => _tr ? 'Şekil Tanıma' : 'Shape Recognition';
  static String get toolShapesHint =>
      _tr ? '(Daire, Kare, Üçgen)' : '(Circle, Square, Triangle)';
  static String get toolAngle => _tr ? 'Açı Kılavuzu' : 'Angle Guide';
  static String get toolAngleHint => '(15° 30° 45° 90°)';
  static String get toolRuler => _tr ? 'Cetvel' : 'Ruler';
  static String get toolGrid => _tr ? 'Izgara' : 'Grid';
  static String get toolMeasure => _tr ? 'Ölçüm' : 'Measure';
  static String get toolDimension =>
      _tr ? 'Ok & Ölçülendirme' : 'Arrows & Dimensions';
  static String get advancedBehaviours =>
      _tr ? 'Gelişmiş Davranışlar' : 'Advanced Behaviours';
  static String get shapeAutoCorrect =>
      _tr ? 'Şekli otomatik düzeltme' : 'Tidy shapes automatically';
  static String get joinShapes => _tr ? 'Birleştirme' : 'Join';
  static String get penProfiles =>
      _tr ? 'Hazır Kalem Profilleri' : 'Pen Profiles';
  static String get addProfile => _tr ? 'Profil ekle' : 'Add profile';
  static String get profileName => _tr ? 'Profil adı' : 'Profile name';
  static String get profileUpdate =>
      _tr ? 'Şimdiki ayarlarla güncelle' : 'Update with current settings';
  static String get profileRename => _tr ? 'Yeniden adlandır' : 'Rename';
  static String get profileDelete => _tr ? 'Sil' : 'Delete';
  static String get profilesRestore =>
      _tr ? 'Hazır profilleri geri yükle' : 'Restore the built-in profiles';
  static String get resetPen =>
      _tr ? 'Bu kalemi sıfırla' : 'Reset this pen';
  static String get cancelWord => _tr ? 'Vazgeç' : 'Cancel';
  static String get myProfile => _tr ? 'Profilim' : 'My profile';
  static String get customProfileHint => _tr ? 'Kendi ayarım' : 'My own settings';
  static String get profileNotes => _tr ? 'Not Alma' : 'Note Taking';
  static String get profileNotesHint =>
      _tr ? 'Günlük kullanım için' : 'For everyday use';
  static String get profileHeading => _tr ? 'Başlık' : 'Heading';
  static String get profileHeadingHint =>
      _tr ? 'Kalın ve belirgin' : 'Thick and clear';
  static String get profileSketch => _tr ? 'Çizim' : 'Sketching';
  static String get profileSketchHint =>
      _tr ? 'Yumuşak ve akıcı' : 'Soft and flowing';
  static String get profileTechnical => _tr ? 'Teknik Çizim' : 'Technical Drawing';
  static String get profileTechnicalHint =>
      _tr ? 'Hassas ve stabil' : 'Precise and steady';
  static String get profileEngineering => _tr ? 'Mühendislik' : 'Engineering';
  static String get profileEngineeringHint =>
      _tr ? 'Düzgün ve net' : 'Clean and crisp';
  static String get profileMarker => _tr ? 'Marker' : 'Marker';
  static String get profileMarkerHint =>
      _tr ? 'Vurgulama için' : 'For highlighting';

  static String get brushPen => _tr ? 'Fırça Uçlu Kalem' : 'Brush Pen';
  static String get penGestures => _tr ? 'Kalem hareketleri' : 'Pen gestures';

  static String get pressureAuto =>
      _tr ? 'Basıncı otomatik ayarla' : 'Adjust pressure automatically';
  static String get pressureAutoHint => _tr
      ? 'Kalemin basınç aralığı dar ise çizgi yine de kalınlaşıp incelir; basınç hiç değişmiyorsa hıza göre'
      : 'Lines still thicken and thin if the pen\'s pressure range is narrow; by speed if it never changes';

  static String get coverTitle => _tr ? 'Kapak ekle' : 'Add cover';
  static String get coverAdded => _tr ? 'Kapak eklendi' : 'Cover added';

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

  // -- screen refresh rate ---------------------------------------------------
  static String get rateTitle => _tr ? 'Ekran hızı (Hz)' : 'Screen rate (Hz)';
  static String get rateSubtitle => _tr
      ? 'Defter bu ekranda saniyede kaç kare çiziliyor, ölçer'
      : 'Measures how many frames a second the app is drawn at';
  static String get rateIntro => _tr
      ? 'Yüksek ekran hızı (90/120/144 Hz) kalemin çizgiyi daha yakından izlemesini sağlar. Aşağıdaki son sayı tahmin değil: Defter\'in şu anda çizdiği karelerden ölçülür.'
      : 'A fast screen (90/120/144 Hz) lets the line follow the pen more closely. The last number below is not a guess: it is measured from the frames the app is drawing right now.';
  static String get rateMax =>
      _tr ? 'Ekranın en yüksek hızı' : 'Fastest rate of the screen';
  static String get rateGiven =>
      _tr ? 'Sistemin uygulamaya verdiği' : 'What the system gives the app';
  static String get rateMeasured =>
      _tr ? 'Şu an ölçülen çizim hızı' : 'Drawing rate measured now';
  static String rateFrames(String value) =>
      _tr ? '$value kare/sn' : '$value frames/s';
  static String rateFull(String max) => _tr
      ? 'Defter ekranın en yüksek hızında ($max) çiziliyor.'
      : 'The app is drawn at the screen\'s fastest rate ($max).';
  static String rateNoFasterMode(String max) => _tr
      ? 'Cihaz şu an bu ekran için en fazla $max bildiriyor. Tabletiniz daha yüksek bir hızı (90/120 Hz) destekliyorsa, bu ekran ayarında yüksek hızın kapalı olduğunu gösterir: aşağıdaki adımları uygulayın. Desteklemiyorsa daha hızlı çizim bu cihazda mümkün değildir.'
      : 'The device reports at most $max for this screen right now. If your tablet supports a faster rate (90/120 Hz), this means the fast rate is switched off in the screen settings: follow the steps below. If it does not, faster drawing is not possible on this device.';
  static String rateHeldBack(String max, String measured) => _tr
      ? 'Ekran $max destekliyor ama sistem Defter\'i şu an $measured ile çizdiriyor. Defter en yüksek hızı her açılışta ister; karar cihazın ekran ayarındadır.'
      : 'The screen supports $max, but the system draws the app at $measured right now. The app asks for the fastest rate every time it opens; the decision is the device\'s screen setting.';
  static String get rateSteps => _tr
      ? '1. Ayarlar > Ekran ve parlaklık > Ekran yenileme hızı bölümünde "Yüksek" seçin ("Dinamik" ya da "Akıllı" seçiliyse sistem uygulamaları 60 Hz\'de tutabilir).\n2. Güç tasarrufu modu açıksa kapatın.\n3. Bu sayfaya dönün: ölçülen sayı ekranın en yüksek hızına çıkmalı.'
      : '1. In Settings > Display & brightness > Screen refresh rate choose "High" (with "Dynamic" or "Smart" the system may keep apps at 60 Hz).\n2. Turn power saving off if it is on.\n3. Come back to this page: the measured number should reach the screen\'s fastest rate.';
  static String get rateMeasuring => _tr ? 'Ölçülüyor…' : 'Measuring…';
  static String get rateNoInfo => _tr
      ? 'Bu cihazdan ekran bilgisi alınamadı; yalnızca ölçülen hız gösteriliyor.'
      : 'The device gave no screen information; only the measured rate is shown.';
  static String get rateOpenSettings =>
      _tr ? 'Ekran ayarlarını aç' : 'Open screen settings';
  static String get rateSettingsNotOpened => _tr
      ? 'Ekran ayarları açılamadı. Cihazın Ayarlar uygulamasından açın.'
      : 'The screen settings could not be opened. Open them from the Settings app.';
  static String get rateCopy => _tr ? 'Bilgiyi kopyala' : 'Copy the details';
  static String get rateCopied =>
      _tr ? 'Panoya kopyalandı' : 'Copied to the clipboard';
  static String get rateTouchHint => _tr
      ? 'Parmağınızı ya da kalemi ekranda gezdirirken ölçülen sayı yükseliyor, bırakınca düşüyorsa cihaz hızı kendisi değiştiriyor demektir (dinamik mod).'
      : 'If the measured number rises while you move a finger or the pen on the screen and falls when you stop, the device is changing the rate by itself (dynamic mode).';

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

  // Pen latency probe
  static String get penProbe => _tr ? 'Kalem gecikme ölçümü' : 'Pen latency measurement';
  static String get penProbeSubtitle => _tr
      ? 'Editörde bir ölçüm düğmesi gösterir: kaydı başlat, kalemle yaz, durdur'
      : 'Shows a measure button in the editor: start, write with the pen, stop';
  static String get penProbeStart => _tr ? 'Ölçümü başlat' : 'Start measuring';
  static String get penProbeStop => _tr ? 'Ölçümü bitir' : 'Stop measuring';
  static String get penProbeResult => _tr ? 'Gecikme ölçümü' : 'Latency measurement';
  static String get penProbeCopy => _tr ? 'Kopyala' : 'Copy';
  static String get penProbeCopied => _tr ? 'Kopyalandı' : 'Copied';

  // Stylus button
  static String get stylusAction => _tr ? 'Kalem çift dokunuşu' : 'Pen double tap';
  static String get stylusActionSubtitle => _tr
      ? 'Kalemin yan tuşuna ya da çift dokunuşuna basınca yapılacak iş'
      : 'What happens when the pen\'s side button or double tap is used';
  static String get stylusTaps => _tr ? 'Gereken dokunuş' : 'Taps needed';
  static String get stylusTapsSubtitle => _tr
      ? 'Kalem çift dokunuşu tek olay olarak gönderiyorsa 1, iki ayrı basış olarak gönderiyorsa 2'
      : '1 if the pen sends its double tap as one event, 2 if as two separate presses';
  static String get stylusTest => _tr ? 'Kalem testi' : 'Pen test';
  static String get stylusTestSubtitle => _tr
      ? 'Kalemin gönderdiği sinyalleri canlı gör'
      : 'See the signals the pen sends, live';
  static String get stylusTestHint => _tr
      ? 'Kalemi aşağıdaki alana tutun ve çift dokunuşu ya da yan tuşu deneyin. Gelen her sinyal listelenir.'
      : 'Hold the pen over the area below and try the double tap or the side button. Every signal is listed.';
  static String get stylusTestNothing => _tr ? 'Henüz sinyal yok' : 'No signals yet';
  static String get stylusTestDetected =>
      _tr ? 'Bu bir kalem tuşu sinyali' : 'This is a pen button signal';
  static String get stylusTestNative => _tr
      ? 'Android\'in doğrudan aldığı sinyaller (altta cihaz listesi)'
      : 'Signals Android receives directly (device list below)';
  static String get stylusTestClear => _tr ? 'Temizle' : 'Clear';
  static String get stylusNone => _tr ? 'Hiçbir şey' : 'Nothing';
  static String get stylusToggleEraser => _tr ? 'Silgi' : 'Eraser';
  static String get stylusPreviousTool => _tr ? 'Önceki araç' : 'Previous tool';
  static String get stylusLasso => _tr ? 'Kement' : 'Lasso';
  static String get stylusHighlighter => _tr ? 'Fosforlu' : 'Highlighter';
  static String get stylusUndo => _tr ? 'Geri al' : 'Undo';
  static String get stylusRedo => _tr ? 'Yinele' : 'Redo';

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
  static String get pdfSection => 'PDF';
  // -- the window that shows a PDF before it is put into the note -----------
  static String get pdfPickRectangle => _tr ? 'Dikdörtgen' : 'Rectangle';
  static String get pdfPickLasso => _tr ? 'Serbest' : 'Freehand';
  static String get pdfPickPrevious => _tr ? 'Önceki sayfa' : 'Previous page';
  static String get pdfPickNext => _tr ? 'Sonraki sayfa' : 'Next page';
  static String get pdfPickThisPage =>
      _tr ? 'Bu sayfayı seç' : 'Choose this page';
  static String get pdfPickHint => _tr
      ? 'Sayfaları işaretleyip nota sayfa olarak alın, ya da kalemle sayfanın bir yerini çevreleyip yalnızca orayı resim veya metin olarak alın. İki parmakla yakınlaştırılır.'
      : 'Tick pages to take them as pages of the note, or mark a part of the page with the pen to take only that as a picture or as text. Two fingers zoom.';
  static String get pdfPickReadingText =>
      _tr ? 'Seçilen yerdeki metin okunuyor…' : 'Reading the text in the marked part…';
  static String pdfPickTextFound(String text) =>
      _tr ? 'Metin: $text' : 'Text: $text';
  static String get pdfPickNoText => _tr
      ? 'Seçilen yerde alınabilir metin yok (sayfa taranmış bir görüntü olabilir). Resim olarak alınabilir.'
      : 'There is no text to take in the marked part (the page may be a scan). It can be taken as a picture.';
  static String get pdfPickClear => _tr ? 'Seçimi kaldır' : 'Clear the mark';
  static String get pdfPickCopy => _tr ? 'Metni kopyala' : 'Copy the text';
  static String get pdfPickCopied =>
      _tr ? 'Metin panoya kopyalandı' : 'Text copied to the clipboard';
  static String get pdfPickAsText => _tr ? 'Metin olarak al' : 'Take as text';
  static String get pdfPickAsImage =>
      _tr ? 'Resim olarak al' : 'Take as a picture';
  static String get pdfPickClearPages =>
      _tr ? 'Sayfa seçimini temizle' : 'Clear the pages';
  static String pdfPickAllPages(int count) =>
      _tr ? 'Tümünü al ($count sayfa)' : 'Take all ($count pages)';
  static String pdfPickChosenPages(int count) => count == 0
      ? (_tr ? 'Seçili sayfaları al' : 'Take the chosen pages')
      : (_tr
            ? 'Seçili $count sayfayı al'
            : 'Take the $count chosen ${count == 1 ? 'page' : 'pages'}');
  static String get pdfPickImageFailed => _tr
      ? 'Seçilen yer resim olarak alınamadı.'
      : 'The marked part could not be taken as a picture.';
  static String get pdfPickTextAdded =>
      _tr ? 'Metin sayfaya eklendi' : 'The text was added to the page';
  static String pdfPickAgain(String name) =>
      _tr ? 'PDF penceresi: $name' : 'PDF window: $name';
  static String get pdfRemove => _tr ? 'PDF\'i kaldır' : 'Remove PDF';
  static String get pdfRemoveTitle =>
      _tr ? 'PDF\'i nottan kaldır' : 'Remove the PDF from the note';
  static String get pdfRemoveAbout => _tr
      ? 'Üzerine yazdığın sayfalar silinmez: yazıların aynı yerde kalır, yalnızca arkasındaki PDF kalkar. Üzerinde bir şey olmayan PDF sayfaları nottan çıkar. Geri al düğmesi hepsini geri getirir.'
      : 'Pages you wrote on are not deleted: your writing stays where it is and only the PDF behind it goes. PDF pages with nothing on them leave the note. Undo brings everything back.';
  static String get pdfRemoveThisPage =>
      _tr ? 'Yalnızca bu sayfadan' : 'From this page only';
  static String get pdfRemoveThisPdf =>
      _tr ? 'Bu PDF\'in tamamını' : 'This whole PDF';
  static String get pdfRemoveAll =>
      _tr ? 'Nottaki bütün PDF\'leri' : 'Every PDF in the note';
  static String pdfRemoveCounts({required int pages, required int written}) {
    final leaving = pages - written;
    if (written == 0) {
      return _tr
          ? '$pages sayfa nottan çıkar'
          : '$pages ${pages == 1 ? 'page leaves' : 'pages leave'} the note';
    }
    if (leaving == 0) {
      return _tr
          ? '$pages sayfa: yazıların kalır, yalnızca PDF kalkar'
          : '$pages ${pages == 1 ? 'page' : 'pages'}: your writing stays, only the PDF goes';
    }
    return _tr
        ? '$pages sayfa: yazı olan $written sayfa yazısıyla kalır, $leaving sayfa nottan çıkar'
        : '$pages pages: $written with writing stay, $leaving leave the note';
  }

  static String pdfRemoved({required int removed, required int kept}) {
    if (kept == 0) {
      return _tr
          ? 'PDF kaldırıldı ($removed sayfa)'
          : 'PDF removed ($removed ${removed == 1 ? 'page' : 'pages'})';
    }
    if (removed == 0) {
      return _tr
          ? 'PDF kaldırıldı, yazıların duruyor ($kept sayfa)'
          : 'PDF removed, your writing is still there ($kept ${kept == 1 ? 'page' : 'pages'})';
    }
    return _tr
        ? 'PDF kaldırıldı: $removed sayfa çıktı, yazı olan $kept sayfa duruyor'
        : 'PDF removed: $removed pages left, $kept with writing stayed';
  }

  static String get undoAction => _tr ? 'Geri al' : 'Undo';
  static String get pdfCrop => _tr ? 'PDF sayfasını kırp' : 'Crop PDF page';
  static String get pdfCropHint => _tr
      ? 'Kırpılan bölüm sayfaya sığacak şekilde büyür. Çizimler yerinde kalır, bu yüzden yazmadan önce kırpmak en iyisi.'
      : 'The cropped part is enlarged to fit the page. Strokes stay where they are, so crop before writing.';
  static String get pdfCropLeft => _tr ? 'Sol' : 'Left';
  static String get pdfCropTop => _tr ? 'Üst' : 'Top';
  static String get pdfCropRight => _tr ? 'Sağ' : 'Right';
  static String get pdfCropBottom => _tr ? 'Alt' : 'Bottom';
  static String get pdfCropAllPages =>
      _tr ? 'Aynı PDF\'in tüm sayfalarına uygula' : 'Apply to all pages of this PDF';
  static String get pdfCropApply => _tr ? 'Uygula' : 'Apply';
  static String get pdfCropReset => _tr ? 'Sıfırla' : 'Reset';

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
  static String get testConnection =>
      _tr ? 'Bağlantıyı dene' : 'Test connection';
  static String testRead(String wrote, String read) => _tr
      ? 'Bağlantı çalışıyor. Resimde "$wrote" yazıyordu, model şunu okudu: '
            '"$read"'
      : 'Connection works. The picture said "$wrote", the model read: '
            '"$read"';
  static String get save => _tr ? 'Kaydet' : 'Save';
  static String get handwritingSettings =>
      _tr ? 'El yazısı tanıma' : 'Handwriting recognition';
  static String get handwritingSettingsSubtitle => _tr
      ? 'OpenRouter anahtarı ve model'
      : 'OpenRouter key and model';
  static String get apiKey => _tr ? 'OpenRouter API anahtarı' : 'OpenRouter API key';
  static String get modelName => _tr ? 'Model' : 'Model';
  static String get resetDefault => _tr ? 'Varsayılana dön' : 'Reset to default';

  // Goodnotes-style editor layout
  static String get gnLayout => _tr ? 'Goodnotes tarzı arayüz' : 'Goodnotes-style editor';
  static String get gnLayoutSubtitle => _tr
      ? 'Koyu üst bar, sekmeler ve yüzen araç şeridi. Kapatınca eski araç çubuğuna dönülür.'
      : 'Dark top bar, tabs and a floating tool strip. Turn off to get the old toolbar back.';
  static String get gnNewTab => _tr ? 'Yeni sekme' : 'New tab';
  static String get gnMoreTools => _tr ? 'Diğer araçlar' : 'More tools';
  static String get gnMenu => _tr ? 'Menü' : 'Menu';
  static String get gnStickers => _tr ? 'Çıkartmalar' : 'Stickers';
  static String get pressureLabel => _tr ? 'Basınç' : 'Pressure';
  static String get pressureNone => _tr
      ? 'Kalemle bu alana yaz; kalemin bildirdiği basınç burada görünür.'
      : 'Write here with the pen; the pressure it reports shows here.';
  static String get pressureNoRange => _tr
      ? 'Bu kalem basınç aralığı bildirmiyor: çizgi kalınlığı basınca '
            'değil hıza göre değişir.'
      : 'The pen reports no pressure range, so line width follows speed, '
            'not pressure.';
  static String get pressureFlat => _tr
      ? 'Basınç değeri değişmiyor. Kalemi hafif ve sert bastırarak dene.'
      : 'The pressure value is not changing. Try pressing lightly and hard.';
  static String get pressureWorks =>
      _tr ? 'Basınç değişiyor: kalem basıncı bildiriyor.' : 'Pressure varies: the pen reports it.';
  static String get paperColor => _tr ? 'Kâğıt rengi' : 'Paper colour';

  static String paperCategory(String? key) => switch (key) {
    null => _tr ? 'Tümü' : 'All',
    'plain' => _tr ? 'Düz / çizgili' : 'Plain / ruled',
    'columns' => _tr ? 'Sütunlar ve bölmeler' : 'Columns and splits',
    'planners' => _tr ? 'Planlayıcılar' : 'Planners',
    'diagrams' => _tr ? 'Diyagramlar' : 'Diagrams',
    _ => _tr ? 'Özel amaçlı' : 'Special',
  };

  // Paper templates
  static String get paperYearly => _tr ? 'Yıllık planlayıcı' : 'Yearly planner';
  static String get paperClassSchedule => _tr ? 'Ders programı' : 'Class schedule';
  static String get paperHabits => _tr ? 'Alışkanlık takibi' : 'Habit tracker';
  static String get paperBudget => _tr ? 'Bütçe planlayıcı' : 'Budget planner';
  static String get paperMeals => _tr ? 'Yemek planlayıcı' : 'Meal planner';
  static String get paperTravel => _tr ? 'Seyahat planlayıcı' : 'Travel planner';
  static String get paperProject => _tr ? 'Proje planlayıcı' : 'Project planner';
  static String get paperWater => _tr ? 'Su takibi' : 'Water tracker';
  static String get paperReading => _tr ? 'Kitap okuma takibi' : 'Reading log';
  static String get paperShopping => _tr ? 'Alışveriş listesi' : 'Shopping list';
  static String get paperMindMap => _tr ? 'Zihin haritası' : 'Mind map';
  static String get paperConceptMap => _tr ? 'Kavram haritası' : 'Concept map';
  static String get paperFlowchart => _tr ? 'Akış şeması' : 'Flowchart';
  static String get paperDecisionTree => _tr ? 'Karar ağacı' : 'Decision tree';
  static String get paperVenn => _tr ? 'Venn şeması' : 'Venn diagram';
  static String get paperCycle => _tr ? 'Döngü' : 'Cycle';
  static String get paperPyramid => _tr ? 'Piramit' : 'Pyramid';
  static String get paperFishbone => _tr ? 'Balık kılçığı' : 'Fishbone';
  static String get paperSwot => _tr ? 'SWOT' : 'SWOT';
  static String get paperTimeline => _tr ? 'Zaman çizelgesi' : 'Timeline';
  static String get paperRings => _tr ? 'Çember' : 'Rings';
  static String get paperWheel => _tr ? 'Pusula gülü' : 'Wheel';
  static String get paperWireframe => _tr ? 'Wireframe' : 'Wireframe';
  static String get paperMath => _tr ? 'Koordinat düzlemi' : 'Coordinate plane';
  static String get paperRecipe => _tr ? 'Tarif defteri' : 'Recipe';
  static String get paperMillimetre => _tr ? 'Milimetrik' : 'Millimetre';
  static String get paperCircuit => _tr ? 'Devre şeması' : 'Circuit';
  static String get paperPcb => _tr ? 'PCB ızgarası' : 'PCB grid';
  static String get paperBlockDiagram => _tr ? 'Blok diyagram' : 'Block diagram';
  static String get paperGantt => _tr ? 'Gantt şeması' : 'Gantt chart';
  static String get paperMeasureTable =>
      _tr ? 'Ölçüm tablosu' : 'Measurement table';
  static String get paperOrgChart => _tr ? 'Hiyerarşi' : 'Hierarchy';
  static String get paperArrowDiagram => _tr ? 'Ok şeması' : 'Process arrows';
  static String get paperRelationDiagram =>
      _tr ? 'İlişki şeması' : 'Relationship diagram';
  static String get paperAcademicPlanner =>
      _tr ? 'Akademik planlayıcı' : 'Academic planner';
  static String get paperGoalPlanner => _tr ? 'Hedef planlayıcı' : 'Goal planner';
  static String get paperFinancePlanner =>
      _tr ? 'Finans planlayıcı' : 'Finance planner';
  static String get paperMoodTracker => _tr ? 'Ruh hali takibi' : 'Mood tracker';
  static String get paperStudentPlanner =>
      _tr ? 'Öğrenci planlayıcı' : 'Student planner';
  static String get paperLedger => _tr ? 'Hesap defteri' : 'Ledger';

  // -- home screen and new notebook -----------------------------------------
  static String get homeDashboard => _tr ? 'Yeni ana sayfa' : 'New home screen';
  static String get homeDashboardSubtitle => _tr
      ? 'Kenar çubuğu, son kullanılanlar, klasörler ve şablonlar tek ekranda'
      : 'Sidebar, recent notes, folders and templates on one screen';
  static String get appName => 'Defter';
  static String get navHome => _tr ? 'Ana Sayfa' : 'Home';
  static String get navNotes => _tr ? 'Notlarım' : 'My Notes';
  static String get navPlanners => _tr ? 'Planlayıcılar' : 'Planners';
  static String get navTemplates => _tr ? 'Şablonlar' : 'Templates';
  static String get navFavorites => _tr ? 'Favoriler' : 'Favorites';
  static String get navRecent => _tr ? 'Son Kullanılanlar' : 'Recent';
  static String get navTrash => _tr ? 'Çöp Kutusu' : 'Trash';
  static String get navWhiteboard => _tr ? 'Beyaz Tahta' : 'Whiteboard';
  static String get navSettings => _tr ? 'Ayarlar' : 'Settings';
  static String get folders => _tr ? 'Klasörler' : 'Folders';
  static String get newFolder => _tr ? 'Yeni Klasör' : 'New Folder';
  static String get folderName => _tr ? 'Klasör adı' : 'Folder name';
  static String get folderNameEmpty =>
      _tr ? 'Klasör adı boş olamaz' : 'A folder needs a name';
  static String get folderNameSlash => _tr
      ? 'Klasör adında eğik çizgi olamaz'
      : 'A folder name can\'t have a slash';
  static String get folderNameExists =>
      _tr ? 'Bu adda bir klasör var' : 'There is a folder with this name';
  static String get heroTitle => _tr
      ? 'Tek bir yerde, tüm düşünceleriniz.'
      : 'All your thoughts, in one place.';
  static String get heroSubtitle => _tr
      ? 'Not alın, planlayın, tasarlayın, daha fazlasını yapın.'
      : 'Take notes, plan, design and more.';
  static String get searchNotes => _tr ? 'Notlarda ara…' : 'Search notes…';
  static String get actionNewNote => _tr ? 'Yeni Not' : 'New Note';
  static String get actionFromTemplate =>
      _tr ? 'Şablondan Oluştur' : 'From Template';
  static String get actionImportPdf => _tr ? 'PDF İçe Aktar' : 'Import PDF';
  static String get actionAddImage => _tr ? 'Görüntü Ekle' : 'Add Image';
  static String get actionNewFolder => _tr ? 'Klasör Oluştur' : 'Create Folder';
  static String get actionMore => _tr ? 'Diğer' : 'More';
  static String get actionImportNote => _tr ? 'Not içe aktar' : 'Import a note';
  static String get seeAll => _tr ? 'Tümü' : 'All';
  static String get newItem => _tr ? 'Yeni' : 'New';
  static String get noRecentNotes => _tr
      ? 'Henüz not yok. "Yeni Not" ile başlayın.'
      : 'No notes yet. Start with "New Note".';
  static String get noFolders =>
      _tr ? 'Henüz klasör yok.' : 'No folders yet.';
  static String itemCount(int count) => _tr ? '$count öğe' : '$count items';
  static String templatesOf(String group) =>
      _tr ? '$group Şablonları' : '$group Templates';
  static String get imageRotate => _tr ? 'Döndür' : 'Rotate';
  static String get imageMore => _tr ? 'Diğer' : 'More';
  static String get camera => _tr ? 'Kamera' : 'Camera';
  static String get takePhoto => _tr ? 'Fotoğraf çek' : 'Take a photo';
  static String cameraFailed(String failure) => switch (failure) {
    'noCamera' =>
      _tr
          ? 'Bu cihazda kamera uygulaması bulunamadı.'
          : 'No camera app was found on this device.',
    'busy' =>
      _tr ? 'Kamera zaten açık.' : 'The camera is already open.',
    _ =>
      _tr
          ? 'Fotoğraf alınamadı. Lütfen yeniden deneyin.'
          : 'The photo could not be taken. Please try again.',
  };
  static String get pdfImportFailed =>
      _tr ? 'PDF içe aktarılamadı' : 'The PDF could not be imported';
  static String pdfImportReason(String failure) => switch (failure) {
    'missing' =>
      _tr
          ? 'Seçilen dosyaya ulaşılamadı. Dosya başka bir uygulamadaysa önce cihaza indirip yeniden deneyin.'
          : 'The chosen file could not be reached. If it is in another app, download it to the device first and try again.',
    'empty' =>
      _tr
          ? 'Dosya boş ya da içinde sayfa yok.'
          : 'The file is empty or has no pages.',
    'notPdf' =>
      _tr ? 'Bu dosya bir PDF değil.' : 'This file is not a PDF.',
    'locked' =>
      _tr
          ? 'Bu PDF parola ile korunuyor. Parolasız bir kopyasını içe aktarın.'
          : 'This PDF is protected with a password. Import a copy without one.',
    _ =>
      _tr
          ? 'PDF okunamadı. Dosya bozuk olabilir.'
          : 'The PDF could not be read. The file may be damaged.',
  };
  static String get pdfNotSupported => _tr
      ? 'Bu cihazda PDF içe aktarılamıyor.'
      : 'PDFs can\'t be imported on this device.';
  static String get invalidNoteFile => _tr
      ? 'Bu dosya türü içe aktarılamıyor (.sbn, .sbn2, .sba ya da .pdf seçin)'
      : 'This kind of file can\'t be imported (choose .sbn, .sbn2, .sba or .pdf)';
  static String get wizardTitle =>
      _tr ? 'Yeni Defter Oluştur' : 'Create a New Notebook';
  static String get stepTemplate => _tr ? 'Şablon Seç' : 'Choose a Template';
  static String get stepCover => _tr ? 'Kapak Tasarla' : 'Design the Cover';
  static String get stepSize => _tr ? 'Boyut ve Yön' : 'Size and Orientation';
  static String get stepName => _tr ? 'Adlandır' : 'Name It';
  static String get stepFolder => _tr ? 'Klasör Seç' : 'Choose a Folder';
  static String get stepCreate => _tr ? 'Oluştur' : 'Create';
  static String get coverDesign => _tr ? 'Kapak Tasarımı' : 'Cover Design';
  static String get noCover => _tr ? 'Kapaksız' : 'No Cover';
  static String get coverMinimal => _tr ? 'Minimal' : 'Minimal';
  static String get coverColourful => _tr ? 'Renkli' : 'Colourful';
  static String get coverPatterned => _tr ? 'Desenli' : 'Patterned';
  static String get coverClassic => _tr ? 'Klasik' : 'Classic';
  static String get coverNature => _tr ? 'Doğa' : 'Nature';
  static String get orientationPortrait => _tr ? 'Dikey' : 'Portrait';
  static String get orientationLandscape => _tr ? 'Yatay' : 'Landscape';
  static String get paperColour => _tr ? 'Kağıt Rengi' : 'Paper Colour';
  static String get colourWhite => _tr ? 'Beyaz' : 'White';
  static String get colourCream => _tr ? 'Krem' : 'Cream';
  static String get colourIvory => _tr ? 'Fildişi' : 'Ivory';
  static String get colourGrey => _tr ? 'Gri' : 'Grey';
  static String get colourBlack => _tr ? 'Siyah' : 'Black';
  static String get colourPink => _tr ? 'Pembe' : 'Pink';
  static String get colourBlue => _tr ? 'Mavi' : 'Blue';
  static String get colourGreen => _tr ? 'Yeşil' : 'Green';
  static String get colourLilac => _tr ? 'Lila' : 'Lilac';
  static String get colourYellow => _tr ? 'Sarı' : 'Yellow';
  static String get colourPeach => _tr ? 'Şeftali' : 'Peach';
  static String get colourMint => _tr ? 'Mint' : 'Mint';
  static String get rootFolder => _tr ? 'Ana klasör' : 'Top folder';
  static String get back => _tr ? 'Geri' : 'Back';
  static String get next => _tr ? 'İleri' : 'Next';
  static String get summaryTemplate => _tr ? 'Şablon' : 'Template';
  static String get summaryCover => _tr ? 'Kapak' : 'Cover';
  static String get summarySize => _tr ? 'Boyut' : 'Size';
  static String get summaryName => _tr ? 'Ad' : 'Name';
  static String get summaryFolder => _tr ? 'Klasör' : 'Folder';
  static String get defaultName =>
      _tr ? 'Tarihli varsayılan ad' : 'Dated default name';

  // -- paper catalogue -----------------------------------------------------
  static String get groupAll => _tr ? 'Tümü' : 'All';
  static String get groupBlank => _tr ? 'Boş' : 'Blank';
  static String get groupLined => _tr ? 'Çizgili' : 'Lined';
  static String get groupSquared => _tr ? 'Kareli' : 'Squared';
  static String get groupDotted => _tr ? 'Noktalı' : 'Dotted';
  static String get groupPlanner => _tr ? 'Planlayıcı' : 'Planner';
  static String get groupDiagram => _tr ? 'Diyagram' : 'Diagram';
  static String get groupEngineering => _tr ? 'Mühendislik' : 'Engineering';
  static String get groupAcademic => _tr ? 'Akademik' : 'Academic';
  static String get groupSpecial => _tr ? 'Özel' : 'Special';
  static String get topicYearly => _tr ? 'Yıllık' : 'Yearly';
  static String get topicMonthly => _tr ? 'Aylık' : 'Monthly';
  static String get topicWeekly => _tr ? 'Haftalık' : 'Weekly';
  static String get topicDaily => _tr ? 'Günlük' : 'Daily';
  static String get topicFinance => _tr ? 'Finans' : 'Finance';
  static String get topicHealth => _tr ? 'Sağlık' : 'Health';
  static String get topicSchool => _tr ? 'Akademik' : 'School';
  static String get topicProject => _tr ? 'Proje' : 'Project';
  static String get topicFood => _tr ? 'Yemek' : 'Food';
  static String get topicTravel => _tr ? 'Seyahat' : 'Travel';
  static String get topicTechnical => _tr ? 'Teknik Çizim' : 'Technical Drawing';
  static String get topicElectronics =>
      _tr ? 'Elektrik-Elektronik' : 'Electronics';
  static String get topicMechanical => _tr ? 'Mekanik' : 'Mechanical';
  static String get topicArchitecture => _tr ? 'Mimari' : 'Architecture';
  static String get topicComputing => _tr ? 'Bilgi İşlem' : 'Computing';
  static String get topicFlow => _tr ? 'Akış' : 'Flow';
  static String get topicMindMap => _tr ? 'Zihin Haritası' : 'Mind Map';
  static String get topicOrganisation => _tr ? 'Organizasyon' : 'Organisation';
  static String get topicAnalysis => _tr ? 'Analiz' : 'Analysis';
  static String get topicMaths => _tr ? 'Matematik' : 'Maths';
  static String get topicOther => _tr ? 'Diğer' : 'Other';
  static String get linedNarrow => _tr ? 'Dar Çizgili' : 'Narrow Ruled';
  static String get linedMedium => _tr ? 'Orta Çizgili' : 'Medium Ruled';
  static String get linedWide => _tr ? 'Geniş Çizgili' : 'Wide Ruled';
  static String get squaredSmall => _tr ? 'Küçük Kareli' : 'Small Squares';
  static String get squaredMedium => _tr ? 'Orta Kareli' : 'Medium Squares';
  static String get squaredLarge => _tr ? 'Büyük Kareli' : 'Large Squares';
  static String get dottedDense => _tr ? 'Sık Noktalı' : 'Dense Dots';
  static String get dottedMedium => _tr ? 'Noktalı' : 'Dotted';
  static String get dottedWide => _tr ? 'Seyrek Noktalı' : 'Wide Dots';
  static String get formatStandard => _tr ? 'Standart' : 'Standard';
  static String get formatSquare => _tr ? 'Kare' : 'Square';

  static String get labelNo => 'No';
  static String get labelFeature => _tr ? 'Ölçülen özellik' : 'Feature';
  static String get labelNominal => _tr ? 'Nominal' : 'Nominal';
  static String get labelTolerance => _tr ? 'Tolerans' : 'Tolerance';
  static String get labelMeasured => _tr ? 'Ölçülen' : 'Measured';
  static String get labelResult => _tr ? 'Sonuç' : 'Result';
  static String get labelPart => _tr ? 'Parça' : 'Part';
  static String get labelInstrument => _tr ? 'Ölçü aleti' : 'Instrument';
  static String get labelDrawnBy => _tr ? 'Çizen' : 'Drawn by';
  static String get labelSheet => _tr ? 'Sayfa' : 'Sheet';
  static String get labelWeek => _tr ? 'Hafta' : 'Week';
  static String get labelTerm => _tr ? 'Dönem' : 'Term';
  static String get labelLessons => _tr ? 'Dersler' : 'Classes';
  static String get labelHomework => _tr ? 'Ödevler' : 'Homework';
  static String get labelExams => _tr ? 'Sınavlar' : 'Exams';
  static String get labelLesson => _tr ? 'Ders' : 'Class';
  static String get labelGrade => _tr ? 'Not' : 'Grade';
  static String get labelWhy => _tr ? 'Neden önemli?' : 'Why it matters';
  static String get labelPlanSteps => _tr ? 'Adımlar' : 'Steps';
  static String get labelDeadline => _tr ? 'Bitiş tarihi' : 'Deadline';
  static String get labelProgress => _tr ? 'İlerleme' : 'Progress';
  static String get labelSavings => _tr ? 'Birikim' : 'Savings';
  static String get labelDescription => _tr ? 'Açıklama' : 'Description';
  static String get labelDebit => _tr ? 'Borç' : 'Debit';
  static String get labelCredit => _tr ? 'Alacak' : 'Credit';
  static String get labelBalance => _tr ? 'Bakiye' : 'Balance';
  static String get labelMood => _tr ? 'Ruh hali' : 'Mood';
  static String get labelDay => _tr ? 'Gün' : 'Day';
  static String get labelStart => _tr ? 'Başlangıç' : 'Start';
  static String get labelEnd => _tr ? 'Bitiş' : 'End';

  static List<String> get months => _tr
      ? const ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık']
      : const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  static String get labelYear => _tr ? 'Yıl' : 'Year';
  static String get labelHabit => _tr ? 'Alışkanlık' : 'Habit';
  static String get labelIncome => _tr ? 'Gelir' : 'Income';
  static String get labelExpenses => _tr ? 'Gider' : 'Expenses';
  static String get labelTotal => _tr ? 'Toplam' : 'Total';
  static String get labelAmount => _tr ? 'Tutar' : 'Amount';
  static List<String> get meals3 => _tr
      ? const ['Kahvaltı', 'Öğle', 'Akşam']
      : const ['Breakfast', 'Lunch', 'Dinner'];
  static String get labelTask => _tr ? 'Görev' : 'Task';
  static String get labelOwner => _tr ? 'Sorumlu' : 'Owner';
  static String get labelDue => _tr ? 'Tarih' : 'Due';
  static String get labelStatus => _tr ? 'Durum' : 'Status';
  static String get labelDestination => _tr ? 'Gidilecek yer' : 'Destination';
  static String get labelDates => _tr ? 'Tarihler' : 'Dates';
  static String get labelStay => _tr ? 'Konaklama' : 'Stay';
  static String get labelTransport => _tr ? 'Ulaşım' : 'Transport';
  static String get labelPacking => _tr ? 'Bavul listesi' : 'Packing list';
  static String get labelBook => _tr ? 'Kitap' : 'Book';
  static String get labelAuthor => _tr ? 'Yazar' : 'Author';
  static String get labelRating => _tr ? 'Puan' : 'Rating';
  static String get labelSummary => _tr ? 'Özet' : 'Summary';
  static String get labelQuotes => _tr ? 'Alıntılar' : 'Quotes';
  static String get labelShopping => _tr ? 'Alışveriş listesi' : 'Shopping list';
  static String get labelWater => _tr ? 'Su (bardak)' : 'Water (glasses)';
  static String get labelRecipe => _tr ? 'Tarif' : 'Recipe';
  static String get labelIngredients => _tr ? 'Malzemeler' : 'Ingredients';
  static String get labelSteps => _tr ? 'Yapılışı' : 'Steps';
  static String get labelTime => _tr ? 'Süre' : 'Time';
  static String get labelServings => _tr ? 'Porsiyon' : 'Servings';
  static List<String> get swotNames => _tr
      ? const ['Güçlü yönler', 'Zayıf yönler', 'Fırsatlar', 'Tehditler']
      : const ['Strengths', 'Weaknesses', 'Opportunities', 'Threats'];
  static String get labelGoal => _tr ? 'Hedef' : 'Goal';
  static String get labelTopic => _tr ? 'Konu' : 'Topic';
  static String get paperIsometric => _tr ? 'İzometrik' : 'Isometric';
  static String get paperEngineering => _tr ? 'Mühendislik' : 'Engineering';
  static String get paperWriting => _tr ? 'El yazısı' : 'Handwriting';
  static String get paperTodo => _tr ? 'Yapılacaklar' : 'To-do';
  static String get paperWeekly => _tr ? 'Haftalık plan' : 'Weekly planner';
  static String get paperDaily => _tr ? 'Günlük plan' : 'Daily planner';
  static String get paperMonthly => _tr ? 'Aylık takvim' : 'Monthly calendar';
  static String get paperMeeting => _tr ? 'Toplantı notu' : 'Meeting notes';
  static String get paperStoryboard => _tr ? 'Storyboard' : 'Storyboard';
  static String get paperTable => _tr ? 'Tablo' : 'Table';
  static String get paperTwoColumns => _tr ? 'İki sütun' : 'Two columns';
  static String get paperThreeColumns => _tr ? 'Üç sütun' : 'Three columns';
  static String get paperFourColumns => _tr ? 'Dört sütun' : 'Four columns';
  static String get paperSideSplit => _tr ? 'Yan bölmeli' : 'Cue column';
  static String get paperTopBottom => _tr ? 'Üst-alt bölmeli' : 'Top and bottom';
  static String get paperVerticalSplit => _tr ? 'Dikey bölmeli' : 'Side by side';
  static String get paperSquareSplit => _tr ? 'Kare bölmeli' : 'Four boxes';
  static String get paperTitled => _tr ? 'Başlıklı' : 'With title';
  static String get paperBullets => _tr ? 'Madde işaretli' : 'Bullets';
  static String get paperNumbered => _tr ? 'Numaralı liste' : 'Numbered list';
  static String get paperLegal => _tr ? 'Legal' : 'Legal pad';
  static String get paperHexagon => _tr ? 'Petek' : 'Honeycomb';
  static String get paperDiamond => _tr ? 'Elmas' : 'Diamond';

  /// Labels printed on the planner templates.
  static List<String> get weekDays => _tr
      ? const ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar']
      : const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static List<String> get weekDaysShort => _tr
      ? const ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz']
      : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static String get labelNotes => _tr ? 'Notlar' : 'Notes';
  static String get labelDate => _tr ? 'Tarih' : 'Date';
  static String get labelTitle => _tr ? 'Başlık' : 'Title';
  static String get labelTodo => _tr ? 'Yapılacaklar' : 'To do';
  static String get labelSchedule => _tr ? 'Program' : 'Schedule';
  static String get labelMonth => _tr ? 'Ay' : 'Month';
  static String get labelAttendees => _tr ? 'Katılımcılar' : 'Attendees';
  static String get labelAgenda => _tr ? 'Gündem' : 'Agenda';
  static String get labelActions => _tr ? 'Aksiyonlar' : 'Action items';

  static String get tipSharpness => _tr ? 'Uç keskinliği' : 'Tip sharpness';
  static String get pressureSensitivity =>
      _tr ? 'Basınç duyarlılığı' : 'Pressure sensitivity';
  static String get lineStabilization =>
      _tr ? 'Çizgi stabilizasyonu' : 'Line stabilization';
  static String get penSettingsSection => _tr ? 'Ayarlar' : 'Settings';
  static String get drawAndHold => _tr ? 'Çiz ve tut' : 'Draw and hold';
  static String get gnRename => _tr ? 'Yeniden adlandır' : 'Rename';

  // Handwriting search
  static String searchPage(int page) => _tr ? 's. $page' : 'p. $page';
  static String get hwSection => _tr ? 'El yazısı araması' : 'Handwriting search';
  static String get hwAdd => _tr ? 'Aramaya ekle' : 'Add to search';
  static String get hwRefresh => _tr ? 'Aramayı yenile' : 'Refresh search text';
  static String get hwNone =>
      _tr ? 'El yazısı henüz aramaya eklenmedi' : 'Handwriting is not in search yet';
  static String get hwDone => _tr ? 'Aramaya eklendi' : 'Added to search';
  static String get hwOutdated => _tr
      ? 'Not o zamandan beri değişti; yenilemek için dokun'
      : 'The note changed since; tap to refresh';
  static String get hwNoWriting =>
      _tr ? 'Notta kalemle yazılmış bir şey yok' : 'There is no pen writing in this note';
  static String get hwConfirmTitle =>
      _tr ? 'El yazısı aramaya eklensin mi?' : 'Add handwriting to search?';
  static String hwConfirmBody(int pictures) => _tr
      ? 'Bu notun el yazısı $pictures parça halinde resim olarak OpenRouter\'a '
          'gönderilir ve okunan metin yalnızca bu cihazda saklanır. Notun '
          'kendisi değişmez. Eklendikten sonra arama çevrimdışı çalışır.'
      : 'The handwriting of this note is sent to OpenRouter as $pictures '
          'pictures and the text that comes back is kept only on this device. '
          'The note itself is not changed. Searching works offline once added.';
  static String hwCapped(int max) => _tr
      ? 'Not çok uzun: yalnızca ilk $max parça okunur.'
      : 'This note is very long: only the first $max pieces are read.';
  static String get hwStart => _tr ? 'Başla' : 'Start';
  static String get hwCancel => _tr ? 'Vazgeç' : 'Cancel';
  static String hwProgress(int done, int total) =>
      _tr ? 'Okunuyor: $done / $total' : 'Reading: $done / $total';
  static String hwIndexedOn(String when) =>
      _tr ? 'Aramaya eklendi ($when)' : 'In search since $when';

  // Ask my notes
  static String get askNotes => _tr ? 'Notlarıma sor' : 'Ask my notes';
  static String get askHint =>
      _tr ? 'Notlarında ne arıyorsun?' : 'What are you looking for in your notes?';
  static String get askNoNotes => _tr
      ? 'Notlarında bununla ilgili bir şey bulamadım'
      : 'I found nothing about this in your notes';
  static String get askSources => _tr ? 'Kullanılan notlar' : 'Notes used';
  static String get askTypedOnly => _tr
      ? 'Yazıyla girilen metin ve "Aramaya ekle" ile okunan el yazısı taranır.'
      : 'Typed text and handwriting added with "Add to search" are searched.';
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

  // E-ink mode
  static String get eInkSection => _tr ? 'E-mürekkep modu' : 'E-ink mode';
  static String get eInkMode => _tr ? 'E-mürekkep modu' : 'E-ink mode';
  static String get eInkModeSubtitle => _tr
      ? 'Uygulamayı ve notları gri tonlarda, kâğıt gibi gösterir. Yalnızca görünümdür; notların renkleri değişmez.'
      : 'Shows the app and notes in greys on paper. Only the view changes; the notes keep their colours.';
  static String get eInkPaperWarmth =>
      _tr ? 'Kâğıt sıcaklığı' : 'Paper warmth';
  static String get eInkInkDarkness =>
      _tr ? 'Mürekkep koyuluğu' : 'Ink darkness';
  static String get eInkTexture => _tr ? 'Kâğıt dokusu' : 'Paper texture';
  static String get eInkRefresh =>
      _tr ? 'Yenileme efekti' : 'Refresh effect';
  static String get eInkRefreshSubtitle => _tr
      ? 'Sayfa değişince hafif bir yenileme. Yazarken hiç çalışmaz; "hareketi azalt" açıksa kapalıdır.'
      : 'A light refresh when turning pages. Never while writing; off when "reduce motion" is on.';
  static String get eInkRefreshPage =>
      _tr ? 'Sayfayı yenile' : 'Refresh page';
  static String get eInkBrightness =>
      _tr ? 'Uygulama parlaklığı' : 'App brightness';
  static String get eInkBrightnessSubtitle => _tr
      ? 'Yalnızca bu uygulamanın penceresi için. Uygulamadan çıkınca veya mod kapanınca sistem parlaklığına döner.'
      : 'For this app\'s window only. Goes back to the system brightness when you leave the app or turn the mode off.';
  static String get eInkBrightnessSystem => _tr ? 'Sistem' : 'System';
  static String get eInkExport =>
      _tr ? 'Dışa aktarmada e-mürekkep görünümü' : 'Export in e-ink look';
  static String get eInkExportSubtitle => _tr
      ? 'PDF ve PNG çıktısı gri tonlu olur. Kapalıysa çıktı notun kendi renkleriyle alınır.'
      : 'PDF and PNG exports are grey. When off, exports use the note\'s own colours.';
  static String get eInkLimits => _tr
      ? 'Gerçek e-mürekkep ekran ışığı yansıtır, görüntüyü güç harcamadan tutar ve fiziksel olarak yenilenir. Bunlar yazılımla yapılamaz; bu mod yalnızca görünümü taklit eder.'
      : 'A real e-ink screen reflects light, holds an image without power and refreshes physically. Software cannot do those; this mode only imitates the look.';

  // -- eraser ----------------------------------------------------------------
  static String get eraserPrecise => _tr ? 'Hassas' : 'Precise';
  static String get eraserWhole => _tr ? 'Çizgi' : 'Stroke';
  static String get eraserPreciseHint => _tr
      ? 'Yalnızca silginin üzerinden geçtiği yeri siler'
      : 'Erases only what the eraser passes over';
  static String get eraserWholeHint => _tr
      ? 'Dokunduğu çizgiyi bütünüyle siler'
      : 'Erases every stroke it touches as a whole';

  // -- version history -----------------------------------------------------
  static String get versionHistory => _tr ? 'Sürüm geçmişi' : 'Version history';
  static String get versionHistoryAbout => _tr
      ? 'Not açılırken, kapanırken ve yazarken yaklaşık on dakikada bir o anki hali saklanır. Son 10 sürüm ve daha eskilerden günde bir sürüm (20 güne kadar) tutulur. Bir sürüme dönerseniz şimdiki hali de saklanır.'
      : 'The note is kept as it is when it is opened, when it is closed and about every ten minutes while you write. The last 10 versions are kept, and of older ones one a day (for up to 20 days). When you go back to a version, the note as it is now is kept too.';
  static String get versionsEmpty => _tr
      ? 'Bu notun henüz saklanan bir sürümü yok.'
      : 'No version of this note has been kept yet.';
  static String get versionsOff => _tr
      ? 'Sürüm saklama kapalı; yeni sürüm saklanmıyor. Ayarlar > Yedekleme bölümünden açabilirsiniz.'
      : 'Keeping versions is off; no new versions are kept. You can turn it on under Settings > Backup.';
  static String get versionRestore => _tr ? 'Geri yükle' : 'Restore';
  static String get versionReasonOpen => _tr ? 'Açılırken' : 'On opening';
  static String get versionReasonAuto => _tr ? 'Yazarken' : 'While writing';
  static String get versionReasonClose => _tr ? 'Kapanırken' : 'On closing';
  static String get versionReasonRestore =>
      _tr ? 'Geri yüklemeden önce' : 'Before a restore';
  static String versionReason(String reason) => switch (reason) {
    'open' => versionReasonOpen,
    'close' => versionReasonClose,
    'restore' => versionReasonRestore,
    _ => versionReasonAuto,
  };
  static String versionRestoreTitle(String when) =>
      _tr ? '$when sürümüne dönülsün mü?' : 'Go back to the version of $when?';
  static String get versionRestoreBody => _tr
      ? 'Not bu sürümdeki haline döner. Şimdiki hali de sürüm olarak saklanır; isterseniz ona geri dönebilirsiniz.'
      : 'The note goes back to how it was in this version. The note as it is now is kept as a version too, so you can come back to it.';
  static String get versionFirstPage =>
      _tr ? 'İlk sayfanın görüntüsü' : 'Picture of the first page';
  static String get versionRestored =>
      _tr ? 'Sürüm geri yüklendi' : 'Version restored';
  static String get versionRestoreFailed => _tr
      ? 'Bu sürüm geri yüklenemedi. Not olduğu gibi duruyor.'
      : 'This version could not be restored. The note is as it was.';
  static String versionPages(int assets) => _tr
      ? (assets == 0 ? 'Ek dosya yok' : '$assets ek dosya')
      : (assets == 0 ? 'No attachments' : '$assets attachments');

  static const _monthsTr = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];
  static const _monthsEn = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// A point in time the way it is said: "Bugün 14:05", "Dün 09:30" or
  /// "3 Ekim 2026 18:02".
  static String dayAndTime(DateTime time, {DateTime? now}) {
    now ??= DateTime.now();
    final clock =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    // From midnight to midnight, in hours: a day is 23 to 25 of them,
    // whichever way the clocks were changed.
    final gap = DateTime(now.year, now.month, now.day)
        .difference(DateTime(time.year, time.month, time.day))
        .inHours;
    if (gap == 0) return _tr ? 'Bugün $clock' : 'Today $clock';
    if (gap > 0 && gap <= 25) return _tr ? 'Dün $clock' : 'Yesterday $clock';
    final month = (_tr ? _monthsTr : _monthsEn)[time.month - 1];
    return _tr
        ? '${time.day} $month ${time.year} $clock'
        : '${time.day} $month ${time.year}, $clock';
  }

  // -- backup ----------------------------------------------------------------
  static String get backupTitle =>
      _tr ? 'Yedekleme ve sürüm geçmişi' : 'Backup and version history';
  static String get backupSettingsSubtitle => _tr
      ? 'Tüm defterleri tek dosyaya yedekleyin, yedekten geri yükleyin'
      : 'Back up every notebook to one file, bring a backup back';
  static String get backupSection => _tr ? 'Tam yedek' : 'Full backup';
  static String get backupAbout => _tr
      ? 'Tüm notlarınız; içlerindeki resimler ve PDF\'ler, ses kayıtları, el yazısı arama metinleri ve kalem profilleriyle birlikte tek bir zip dosyasına yazılır ve yazıldıktan sonra baştan okunarak doğrulanır.'
      : 'All your notes, with their pictures and PDFs, audio recordings, handwriting search text and pen profiles, are written to one zip file, which is then read back to check it.';
  static String get backupLimits => _tr
      ? 'Yedek kendiliğinden alınmaz ve cihazın dışına kendiliğinden gitmez: oluşturduktan sonra Drive, bilgisayar veya USB bellek gibi başka bir yere kaydedin. Çöp kutusundaki notlar ve uygulama ayarları yedeğe girmez.'
      : 'Backups are not made on their own and do not leave the device on their own: after making one, save it somewhere else, such as Drive, a computer or a USB stick. Notes in the trash and app settings are not included.';
  static String get backupCreate => _tr ? 'Yedek oluştur' : 'Make a backup';
  static String get backupRestore =>
      _tr ? 'Yedekten geri yükle' : 'Restore from a backup';
  static String get backupShare => _tr ? 'Paylaş / gönder' : 'Share / send';
  static String get backupSave => _tr ? 'Cihaza kaydet' : 'Save to device';
  static String get backupSaved => _tr ? 'Yedek kaydedildi' : 'Backup saved';
  static String get backupTooLargeToSave => _tr
      ? 'Bu yedek "Cihaza kaydet" için çok büyük. "Paylaş / gönder" ile dosya yöneticinize veya Drive\'a gönderin.'
      : 'This backup is too large for "Save to device". Use "Share / send" to hand it to your file manager or Drive.';
  static String get backupWriting => _tr ? 'Yedek yazılıyor…' : 'Writing the backup…';
  static String get backupVerifying =>
      _tr ? 'Yedek doğrulanıyor…' : 'Checking the backup…';
  static String get backupRestoring =>
      _tr ? 'Notlar geri yükleniyor…' : 'Restoring notes…';
  static String get backupReading => _tr ? 'Yedek okunuyor…' : 'Reading the backup…';
  static String backupProgress(String done, String total) =>
      '$done / $total';
  static String get backupReady =>
      _tr ? 'Yedek hazır ve doğrulandı' : 'The backup is ready and checked';
  static String backupSummary(int notes, int recordings, String size) => _tr
      ? '$notes not, $recordings ses kaydı · $size'
      : '$notes notes, $recordings recordings · $size';
  static String get backupReadyHint => _tr
      ? 'Şimdi bu dosyayı cihazın dışında bir yere kaydedin. Dosya uygulamanın geçici alanında durur; yeni yedek alınca veya sistem yer açınca silinir.'
      : 'Now save this file somewhere off the device. It sits in the app\'s temporary space and goes when a new backup is made or the system frees space.';
  static String backupLast(String when) =>
      _tr ? 'Son oluşturulan yedek: $when' : 'Last backup made: $when';
  static String get backupNone =>
      _tr ? 'Bu cihazda henüz yedek oluşturulmadı' : 'No backup has been made on this device yet';
  static String get backupFileGone => _tr
      ? 'Dosyası artık geçici alanda değil; gerekirse yeniden oluşturun.'
      : 'Its file is no longer in the temporary space; make a new one if needed.';
  static String backupRestoreTitle(String when) =>
      _tr ? '$when tarihli yedek' : 'Backup of $when';
  static String backupRestoreBody(int notes, int recordings, String size) => _tr
      ? 'Bu yedekte $notes not ve $recordings ses kaydı var ($size).\n\nCihazdaki hiçbir notun üzerine yazılmaz ve hiçbir not silinmez: aynı olan notlar atlanır, aynı adlı ama farklı olan notlar "(2)" gibi bir adla yanına eklenir.'
      : 'This backup holds $notes notes and $recordings recordings ($size).\n\nNo note on the device is replaced or deleted: notes that are the same are skipped, and notes of the same name that differ are added next to them under a name like "(2)".';
  static String get backupRestoreDone =>
      _tr ? 'Geri yükleme tamamlandı' : 'Restore finished';
  static String restoreRestored(int n) =>
      _tr ? '$n not geri yüklendi' : '$n notes restored';
  static String restoreAlreadyThere(int n) => _tr
      ? '$n not zaten vardı, dokunulmadı'
      : '$n notes were here already and left alone';
  static String restoreCopies(int n) => _tr
      ? '$n not farklıydı, kopya olarak eklendi'
      : '$n notes differed and were added as copies';
  static String restoreRecordings(int n) =>
      _tr ? '$n ses kaydı geri yüklendi' : '$n recordings restored';
  static String restoreFailed(int n) => _tr
      ? '$n not yedekte bozuk çıktı ve atlandı'
      : '$n notes are damaged in the backup and were left out';
  static String backupError(String failure) => switch (failure) {
    'notABackup' =>
      _tr
          ? 'Bu dosya Defter yedeği değil.'
          : 'This file is not a Defter backup.',
    'newerFormat' =>
      _tr
          ? 'Bu yedek uygulamanın daha yeni bir sürümüyle alınmış. Önce uygulamayı güncelleyin.'
          : 'This backup was made by a newer version of the app. Update the app first.',
    'damaged' =>
      _tr
          ? 'Yedek dosyası bozuk veya eksik.'
          : 'The backup file is damaged or incomplete.',
    'changedWhileReading' =>
      _tr
          ? 'Yedek alınırken notlar değişti. Lütfen yeniden deneyin.'
          : 'Notes changed while the backup was made. Please try again.',
    _ =>
      _tr
          ? 'Dosya okunamadı veya yazılamadı. Boş yer kalmamış olabilir.'
          : 'A file could not be read or written. The device may be out of space.',
  };
  static String get backupFailed =>
      _tr ? 'Yedek oluşturulamadı' : 'The backup could not be made';
  static String get restoreFailedTitle =>
      _tr ? 'Geri yüklenemedi' : 'Could not restore';
  static String get versionsSection => _tr ? 'Sürüm geçmişi' : 'Version history';
  static String get versionsSwitch =>
      _tr ? 'Notların eski sürümlerini sakla' : 'Keep earlier versions of notes';
  static String versionsSize(String size) => _tr
      ? 'Saklanan sürümler cihazda $size yer kaplıyor'
      : 'The versions kept take $size on the device';
  static String get versionsWhere => _tr
      ? 'Sürümlere not açıkken ⋯ menüsündeki "Sürüm geçmişi" ile ulaşılır. Sürümler yalnızca bu cihazda durur; yedeğe ve eşitlemeye girmez.'
      : 'Versions are reached with "Version history" in the ⋯ menu while a note is open. They stay on this device only; they are not part of backups or sync.';
  static String get versionsClear =>
      _tr ? 'Tüm sürümleri sil' : 'Delete all versions';
  static String get versionsClearBody => _tr
      ? 'Bütün notların saklanan eski sürümleri silinir. Notların şimdiki hali etkilenmez. Bu geri alınamaz.'
      : 'The earlier versions kept of every note are deleted. The notes as they are now are not affected. This cannot be undone.';
  static String get versionsCleared =>
      _tr ? 'Sürümler silindi' : 'Versions deleted';
}
