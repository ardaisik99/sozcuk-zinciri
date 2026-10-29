# Sözcük Zinciri — Oyun tasarımı

## Sürüm 2

Godot 4.7.2, GDScript, Compatibility renderer. İlk teslim web içindir; Android ve iOS için dikey Control yerleşimi ve yerel klavye kullanımı korunur. Bu sürüm yalnızca Türkçedir.

Yükleme → kullanıcı adı → kısa açıklama → oynanabilir öğretici → ana menü. Profil resmi ve avatar seçimi kaldırılmıştır. Sonraki açılışlarda profil ve öğretici geçilir. Öğreticide SU → BARDAK → ALTLIK → KUMAŞ zinciri ücretsiz jokerlerle oynanır.

## Oynanış

24 editoryal bölüm, 3 kategori: Mutfak, Doğa, Günlük Yaşam. Bölümler 4 veya 5 sözcük içerir. Önceki sözcük ile sıradaki sözcük bir isim tamlaması veya yerleşik ifade oluşturur. Cevap doğrudan harf kutularına yazılır. İlk harfi tekrar yazmak gerekmez. Örneğin B hazırken ARDAĞI yazmak yeterlidir. Ekli biçim BARDAĞI, kısa bir harf animasyonuyla BARDAK köküne dönüşür ve sonraki bağlantı bardak altlığı olur. Tam ekli sözcük, yalnızca eksik devamı, yalın kök veya tam doğru tamlama kabul edilir. Keyfi ek kesilmez: bütün dönüşümler `forms` ve `words` alanlarında tanımlıdır.

Doğru girişten 240 ms sonra doğrulama başlar. Harfler sırayla hafifçe büyür; ek harfleri kaybolur, yumuşamış harfler köke döner. Animasyon yaklaşık 600 ms sürer. Cevap alanı ve klavye odağı aynı kalır; sonraki kelime için tekrar dokunulmaz. Ayrı bir cevap kutusu ve kontrol düğmesi yoktur. Klavyenin gönder/ileri tuşu da doğrular. Animasyon tercihi kapalıysa dönüşüm anlıktır.

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

`user://progress.json`: şema ve içerik sürümü, ad, öğretici durumu, altın, tamamlanan bölümler, devam edilen zincirlerin adımı/açık harfleri/ipucu durumu ve animasyon tercihi. V1'den geçişte kazanılmış altın ve tamamlanan bölümler korunur; eski harf maskeleri yeni ekli biçimlerle çakışmaması için sıfırlanır. Her ekonomik işlem, tamamlanma ve profil değişikliğinde kaydedilir. Web'de Godot'un IndexedDB dosya sistemi kullanılır. Tarayıcı verileri silinirse veya gizli oturum kullanılırsa kayıt kaybolabilir. Veriler cihazlar arasında senkronize edilmez.

## Parti modu

2–4 oyuncu, 1 veya 2 tur. Aynı cihaz sırayla paylaşılır. Her el öncesinde oyuncuya teslim ekranı, ardından 3–2–1 geri sayımı vardır. Her oyuncu 4 kelimelik farklı bir zinciri 90 saniyede çözer.

Doğru sözcük +30 puan; harf −10, ipucu −5. Zinciri bitiren oyuncuya kalan her 3 saniye için +1 puan eklenir. Parti jokerleri kişisel altını tüketmez. Her el sonrasında cevaplar gösterilir. Sonuçlar puana göre sıralanır; eşit puanda beraberlik gösterilir. Parti skorları kalıcı profile aktarılmaz.

## 1'e 1 çevrim içi yarış — sonraki aşama

Mevcut ekranda bağlantının henüz açık olmadığı belirtilir. Sahte oda, rakip, skor veya mesaj üretilmez. `RemoteRace` gelecekteki bağlantı katmanı için sınır oluşturur.

Sonraki uygulama: oda kodu, sunucu tarafından belirlenen ortak zincir, ortak başlangıç zamanı, sunucu doğrulamalı cevap ve skor, izinli kısa mesaj listesi, yeniden bağlanma ve zaman aşımı. Web için WebSocket; kimlik, oda sahipliği ve skor doğrulaması sunucuda olmalıdır. Cihaz saati ve yerel altın rekabetçi skor için güven kaynağı değildir.

