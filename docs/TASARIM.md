# Sözcük Zinciri — Oyun tasarımı

## İlk sürüm

Godot 4.7.2, GDScript, Compatibility renderer. İlk teslim web içindir; Android ve iOS için dikey Control yerleşimi ve yerel klavye kullanımı korunur. Bu sürüm yalnızca Türkçedir.

Yükleme → yerel profil → kısa açıklama → oynanabilir öğretici → ana menü. Sonraki açılışlarda profil ve öğretici geçilir. Öğreticide ÇAY → KAŞIK → OYUN → HAVA zinciri ücretsiz jokerlerle oynanır.

## Oynanış

24 editoryal bölüm, 3 kategori: Mutfak, Doğa, Günlük Yaşam. Bölümler 4 veya 5 sözcük içerir. Önceki sözcük ile sıradaki sözcük bir isim tamlaması veya yerleşik ifade oluşturur. Cevap ek almadan yalın sözcük olarak girilir. Bitişte bütün bağlantıların doğru biçimleri gösterilir: çay kaşığı, kaşık oyunu, oyun havası.

İlk sözcük açık, sıradaki sözcüğün ilk harfi ve uzunluğu görünür. Sonraki kartlar, önceki kelimenin çözülmesini bekler. Hatalı tahminler altın veya can tüketmez. Türkçe i/İ ve ı/I dönüşümleri ayrı ele alınır. Başta ve sonda kalan boşluklar temizlenir; yanlış harfler otomatik olarak doğru cevaba dönüştürülmez.

Her kategorinin ilk bölümü açıktır; diğerleri önceki bölümle açılır. Tamamlanmış bölümler tekrar oynanabilir. Ana menü henüz tamamlanmamış en erken bölüme ve varsa o bölümdeki kayıtlı tahmine ilerler.

## Ekonomi

| İşlem | Miktar |
| --- | --- |
| İlk profil | 100 altın |
| Bölümün ilk tamamlanması | +25 altın |
| Aynı bölümün tekrarı | 0 altın |
| Rastgele kapalı harf | −15 altın |
| Anlam ipucu | −10 altın |
| Öğretici jokerleri | Ücretsiz |

Yetersiz bakiyede işlem yapılmaz. Açılmış ipucu tekrar ücretlendirilmez. Tüm harfler açılmışsa ek ücret alınmaz. İlk harf zaten ücretsizdir. Reklam, satın alma ve çevrim içi cüzdan bu sürüme dahil değildir.

## Yerel kayıt

`user://progress.json`: şema sürümü, ad, avatar, öğretici durumu, altın, tamamlanan bölümler, devam edilen zincirlerin adımı/açık harfleri/ipucu durumu ve animasyon tercihi. Her ekonomik işlem, tamamlanma ve profil değişikliğinde kaydedilir. Web'de Godot'un IndexedDB dosya sistemi kullanılır. Tarayıcı verileri silinirse veya gizli oturum kullanılırsa kayıt kaybolabilir. Veriler cihazlar arasında senkronize edilmez.

## Parti modu

2–4 oyuncu, 1 veya 2 tur. Aynı cihaz sırayla paylaşılır. Her el öncesinde oyuncuya teslim ekranı, ardından 3–2–1 geri sayımı vardır. Her oyuncu 4 kelimelik farklı bir zinciri 90 saniyede çözer.

Doğru sözcük +30 puan; harf −10, ipucu −5. Zinciri bitiren oyuncuya kalan her 3 saniye için +1 puan eklenir. Parti jokerleri kişisel altını tüketmez. Her el sonrasında cevaplar gösterilir. Sonuçlar puana göre sıralanır; eşit puanda beraberlik gösterilir. Parti skorları kalıcı profile aktarılmaz.

## 1'e 1 çevrim içi yarış — sonraki aşama

Mevcut ekranda bağlantının henüz açık olmadığı belirtilir. Sahte oda, rakip, skor veya mesaj üretilmez. `RemoteRace` gelecekteki bağlantı katmanı için sınır oluşturur.

