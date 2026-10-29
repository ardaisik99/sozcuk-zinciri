# V5 — Açılış yüklemesi

V4'ün ilk açılışında tam Godot motoru 10.054.758 B gzip olarak tek istekle indiriliyordu. Aynı bağlantıda bu dosyanın Python HTTP indirmesi 48,24 saniye sürdü. Küçük arka plan görseli 37.762 B olmasına rağmen, oyunun göründüğü ilk kare motor indirmesini bekliyordu. HTML de font ve manzara için ayrı istekler yapıyordu.

V5 yükleyicisi:

- Font ve orijinal net manzara HTML içinde sunulur; ilk yükleme görünümü için ayrı resim/font isteği yoktur.
- Destek varsa tarayıcının yerel Brotli açması kullanılır; destek yoksa gzip seçilir. Ek JavaScript sıkıştırma kitaplığı indirilmez. [Compression Streams biçimleri](https://developer.mozilla.org/en-US/docs/Web/API/DecompressionStream/DecompressionStream).
- Motor ve oyun paketi gzip olarak aktarılır. Sunucunun Range desteğiyle 256 KiB parçalar en fazla dört bağlantıda indirilir. Parçaların sırası, uzunluğu, dosya sürümü ve tamamının SHA-256 özeti doğrulanır.
- Yalnızca başarısız parça yeniden denenir. Eksik/bozuk dosya önbelleğe yazılmaz. Süre ve deneme sayıları sınırlıdır; hata arayüze bildirilir.
- Tamamlanan dosyalar Cache Storage'da saklanır. Güncellenmeyen motor sonraki açılışta yeniden indirilmez. Motor ve oyun içeriğinin kimliği ayrıdır; bölüm/UI güncellemesi motor indirmesini geçersiz kılmaz.
- Dosya adları içerik özetini taşır. Önceki ve güncel içerik sürümü tutulur. Özel mod/kota gibi saklama hataları oynamayı engellemez.
- Range desteklemeyen sunucuda tek tam indirme; DecompressionStream bulunmayan tarayıcıda ham dosya indirmesi kullanılır.
- Nunito'nun Türkçe/Latin karakterleri ve kullanılan semboller korunarak fontlar alt kümeye indirildi. Nunito TTF 276.932 → 98.936 B, mevcut küçük sembol fontu 5.084 → 4.256 B. Sembol alt kümesinin aile adı Zincir Symbols olarak değiştirildi. Tam lisanslar korunur.

İlk aşamanın canlı GitHub Pages ölçümü: standart motor + yeni yükleyici ile ilk ekran 18.399 ms; aynı içerik ve motor önbellekteyken 690 ms. Bu değerler test edilen bağlantı ve tarayıcıya aittir. Python dosya aktarım süresi ile tarayıcı hazır ekran süresi aynı ölçüm değildir.

Son yayın (`?v=5.1`, 30 Ekim 2026, 390 × 844 tarayıcı):

| Ölçüm | Süre |
| --- | ---: |
| İlk içerikli boyama, motor önbellekte değilken | 412 ms |
| Küçük motorla ilk hazır ekran | 3.773 ms |
| Aynı motor/içerikle tekrar hazır ekran | 743 ms |

Son ilk açılışta 4.630.972 B motor ve 227.766 B oyun verisi gzip olarak ağdan geldi. Tekrar açılışta iki dosya da Cache Storage'dan geldi; bunlar için ağ indirmesi yapılmadı. HTML/başlatıcı gibi küçük sayfa istekleri bu ifadeye dahil değildir. Ham kayıtlar [perf-loading-v5.json](perf-loading-v5.json) dosyasındadır. Süreler bu cihaz/bağlantıdaki ölçümdür; bütün cihazlara veya ağlara ait sabit süre garantisi değildir. Fiziksel iOS/Android cihazda ölçüm yapılmadı.

## Küçük Godot motoru

`scripts/lean_web.py` yalnızca GDScript, FreeType, basit metin sunucusu ve WebP modüllerini içerir. 3D, fizik, gezinme, XR, gelişmiş GUI ve kullanılmayan medya/ağ modülleri derlemeye alınmaz. Emscripten 4.0.11, tek iş parçacığı, yayın hedefi ve boyut optimizasyonu kullanılır. Türkçe Latin metni ve cihaz klavyesi korunur. Web motorunun fizik sınıflarına doğrudan bağımlılık kaldırılmıştır; standart editörde mevcut fizik sunucuları yine kapatılır.

Derleme kaynağı ve ayarlar `.github/workflows/lean-runtime.yml` içinde kayıtlıdır. Oyun testleri resmi Godot editöründe, küçük motorun gerçek çalışması ise tarayıcıda ayrıca kontrol edilir. Bu ayrım, kaldırılmış sınıf/modül hatalarının yalnızca editör testiyle gizlenmesini önler.

Yayın motoru 39.514.754 → **16.138.025 B** ham; 10.054.758 → **4.630.972 B** gzip. Yerel Brotli destekleyen tarayıcıda **3.661.226 B** aktarılır. Yeni kaynak, release SHA-256 ve WASM SHA-256 değerleri `scripts/web_runtime.json` dosyasına sabitlenmiştir. Yanlış standart motorla paketleme artık kontrol hatası verir.

Eski HTML/PCK önbellekleri yeni motora karışmasın diye sabit `index.*` adreslerinde önceki resmi motorun geçiş kopyası tutulur. V5 bu adresleri kullanmaz; yeni oyun yalnızca içerik özetli runtime/game dosyalarını ister. Yeniden dene düğmesi de eski HTML kaydını kullanmayan yeni bir sayfa isteği açar.

Küçük motorla yerel tarayıcıda menü/profil görünümü, Türkçe karakterler ve SU → BARDAK → ALTLIK → KUMAŞ öğreticisinin ekli girişlerle odak kaybetmeden tamamlanması doğrulandı. Konsolda hata yoktu. Yalnızca editör testine dayanılarak yayın yapılmadı.

Dayanak: [Godot boyut optimizasyonu](https://docs.godotengine.org/en/latest/engine_details/development/compiling/optimizing_for_size.html), [Godot Web derlemesi](https://docs.godotengine.org/en/latest/engine_details/development/compiling/compiling_for_web.html).

## Doğrulama

`tests/test_asset_loader.cjs` gerçek gzip verisiyle paralel parça birleştirme, eş zamanlı istek sınırı, tek parça yeniden deneme, SHA-256, sıfır ağ isteğiyle önbellek kullanımı, bozuk kayıt yenileme, sunucu Range geri dönüşü ve saklama izin/kota sorunlarını kapsar. Mevcut 2.744 maske ve oynanış testleri de korunur.
