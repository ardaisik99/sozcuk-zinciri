# Sözcük Zinciri

Godot 4.7.2 ile Türkçe, dikey mobil kelime bulmaca. 24 bölüm, üç kategori, profil ve ilerleme kaydı, jokerler, oynanabilir öğretici ve aynı cihazda 2–4 kişilik parti modu. Sürüm 4: gün batımı manzarası, beyaz paneller, turkuaz/mor/turuncu butonlar ve yatay zincir kartları. Kutulara doğrudan yazma, ilk harfi tekrar yazmadan otomatik ilerleme ve “BARDAĞI → BARDAK” dönüşümü korunur.

## Çalıştırma

Godot'ta `project.godot` dosyasını açıp F6 yerine F5 ile ana sahneyi çalıştırın. Ek paket veya API anahtarı gerekmez.

Web için küçük, doğrulanmış Godot şablonunu kurun:

```powershell
python -m pip install brotli
python scripts/install_web_template.py
godot --headless --path . --export-release Web web/index.html
python scripts/package_web.py
python -m http.server 8765 --directory web
```

Web çıktısı `file://` üzerinden çalıştırılmaz; HTTP/HTTPS gerekir. GitHub Actions her main push'unda web çıktısını üretir ve Pages'e yayınlar. Motor binary'leri Git deposuna eklenmez.

## Doğrulama

```powershell
godot --headless --path . --script tests/test_state.gd
godot --headless --path . --script tests/test_flows.gd
python scripts/check_project.py godot
```

[Oyun tasarımı ve performans kararları](docs/TASARIM.md). Çevrim içi yarış bu sürümde bağlı değildir. APK/IPA çıktısı hazırlanmaz.

Web giriş köprüsü `scripts/web_input.js` içindedir. Görünen bütün alanları Godot çizer; şeffaf DOM girdileri yalnızca cihazın klavyesi içindir. Aynı DOM alanı sonraki sözcüklerde korunur. `data/levels.json` içindeki `forms` ekli biçimleri, `words` ise kökleri tanımlar. Gelişigüzel ek kesme algoritması kullanılmaz.

V3: joker sonrası görüntü/doğrulama aynı çözücüyü kullanır, i/ı klavye farkı tolere edilir. Bölümler sabit içerik kimlikleri korunarak `order` ile kolaydan zora sıralanır. Web'de bloklayan FPS beklemesi kaldırılmıştır. [Ölçüm raporu](docs/PERFORMANCE-V3.md).

V4 görselleri, üretim briefleri, sıkıştırma boyutları ve tarayıcı kontrolleri: [V4 tasarım ve varlık notları](docs/ASSETS-V4.md). [Web sürümü](https://ardaisik99.github.io/sozcuk-zinciri/?v=4).

V5: küçük yayın motoru, paralel ve doğrulanan parça indirme, motor/içerik için ayrı kalıcı önbellek ve HTML içine alınmış ilk ekran görselleri. [Yükleme raporu](docs/LOADING-V5.md), [güncel web sürümü](https://ardaisik99.github.io/sozcuk-zinciri/?v=5.1). Şablon GitHub sürümünden SHA-256 ile doğrulanır; oyun güncellemeleri motorun yeniden indirilmesini gerektirmez.