Sonraki uygulama: oda kodu, sunucu tarafından belirlenen ortak zincir, ortak başlangıç zamanı, sunucu doğrulamalı cevap ve skor, izinli kısa mesaj listesi, yeniden bağlanma ve zaman aşımı. Web için WebSocket; kimlik, oda sahipliği ve skor doğrulaması sunucuda olmalıdır. Cihaz saati ve yerel altın rekabetçi skor için güven kaynağı değildir.

## Görsel sistem

Kırık beyaz `#FAF7F0`, mor `#7654BF`, lila `#EEE7F8`, sarı `#F8D875`, mercan `#EF9277`, koyu metin `#35264C`. Nunito değişken fontu, SIL Open Font License. Büyük başlıklar 28–34, kelime kutuları 23, gövde 14–17 mantıksal piksel. Normal butonlar 48–58 piksel. Köşeler 16–26 piksel. Bulanıklık, ekran yakalama shader'ı, gerçek zamanlı ışık ve pahalı gölge yoktur.

Özgün maskot ve dört kategori/parti çizimi, yerleşik imagegen ile üretilmiş bitmap varlıklardır. Temel brief: “ivory background, flat playful pastel illustration, dark plum outlines, purple/yellow/coral palette, crisp edges, no text, no blur”. Kaynaklar `assets/mascot.webp`, `tea.webp`, `plant.webp`, `book.webp`, `party.webp`; font lisansı `assets/FONT-LICENSE.txt`.

## Performans bütçesi

Oyun yalnızca 2D Control düğümleri kullanır. 30 FPS üst sınır; oyun mantığında sürekli `_process` veya fizik döngüsü yoktur. Sayaç yalnızca parti oynanırken saniyede bir çalışır. Konfeti 22 basit dörtgenden oluşur; kısa sürede temizlenir ve profil üzerinden kapatılabilir. Ekranlar değiştirilirken önceki düğümler ve animasyonlar temizlenir.

Maskot 480×480, küçük çizimler 192×192, şeffaf WebP. Görsel kaynaklarının toplamı yaklaşık 66 KB; Nunito fontu yaklaşık 270 KB. Ok ve onay işaretleri için küçük bir DejaVu Sans alt kümesi kullanılır. Kaynak görsellerin büyük üretim dosyaları dağıtıma dahil edilmez. Yazı ve butonlar motorun yerel UI bileşenleridir; bir ekran görüntüsü olarak paketlenmez. Web'de giriş alanları native HTML input ve JavaScriptBridge ile Godot'a bağlanır; mobilde cihazın klavyesi doğrudan kullanıcı dokunuşuyla açılır. Masaüstü ve mobil IME girişleri de bu alanlardan geçer.

Web: single-thread export, GDExtension kapalı, VRAM sıkıştırma kapalı, ek CDN veya çalışma zamanı ağı yok. GitHub Pages'te özel COOP/COEP başlığı gerektirmez. Godot WebAssembly motoru ayrıca indirilir; bu boyut oyun çizimleriyle karıştırılmamalıdır. Motor 39.514.754 bayt; gzip aktarımı 10.054.758 bayttır. GitHub Pages özel sıkıştırma başlıkları sunmadığından modern tarayıcılarda DecompressionStream kullanılarak sıkıştırılmış motor akış hâlinde açılır ve WebAssembly derlemesine verilir. Bu API olmayan eski tarayıcılarda standart WASM dosyasına dönülür. Oyun PCK paketi yaklaşık 450 KB. Daha küçük motor gerekirse sonraki aşamada 3D ve kullanılmayan modüller kapatılarak özel export template derlenebilir.

## İngilizceye hazırlık

İngilizce içerik veya dil düğmesi bu sürümde gösterilmez. Gelecekte arayüz metinleri TranslationServer'a, bölüm içerikleri dil başına ayrı JSON dosyalarına taşınabilir. Türkçe normalleştirme İngilizce cevaplara uygulanmamalıdır. Her dil için bağlantıların ayrı editoryal incelemesi gerekir.
