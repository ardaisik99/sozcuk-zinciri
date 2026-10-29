# Sözcük Zinciri

Godot 4.7.2 ile Türkçe, dikey mobil kelime bulmaca. 24 bölüm, üç kategori, profil ve ilerleme kaydı, jokerler, oynanabilir öğretici ve aynı cihazda 2–4 kişilik parti modu.

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
