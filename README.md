# Sözcük Zinciri

Godot 4.7.2 ile Türkçe, dikey mobil kelime bulmaca. 24 bölüm, üç kategori, profil ve ilerleme kaydı, jokerler, oynanabilir öğretici ve aynı cihazda 2–4 kişilik parti modu. Sürüm 2: referanslara uygun mor-sarı tasarım, doğrudan kutulara yazma, ilk harfi tekrar yazmadan otomatik ilerleme ve “BARDAĞI → BARDAK” dönüşümü. Avatar seçimi yoktur.

## Çalıştırma

Godot'ta `project.godot` dosyasını açıp F6 yerine F5 ile ana sahneyi çalıştırın. Ek paket veya API anahtarı gerekmez.

Web için aynı Godot sürümünün export template paketini yükleyin:

```powershell
godot --headless --path . --export-release Web web/index.html
python scripts/package_web.py
python -m http.server 8765 --directory web
```

Web çıktısı `file://` üzerinden çalıştırılmaz; HTTP/HTTPS gerekir. GitHub Actions her main push'unda web çıktısını üretir ve Pages'e yayınlar. Motor binary'leri Git deposuna eklenmez.

## Doğrulama

```powershell
godot --headless --path . --script tests/test_state.gd
godot --headless --path . --script tests/test_flows.gd
```

[Oyun tasarımı ve performans kararları](docs/TASARIM.md). Çevrim içi yarış bu sürümde bağlı değildir. APK/IPA çıktısı hazırlanmaz.

Web giriş köprüsü `scripts/web_input.js` içindedir. Görünen bütün alanları Godot çizer; şeffaf DOM girdileri yalnızca cihazın klavyesi içindir. Aynı DOM alanı sonraki sözcüklerde korunur. `data/levels.json` içindeki `forms` ekli biçimleri, `words` ise kökleri tanımlar. Gelişigüzel ek kesme algoritması kullanılmaz.
