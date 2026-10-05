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
}
