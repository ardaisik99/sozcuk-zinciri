# Görsel varlıklar — Sürüm 2

Yöntem: yerleşik imagegen. Kullanıcının üç ekranı stil referansıdır; hiçbir referans ekran oyuna ekran görüntüsü olarak eklenmez. Kodla çizilmiş maskot veya organik arka plan yoktur. Bitmap'ler küçük WebP'lere dönüştürülür; buton ve yazılar Godot UI bileşenidir.

Üretim brief'leri:

1. `assets/v2/background.webp`: “Portrait 2:3 mobile game background only. Warm white empty center, cropped organic violet/lavender and golden yellow waves hugging corners, tiny edge sparkles. Crisp 2D finish. No text, logo, buttons, phone, bird or character.”
2. `assets/v2/splash.webp`: “Portrait 2:3 loading background only. Deep royal violet center, vivid purple organic edge blobs, golden yellow waves, restrained dots and sparkles. Keep middle empty. No text, logo, phone, bird or character. No blur.”
3. `assets/v2/logo.webp`: “Transparent production logo, exact two-line Turkish text Sözcük / Zinciri. Chunky rounded extra-bold slightly slanted typography. Top vivid purple, bottom golden yellow, small purple/gold interlocking chain below. No mascot, phone or other text.”
4. `assets/v2/logo_dark.webp`: “Loading-screen variant of the same logo. Change only the top word Sözcük to ivory white, preserve exact spelling, geometry, yellow Zinciri and chain. Transparent background.”
5. `assets/v2/icon_*.webp`: “Transparent 4-column 3-row UI icon atlas. Purple play, two people, three people, folder; gear, outline user, golden lightbulb, gold star coin; orange tea cup, green leaf, open book, interlocking chain. Consistent rounded silhouettes, clean at 24px. No text, avatar portrait, bird, grid or phone.”

Arka planlar 512×768, simgeler 96×96, logolar en fazla 600×440. Alfa kanalının dışındaki boş paylar kırpılır. Godot import: lossy WebP 0.88, mipmaps kapalı. Özgün üretim PNG'leri kaynak depoya veya web dağıtımına eklenmez.
