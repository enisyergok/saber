# Defter — özellikler, gizlilik, sınırlar

Defter, Saber Notes'un (Flutter) çatalıdır. Tablet için kalem deneyimi,
çevrimdışı çalışma ve veri kaybı olmaması önceliklidir.

## Özellikler

| Alan | Ne var |
| --- | --- |
| Kalem | Mürekkep katmanları (yazarken yalnızca canlı katman çizilir), avuç içi reddi, silgi hızlandırma ve 3 silgi boyutu, kalın/ince ve renk ön ayarları, 3 saydamlık düzeyi |
| Araçlar | Kement seçimi: taşı, boyutlandır, döndür (geri al/yinele dahil); şekil kalemi, isteğe bağlı ok ucu |
| Güvenli kayıt | Atomik yazma, `.bak` yedek, bozuk dosyada yedekten kurtarma, `.bad` karantina |
| Düzen | Çöp kutusu, favoriler, ad ve metin araması (Türkçe harf duyarlı), sayfa ızgarası ve yer imleri, sekmeler |
| PDF | PDF içinde metin arama, içindekiler listesi, PDF'e dışa aktarma |
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
- PDF dışa aktarmada arka plan PDF sayfaları resim olarak (2 kat çözünürlük) gömülür; çizgiler vektör kalır.
- PDF sayfa kırpma yok.
- Uygulama herkese açık varsayılan anahtarla imzalanıyor; kendi anahtarına geçmek uygulamayı silip yeniden kurmayı gerektirir.
