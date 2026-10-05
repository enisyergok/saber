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
| Ses | Nota bağlı ses kaydı (cihazda saklanır) |
| Bağlantılar | Metinden başka nota bağlantı |
| Eşitleme | Nextcloud; senkron durumu sayfası |
| OpenRouter | El yazısını metne çevirme, Notlarıma sor |

## Neler internete gider

Hiçbir şey kendiliğinden gitmez. Yalnızca sen bastığında:

- **Yazıyı metne çevir:** seçili kalem yazısı, siyah beyaz bir resim olarak OpenRouter'a gönderilir.
- **Notlarıma sor:** sorunla ilgili en fazla 5 notun ilgili parçaları ve sorun gönderilir.
- **Nextcloud eşitlemesi:** yalnızca giriş yaptıysan.

OpenRouter anahtarı Ayarlar > El yazısı tanıma bölümünde girilir ve cihazda
saklanır (şifrelenmez, eşitlenmez).

## Bilinen sınırlar

- Notlarıma sor yalnızca **yazıyla girilen** metni tarar. El yazısı önce metne çevrilmeli.
- Ses kayıtları eşitlenmez. Not yeniden adlandırılırsa, taşınırsa veya çöpe atılırsa kayıtlar notla birlikte gider; klasör olarak taşınırsa kayıtlar yerinde kalır.
- Notlar arası bağlantılar yolu içerir; hedef not yeniden adlandırılırsa bağlantı eski adı gösterir.
- Resim ve dikdörtgen içeren seçimler döndürülemez.
- PDF dışa aktarmada arka plan PDF sayfaları resim olarak (3 kat çözünürlük) gömülür; çizgiler vektör kalır. Gerçek vektör PDF için yeni kütüphane gerekir.
- PDF sayfa kırpma sayfa boyutunu değiştirmez; kesilen bölüm sayfaya sığacak şekilde büyür, çizimler yerinde kalır (önce kırp, sonra yaz). Kırpma geri al düğmesine bağlı değil, penceredeki Sıfırla ile geri alınır.
- Şekil tanıma en çok 6 köşeli çokgenleri tanır (daha fazlası daire/elips sayılır); yıldız eski tanıyıcıyla çalışır. Köşe düzenleme yalnızca bu sürümden sonra tanınan çokgen ve çizgilerde vardır, eski şekillerde yoktur.
- Üç ayrı çizgiden tek üçgen yapma yok: çizgi uçları yapışır ama ayrı vuruş olarak kalır.
- Uygulama depodaki yedek (fallback) anahtarla imzalanıyor; kendi anahtarına geçmek uygulamayı silip yeniden kurmayı gerektirir. Şimdilik bırakıldı.
