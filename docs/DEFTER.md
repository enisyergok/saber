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
| Düzen | Çöp kutusu, favoriler, ad ve metin araması (Türkçe harf duyarlı), sayfa ızgarası ve yer imleri, sekmeler |
| PDF | PDF içinde metin arama, içindekiler listesi, sayfa kırpma (Alt menü > PDF), PDF'e dışa aktarma |
| Kalem | (devamı) Kalem çift dokunuşu eylemi (Ayarlar), kalem sinyali testi, kalem gecikme ölçümü (Ayarlar > Kalem gecikme ölçümü; editörde kayıt düğmesi) |
| Ana sayfa | Tablette açılış ekranı: kenar çubuğu (Ana Sayfa, Notlarım, Planlayıcılar, Şablonlar, Favoriler, Son Kullanılanlar, Beyaz Tahta, Çöp Kutusu, Ayarlar, klasörler), üstte arama ve eylemler (Yeni Not, Şablondan Oluştur, PDF İçe Aktar, Görüntü Ekle, Klasör Oluştur), son açılan notlar, klasörler ve içlerindeki öğe sayısı, şablon türleri. Ayarlar > "Yeni ana sayfa" ile kapatılır; telefonda eski görünüm kalır. |
| Yeni defter | Altı adım: şablon (78 kâğıt, türlere göre), kapak (36 kapak, türlere göre, adın yazılı önizlemesi), boyut ve yön (Standart, A4, A5, B5, Letter, Kare; dikey/yatay) ile kâğıt rengi, ad, klasör, özet. Her adımda "Oluştur" ile varsayılanlarla hemen açılabilir. |
| Şablon galerileri | Planlayıcı, mühendislik ve diyagram şablonları konu başlıklarına göre (yıllık, finans, sağlık…; teknik çizim, elektrik-elektronik, mekanik…; akış, zihin haritası, analiz…). Yeni kâğıtlar: milimetrik, devre şeması, PCB ızgarası, blok diyagram, Gantt, ölçüm tablosu, hiyerarşi, ok şeması, ilişki şeması, akademik/hedef/finans/öğrenci planlayıcı, ruh hali takibi, hesap defteri. |
| Kalem paneli | Kalem düğmesine ikinci dokunuş. Altı kalem (dolma, tükenmez, fırça, kurşun kalem, marker, kaligrafi), canlı önizleme, kalınlık (mm), opaklık, uç keskinliği, basınç duyarlılığı, çizgi stabilizasyonu, noktaları sürüklenen basınç eğrisi, renkler, hazır ve kendi kalem profillerin. |
| Teknik araçlar | Kalem panelinde: otomatik düz çizgi, tutmadan şekil tanıma, 15° adımlı açı kılavuzu, cetvel (her çizgi düz), kareli kâğıt, ölçüm (çizerken uzunluk ve açı), ok ve ölçülendirme (çizgiye ok uçları ve mm olarak uzunluğu, daireye çap, dikdörtgene en ve boy; mürekkep olarak yazılır). Şekli otomatik düzeltme: neredeyse kare olan kare, neredeyse daire olan daire olur. |
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
- Ölçülendirme yazısı sıradan mürekkeptir: çizgiyi sonradan taşır ya da uzatırsan yazı kendiliğinden güncellenmez.
- Fırça ve kaligrafi kalemlerinin çizgileri dosyada dolma kalem çizgisi olarak saklanır (eski sürümler de açabilsin diye); bu yüzden not yeniden açıldığında çizgiler aynı görünür ama hangi kalemle çizildikleri ayırt edilmez.
- Kaligrafi kaleminin ucu 45° sabittir; açı ayarı yok.
- Tutmadan şekil tanıma açıkken yaklaşık 2 cm'den büyük kapalı çizimler şekle döner; büyük yazılmış "O" gibi harfler de daireye dönebilir. Varsayılan olarak kapalıdır.
- Kalem paneli yatay tablette ekrana sığmayabilir; içi kaydırılır.
- Notlarıma sor, yazıyla girilen metni ve "Aramaya ekle" ile okunmuş el yazısını tarar. Aramaya eklenmemiş notların el yazısı taranmaz; not sonradan değişirse metin eski kalır (menü uyarır, yenilemek için dokun). Aramaya ekleme internet ve OpenRouter anahtarı ister; eklendikten sonra arama çevrimdışıdır. Uzun not en çok 60 parça okunur.
- Ses kayıtları eşitlenmez. Not yeniden adlandırılırsa, taşınırsa veya çöpe atılırsa kayıtlar notla birlikte gider; klasör olarak taşınırsa kayıtlar yerinde kalır.
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
