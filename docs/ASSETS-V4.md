# V4 — Gün batımı arayüzü

Kullanıcının sunduğu “Pastel Türkçe Kelime Oyunu Arayüzü (1).png” görselinin kompozisyonu ve renk ailesi temel alındı. Menü, ilk isim kaydı, öğretici, bölümler, oyun, sonuç, parti, profil ve çevrim içi hazırlık ekranları aynı manzara ve panel sistemini kullanır. Gerçek bölüm sayıları, altın bakiyesi ve ödüller gösterilir. Çevrim içi ekran bağlantı kurulmadığını açıkça belirtir; sahte rakip skoru veya eşleşme yoktur.

## Varlıklar

Görseller imagegen ile üretildi. Pillow ile kırpma, alfa kenar temizliği, boyutlandırma ve WebP sıkıştırma uygulandı. Kaynak boyutlar yayın paketine eklenmedi. Panel, metin, ilerleme ve girişler Godot Control bileşenleridir. Nunito değişken yazı tipi Türkçe karakterlerle ve mevcut lisansıyla korunur.

| Dosya | Boyut | Diskte |
| --- | --- | ---: |
| `assets/v4/landscape.webp` | 640 × 960 | 37.762 B |
| `assets/v4/button_teal.webp` | 420 × 94 | 5.738 B |
| `assets/v4/button_purple.webp` | 420 × 94 | 5.860 B |
| `assets/v4/button_orange.webp` | 420 × 94 | 5.358 B |
| `assets/v4/button_gold.webp` | 420 × 94 | 5.366 B |
| `assets/v4/{user,party,versus,gear,star,gem}.webp` | her biri 96 × 96 | toplam 18.674 B |

Yeni görseller toplam **78.758 B**. Arka plan WebP kalite 86, butonlar 90, simgeler 92. Godot texture import: lossy 0.90, mipmap kapalı, GPU formatlarına ayrı kopya üretilmez. Butonlar StyleBoxTexture ile dokuz parçalı esnetilir; her boyut için ayrı görsel yoktur. Godot ve HTML yükleme ekranı aynı manzarayı kullanır. Eski v2 tam ekran görselleri, logolar ve kullanılmayan simgeler export dışında bırakıldı.

Oyun paketi **339.288 B**. Ortak Godot WASM motoru gzip ile **10.054.758 B** aktarılır (ham 39.514.754 B). Bu motor boyutu görsel paketinden ayrıdır. HTML loader için font ve 37.762 B manzara ayrıca sunulur; yayın toplamını yalnızca 339 KB olarak yorumlamamak gerekir.

## Üretim briefleri

### Manzara

Reference guided portrait 2:3 mobile-game illustration. Pastel lavender-blue sky, peach/coral/golden horizon, layered mauve/slate mountains on both sides, a serene lake leading into the foreground, faceted indigo rocks and stylized grasses at the lower corners. Calm crisp 2D geometric style, quiet sky and water for native interface overlays. Palette periwinkle #697FD3, peach #FFB58B, gold #FFD59B, lavender #AAA2D5, indigo #353F79. One continuous background; no UI, text, frames, people, mascots, watermark, blur or noise.

### Simgeler

Transparent 3-column × 2-row sprite sheet, six isolated icons with consistent rounded mobile-game styling: ivory person silhouette, group of three, crossed rounded swords; ivory gear, gold five-point reward star and amber diamond currency token. White icons minimal silhouettes, gold icons with small crisp facets/bevels. No labels, UI frames, birds, background or blur. Split, clean and contain each icon into a 96 × 96 asset.

### Butonlar

Transparent sprite sheet of four identical blank horizontal rounded button skins. Subtle lighter top rim and short darker bottom bevel, reference-matched polished casual 2D style. Teal #2CC5BD → #159FAD; violet #A06CF8 → #703CDF; orange #FFB449 → #FF7E2A; gold #FFD979 → #FFC43E. No text, icons, objects, background, noise or blur. Crop and resize into 420 × 94 nine-slice textures; all labels remain native Godot text.

## Kontroller

- 2.744 joker maskesi, görüntü/kabul eşitliği, Türkçe I varyasyonları ve kolaydan zora sıralama testleri geçti.
- Kayıt, ekonomi, tek sefer ödül, parti süresi/puanı ve animasyon sırasında aynı giriş alanının korunması testleri geçti.
- Tarayıcıda ÇİÇEK → BAL → ARI → KOVAN zinciri `alı`, `rısı`, `ovanı` girilerek yeniden dokunmadan tamamlandı.
- Öğretici SU → BARDAK → ALTLIK → KUMAŞ zinciri ekli cevaplarla (`ardağı`, `ltlığı`, `umaşı`) yeniden dokunmadan tamamlandı. Ekten köke kısa animasyon korunur.
- 390 × 844, 320 × 568 ve klavye açılmasını temsil eden 320 × 360 alan kontrol edildi. Son ölçüde odaklı kutular ekran içinde kaldı ve DOM giriş kutusu aynı konumu izledi. Gerçek iOS/Android cihaz klavyesi bu masaüstü kontrolünde fiziksel cihazda denenmedi.
- Yeni isim kaydı → öğretici yönlendirmesi ve sonuç → ana menü → bölümler yönlendirmeleri tarayıcıda doğrulandı. Konsolda çalışma hatası görülmedi.
- Daraltılmış parti formunda tarayıcının `overflow:hidden` giriş katmanını Godot'tan bağımsız kaydırdığı bulundu. `overflow:clip` ile bu ikinci kaydırma kaldırıldı. Odak değişiminde Godot alanı görünür hale getirir; DOM alanları Godot konumlarından tekrar eşlenir. 390 × 480 ekranda ikinci oyuncuya yazma ve Tab ile dördüncü oyuncuya ilerleme sonrası hem `#native-fields.scrollTop` hem `#stage.scrollTop` sıfır kaldı; görünen kart ile DOM alanının konumu eşleşti.

V3'ün asenkron kare zamanlaması, boşta yeniden çizim yapmama, kapalı fizik/3D ve DPR 2 sınırı korunur. Yeni tasarımda sürekli animasyon, shader, blur veya parçacık sistemi yoktur. Sonuç konfetisi 22 küçük öğeyle kısa sürede biter. Statik profil ekranında 65,009 saniyelik ölçümde 0 yeniden çizim, 0 WebGL çizim çağrısı, 0 yeni uzun görev ve %0,1331 ana döngü süre oranı ölçüldü. Örnek `perf-v4.json` dosyasındadır; burada ölçülen ana döngü süresi, bilgisayarın toplam CPU/GPU kullanımı değildir.