## Görsel sistem

Referanslardaki organik kenar formları, canlı mor `#6038EF`, lila `#F0EBFF`, altın sarısı `#FFCA58`, beyaz `#FFFEFA` ve koyu mor metin `#292060` kullanılır. Bütün ekranlar aynı arka plan, kart, başlık ve ikon ailesini paylaşır. Nunito değişken fontu, SIL Open Font License. Büyük başlıklar 26–30, kelime kutuları 23, gövde 14–17 mantıksal piksel. Butonlar 48–62 piksel. Köşeler 18–22 piksel. Bulanıklık, ekran yakalama shader'ı, gerçek zamanlı ışık ve pahalı gölge yoktur.

Kuş ve eski çizimler kaldırılmıştır. Yeni açık/koyu arka planlar, şeffaf Sözcük Zinciri logosu ve 12 simge yerleşik imagegen ile üretilmiştir. Dosyalar `assets/v2/` klasöründedir. [Görsel üretim notları](ASSETS-V2.md). Font lisansı `assets/FONT-LICENSE.txt`.

## Performans bütçesi

Oyun yalnızca 2D Control düğümleri kullanır. 30 FPS üst sınır; oyun mantığında sürekli `_process` veya fizik döngüsü yoktur. Sayaç yalnızca parti oynanırken saniyede bir çalışır. Konfeti 22 basit dörtgenden oluşur; kısa sürede temizlenir ve profil üzerinden kapatılabilir. Ekranlar değiştirilirken önceki düğümler ve animasyonlar temizlenir.

Arka planlar 512×768, simgeler 96×96, logo en fazla 600×440 WebP. Küçük arka planlar yaklaşık 6 ve 11 KB'dır. Godot texture import sıkıştırması kayıplı WebP, kalite 0.88; mipmap yoktur. Nunito yaklaşık 270 KB. Ok ve onay işaretleri için küçük bir DejaVu Sans alt kümesi kullanılır. Büyük üretim PNG'leri dağıtıma dahil edilmez. Yazı ve butonlar motorun yerel UI bileşenleridir; ekran görüntüsü olarak paketlenmez.

Kaydırma çubukları hem Godot'ta hem HTML'de gizlidir; kaydırma çalışır. Görünen bütün metin kutularını Godot çizer. HTML input'lar şeffaf klavye alanlarıdır; böylece kaydırırken ikinci bir kutu ve metin katmanı görünmez. Yalnızca kaydırma/boyut değişimi olaylarında konum güncellenir. Oyun sırasında aynı input sözcükler arasında korunur. Klavye açıldığında harf satırı görünür alana kaydırılır.

Web: single-thread export, GDExtension kapalı, VRAM sıkıştırma kapalı, ek CDN veya çalışma zamanı ağı yok. GitHub Pages'te özel COOP/COEP başlığı gerektirmez. Godot WebAssembly motoru ayrıca indirilir; bu boyut oyun çizimleriyle karıştırılmamalıdır. Motor 39.514.754 bayt; gzip aktarımı 10.054.758 bayttır. GitHub Pages özel sıkıştırma başlıkları sunmadığından modern tarayıcılarda DecompressionStream kullanılarak sıkıştırılmış motor akış hâlinde açılır ve WebAssembly derlemesine verilir. Bu API olmayan eski tarayıcılarda standart WASM dosyasına dönülür. Oyun PCK paketi yaklaşık 400 KB. PCK hash'i tarayıcı önbellek anahtarıdır; yeni sürümde eski oyun verisi gelmez, aynı motor dosyası tekrar kullanılır.

## İngilizceye hazırlık

İngilizce içerik veya dil düğmesi bu sürümde gösterilmez. Gelecekte arayüz metinleri TranslationServer'a, bölüm içerikleri dil başına ayrı JSON dosyalarına taşınabilir. Türkçe normalleştirme İngilizce cevaplara uygulanmamalıdır. Her dil için bağlantıların ayrı editoryal incelemesi gerekir.
