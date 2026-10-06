# Defter — özellikler, gizlilik, sınırlar

Defter, Saber Notes'un (Flutter) çatalıdır. Tablet için kalem deneyimi,
çevrimdışı çalışma ve veri kaybı olmaması önceliklidir.

## Özellikler

| Alan | Ne var |
| --- | --- |
| Kalem | Mürekkep katmanları (yazarken yalnızca canlı katman çizilir), avuç içi reddi, silgi hızlandırma ve 3 silgi boyutu, kalın/ince ve renk ön ayarları, 3 saydamlık düzeyi |
| Araçlar | Kement seçimi: taşı, boyutlandır, döndür (geri al/yinele dahil); şekil kalemi, isteğe bağlı ok ucu |
| Şekiller | Bekleyince düzleştirme (kalemi çizimden sonra 0,6 sn durdur; fosforlu dahil), çokgen/elips/yay/döndürülmüş dikdörtgen tanıma, şekil köşelerini sürükleyerek düzenleme, uçların yakın şekillere yapışması; hepsi Ayarlar'dan kapatılabilir |
| Arayüz | Gruplanmış araç çubuğu, doğrudan şekil düğmesi, üst çubukta "3 / 12" sayfa sayacı, geniş ekranda sayfa küçük resim paneli |
| Güvenli kayıt | Atomik yazma, `.bak` yedek, bozuk dosyada yedekten kurtarma, `.bad` karantina |
| Sürüm geçmişi | Not açılırken, kapanırken ve yazarken on dakikada bir o anki hali (resim ve PDF'leriyle) cihazda saklanır: son 10 sürüm ve daha eskilerden günde bir sürüm (20 güne kadar). Alt menü > Sürüm geçmişi ile bir sürüme dönülür; dönmeden önce şimdiki hal de saklanır, yani geri dönüş de geri alınabilir. Aynı içerik bir kez tutulur. Ayarlar > Yedekleme'den kapatılır, kapladığı yer görülür, tümü silinir. |
| Tam yedek | Ayarlar > Yedekleme ve sürüm geçmişi > Yedek oluştur: tüm notlar (resim, PDF, önizleme), ses kayıtları, el yazısı arama metinleri ve kalem profilleri tek bir zip dosyasına yazılır, sonra baştan okunup SHA-256 ile doğrulanır; dosya paylaşma menüsüyle ya da "Cihaza kaydet" ile dışarı alınır. Yedekten geri yükle: hiçbir notun üzerine yazılmaz ve hiçbir not silinmez; aynı olan atlanır, farklı olan "(2)" adıyla yanına eklenir, yedekte bozuk çıkan not atlanıp gerisi yüklenir. |
| Düzen | Çöp kutusu, favoriler, ad ve metin araması (Türkçe harf duyarlı), sayfa ızgarası ve yer imleri, sekmeler |
| PDF | PDF içinde metin arama, içindekiler listesi, sayfa kırpma (Alt menü > PDF), PDF'e dışa aktarma |
| Kalem | (devamı) Kalem çift dokunuşu eylemi (Ayarlar), kalem sinyali testi, kalem gecikme ölçümü (Ayarlar > Kalem gecikme ölçümü; editörde kayıt düğmesi) |
| Ana sayfa | Tablette açılış ekranı: kenar çubuğu (Ana Sayfa, Notlarım, Planlayıcılar, Şablonlar, Favoriler, Son Kullanılanlar, Beyaz Tahta, Çöp Kutusu, Ayarlar, klasörler), üstte arama ve eylemler (Yeni Not, Şablondan Oluştur, PDF İçe Aktar, Görüntü Ekle, Klasör Oluştur), son açılan notlar, klasörler ve içlerindeki öğe sayısı, şablon türleri. Ayarlar > "Yeni ana sayfa" ile kapatılır; telefonda eski görünüm kalır. |
| Yeni defter | Altı adım: şablon (78 kâğıt, türlere göre), kapak (36 kapak, türlere göre, adın yazılı önizlemesi), boyut ve yön (Standart, A4, A5, B5, Letter, Kare; dikey/yatay) ile kâğıt rengi, ad, klasör, özet. Her adımda "Oluştur" ile varsayılanlarla hemen açılabilir. |
| Şablon galerileri | Planlayıcı, mühendislik ve diyagram şablonları konu başlıklarına göre (yıllık, finans, sağlık…; teknik çizim, elektrik-elektronik, mekanik…; akış, zihin haritası, analiz…). Yeni kâğıtlar: milimetrik, devre şeması, PCB ızgarası, blok diyagram, Gantt, ölçüm tablosu, hiyerarşi, ok şeması, ilişki şeması, akademik/hedef/finans/öğrenci planlayıcı, ruh hali takibi, hesap defteri. |
| Kalem paneli | Kalem düğmesine ikinci dokunuş. Altı kalem (dolma, tükenmez, fırça, kurşun kalem, marker, kaligrafi), canlı önizleme, kalınlık (mm), opaklık, uç keskinliği, basınç duyarlılığı, çizgi stabilizasyonu, noktaları sürüklenen basınç eğrisi, renkler, hazır ve kendi kalem profillerin. |
| Teknik araçlar | Kalem panelinde: otomatik düz çizgi, tutmadan şekil tanıma, 15° adımlı açı kılavuzu, cetvel (her çizgi düz), kareli kâğıt, ölçüm (çizerken uzunluk ve açı), ok ve ölçülendirme (çizgiye ok uçları ve mm olarak uzunluğu, daireye çap, dikdörtgene en ve boy; mürekkep olarak yazılır). Her biri tek başına çalışır: açı kılavuzu ya da ölçülendirme açıkken elle düz çizilen çizgi, "Düz Çizgi" kapalı olsa da düzleştirilir; ölçülendirme açıkken daire ve dikdörtgen de tanınır. Ölçüm ve açı değeri çizerken kalemin ucunun üstünde, çizgi bitince 4 sn daha görünür. Şekli otomatik düzeltme: neredeyse kare olan kare, neredeyse daire olan daire olur. |
| E-mürekkep modu | Ayarlar > E-mürekkep modu. Arayüz ve notlar gri tonlarda, kâğıt gibi görünür (kâğıt sıcaklığı, mürekkep koyuluğu, doku şiddeti ayarlanır). Yalnızca görünümdür; notların renkleri değişmez. Resim ve PDF sayfaları gri tona çevrilir, sayfa değişince hafif yenileme efekti olur (Alt menü > Sayfayı yenile ile tam yenileme), pencere parlaklığı düşürülebilir, dışa aktarma isteğe bağlı gri tonlu olur |
| Ses | Nota bağlı ses kaydı (cihazda saklanır) |
| Bağlantılar | Metinden başka nota bağlantı |
| Eşitleme | Nextcloud; senkron durumu sayfası |
| OpenRouter | El yazısını metne çevirme, Notlarıma sor |
| El yazısı araması | Alt menü > El yazısı araması > Aramaya ekle: notun el yazısı bölümler halinde okunur, metin cihazda ayrı dosyada tutulur (not değişmez, eşitlenmez). Ana ekran araması ve Notlarıma sor bu metni de tarar; sonuçta sayfa numarası görünür |

## Neler internete gider

Hiçbir şey kendiliğinden gitmez. Yalnızca sen bastığında:

- **Yazıyı metne çevir:** seçili kalem yazısı, siyah beyaz bir resim olarak OpenRouter'a gönderilir.
- **Notlarıma sor:** sorunla ilgili en fazla 5 notun ilgili parçaları ve sorun gönderilir.
- **Nextcloud eşitlemesi:** yalnızca giriş yaptıysan.

OpenRouter anahtarı Ayarlar > El yazısı tanıma bölümünde girilir ve cihazda
saklanır (şifrelenmez, eşitlenmez).

## Bilinen sınırlar

- Ana sayfada örnek görseldeki "Kütüphane", "Paylaşılanlar" ve bildirim zili yok: uygulamada bunların karşılığı olan bir özellik bulunmuyor, boş düğme konmadı.
- Yeni defterde sayfa numarası seçeneği yok (uygulama sayfalara numara basmıyor).
- Kâğıt boyutu yalnızca yeni defter oluşturulurken seçilir; var olan bir notun boyutu sonradan değiştirilemez. Sonradan eklenen sayfalar bir önceki sayfanın boyutunu alır (PDF sayfasından sonra eklenenler hariç, onlar standart boyuttadır).
- Milimetrik kâğıdın en küçük karesi 2 mm'dir (1 mm çizgiler ekranda birbirine karışıyor); PCB ızgarasında noktalar 5,08 mm aralıklıdır.
- Çizgi aralığı dar/orta/geniş olan kâğıtlar aynı deseni farklı satır yüksekliğiyle kullanır; satır yüksekliği not açıkken alt menüden de değiştirilebilir.
- Yeni defterin kapağı ilk sayfa olarak eklenir; ana ekrandaki defter kartı notun ilk sayfasını gösterdiği için kapak orada da görünür. Kapak görüntüsü tablette doğrulanmadı (testler gerçek resim çizemiyor).
- Uzunluklar sayfanın A4 genişliğinde (210 mm) olduğu varsayılarak hesaplanır: 1000 sayfa birimi = 210 mm. Başka boyutta yazdırırsan ölçüler aynı oranda değişir; PDF üzerine çizilen notlarda sayfa genişliği A4 değilse mm değeri gerçek ölçüyü vermez.
- Açı kılavuzu ve ölçülendirme yalnızca düz çizilen çizgilere dokunur: çizgi, iki ucu arasındaki doğrudan boyunun %6'sından fazla sapmamalı ve yaklaşık 7 mm'den uzun olmalı; yazı ve eğriler olduğu gibi kalır. Bu ikisi açıkken kısa düz çizgiler ("l", "–" gibi) de düzleşebilir; yazı yazarken kapatmak gerekir. Ölçüm tek başına çizgiyi değiştirmez, yalnızca ölçer.
- Ölçülendirme yazısı sıradan mürekkeptir: çizgiyi sonradan taşır ya da uzatırsan yazı kendiliğinden güncellenmez.
- Fırça ve kaligrafi kalemlerinin çizgileri dosyada dolma kalem çizgisi olarak saklanır (eski sürümler de açabilsin diye); bu yüzden not yeniden açıldığında çizgiler aynı görünür ama hangi kalemle çizildikleri ayırt edilmez.
- Kaligrafi kaleminin ucu 45° sabittir; açı ayarı yok.
- Tutmadan şekil tanıma açıkken yaklaşık 2 cm'den büyük kapalı çizimler şekle döner; büyük yazılmış "O" gibi harfler de daireye dönebilir. Varsayılan olarak kapalıdır.
- Kalem paneli yatay tablette ekrana sığmayabilir; içi kaydırılır.
- Notlarıma sor, yazıyla girilen metni ve "Aramaya ekle" ile okunmuş el yazısını tarar. Aramaya eklenmemiş notların el yazısı taranmaz; not sonradan değişirse metin eski kalır (menü uyarır, yenilemek için dokun). Aramaya ekleme internet ve OpenRouter anahtarı ister; eklendikten sonra arama çevrimdışıdır. Uzun not en çok 60 parça okunur.
- Ses kayıtları eşitlenmez. Not yeniden adlandırılırsa, taşınırsa veya çöpe atılırsa kayıtlar notla birlikte gider; klasör yeniden adlandırılınca da içindeki notların kayıtları, el yazısı metni ve sürümleri notlarla gider.
- Yedek kendiliğinden alınmaz ve cihazın dışına kendiliğinden gitmez; zamanlanmış otomatik yedek yok. Yedek dosyası uygulamanın geçici alanında oluşur (yeni yedekte veya sistem yer açınca silinir); kalıcı olması için dışarı kaydetmek gerekir. "Cihaza kaydet" dosyayı bellekten geçirdiği için 150 MB'a kadar olan yedeklerde çıkar, daha büyükleri paylaşma menüsüyle alınır.
- Yedeğe girmeyenler: çöp kutusundaki notlar, uygulama ayarları, sürüm geçmişi, arama dizini (yeniden kurulur), Nextcloud oturumu. Kalem profillerinden yalnızca cihazda olmayanlar eklenir; var olan bir profilin yedekteki farklı hali geri gelmez.
- Geri yüklemede "aynı not" şöyle anlaşılır: not dosyası bayt bayt aynı, ek sayısı ve her ekin boyutu aynı. Ekin içeriği ayrıca karşılaştırılmaz.
- Sürüm geçmişi yalnızca cihazda durur (eşitlenmez, yedeğe girmez) ve uygulama silinince gider; cihaz kaybına karşı koruma tam yedektir. Sürümler not açıkken alt menüden açılır; ana ekrandan bir notun sürümlerine bakılamaz. Bir sürüm yalnızca tümüyle geri yüklenir, tek sayfası alınamaz. Editör dışından değişen notların (eşitlemeyle gelen değişiklik) ara halleri sürüm olmaz; not bir sonraki açılışta o haliyle saklanır.
- Sürüm geçmişi yer kaplar: her notun resim ve PDF'lerinin bir kopyası sürüm deposunda da durur (aynı içerik bir kez tutulur, sürüm sayısı kadar çoğalmaz), ayrıca her sürüm için not dosyasının o hali. Kapladığı yer Ayarlar > Yedekleme'de yazar.
- Sürüm saklanırken not dosyaları arka planda okunur; çok büyük PDF'li notlarda ilk sürüm birkaç saniye sürebilir (yazmayı bekletmez, kayıt en çok 3 sn bekler ve o sürüm atlanır).
- Sürüm geçmişi ve tam yedek tablette denenmedi; dosya işlemleri testlerde gerçek dosyalarla, paylaşma ve dosya seçme pencereleri ise yalnızca tablette denenebilir.
- Notlar arası bağlantılar yolu içerir; hedef not yeniden adlandırılırsa bağlantı eski adı gösterir.
- Resim ve dikdörtgen içeren seçimler döndürülemez.
- PDF dışa aktarmada arka plan PDF sayfaları resim olarak (3 kat çözünürlük) gömülür; çizgiler vektör kalır. Gerçek vektör PDF için yeni kütüphane gerekir.
- PDF sayfa kırpma sayfa boyutunu değiştirmez; kesilen bölüm sayfaya sığacak şekilde büyür, çizimler yerinde kalır (önce kırp, sonra yaz). Kırpma geri al düğmesine bağlı değil, penceredeki Sıfırla ile geri alınır.
- Şekil tanıma en çok 6 köşeli çokgenleri tanır (daha fazlası daire/elips sayılır); yıldız eski tanıyıcıyla çalışır. Köşe düzenleme yalnızca bu sürümden sonra tanınan çokgen ve çizgilerde vardır, eski şekillerde yoktur.
- Üç ayrı çizgiden tek üçgen yapma yok: çizgi uçları yapışır ama ayrı vuruş olarak kalır.
- E-mürekkep modu gerçek e-mürekkep ekranın yerini tutmaz: ışığı yansıtma, görüntüyü güç harcamadan tutma ve fiziksel yenilenme yazılımla yapılamaz, yalnızca görünüm taklit edilir. Cihaz genelinde gri tonlama, root veya özel ROM bu uygulamanın özelliği değildir.
- E-mürekkep modunda sistem açık/koyu teması yok sayılır (kâğıt hep açık renkli). Koyu zeminli notlar en çok %28 koyulukta açık gri kâğıda çevrilir, aksi halde mürekkep görünmez olurdu.
- E-mürekkep modunda renk seçicideki kalem renkleri gerçek renkleriyle kalır (seçilen rengi tanımak için); sayfada gri görünürler.
- Resim ve PDF için gri tona çevirme çizim sırasında yapılır (ek bellek kullanmaz); gerçek dithering (nokta serpme) yoktur, çünkü 8 bit LCD üzerinde yalnızca gren katardı.
- Uygulama depodaki yedek (fallback) anahtarla imzalanıyor; kendi anahtarına geçmek uygulamayı silip yeniden kurmayı gerektirir. Şimdilik bırakıldı.
