# V3 — Hata ve güç tüketimi doğrulaması

## Giriş hatasının kökü

V2'de çizim fonksiyonu joker hücrelerine doğru harfi basarken doğrulama başka bir ham metni okuyordu. Örneğin `incani` + `[0,6]` açık hücreleri ekranda FİNCANI gösteriyor, doğrulama false dönüyordu. Bütün harfleri açılmış boş giriş de aynı durumda kalabiliyordu. V3 çizim ve doğrulamayı aynı çözülmüş harf durumuna bağlar. Joker sonrası hem Godot hem DOM metni birlikte güncellenir.

2.744 farklı joker maskesinde tam sözcük, ilk harfsiz devam, yalnızca boş hücreler ve hatalı/taşan metinler kontrol edilir. Ek olarak i/ı, ayrışık noktalı I, ücretli joker, kaldığı yerden devam, tekrar ödülü, animasyonlu otomatik geçiş, klavye alanı sürekliliği, zorluk sırası ve tek seferlik joker iadesi test edilir.

Tarayıcıda ayrıca EV → KAPI → ZİL → SES ve YEMEK → MASA → TENİS → TOP zincirleri ilk harfi tekrar yazmadan ve sonraki sözcüklere yeniden dokunmadan tamamlandı. Yazı sırasında joker kullanılıp sadece kalan boş hücrelerin girilmesi doğrulandı. Bildirilen KAHVE örneğinde jokerden sonra `incani` girişi otomatik kabul edildi; FİNCAN açıldı ve TAKIMI kutularına geçildi. Tarayıcı konsolunda bu akışlarda hata görülmedi.

Kayıt dosyası sayıları da yüklenirken tam sayıya çevrilir. Godot Array.has karşılaştırmasında int/float farkı yüzünden tamamlandı işaretlerinin, joker maskelerinin ve sıradaki bölümün kaybolması engellenir. JSON'a yazıp geri okuma testi bunu kapsar.

## Aynı bilgisayar ve aynı görünümde ölçüm

390×844 tuval, aynı tarayıcı, statik ana menü. Başlangıç yüklemesi dışarıda bırakılır. `?benchmark=1` isteğe bağlı yerel ölçümü açar; hiçbir ölçüm ağ üzerinden gönderilmez. RAF callback'lerinin toplam senkron süresi ve WebGL clear/draw çağrıları sayılır. Ham örnekler [perf-v3.json](perf-v3.json) dosyasındadır.

| Boşta ölçüm | V2 | V3 |
| --- | ---: | ---: |
| Örnekleme aralığı | 101,032 sn | 90,998 sn |
| Ana döngünün tuttuğu süre / geçen süre | %99,252 | %0,102 |
| Ekran temizleme / saniye | 30,000 | 0 |
| GPU çizim çağrısı / saniye | 990,013 | 0 |

Bu oran **bilgisayarın toplam CPU yüzdesi değildir**; oyun ana döngüsünün ana iş parçacığında tuttuğu süredir. GPU yüzdesi veya watt ölçülmemiştir; WebGL çizim çağrıları sayılmıştır. Fan sesi/cihaz sıcaklığı garantisi olarak yorumlanmamalıdır. Etkileşim ve animasyon sırasında yeni kareler doğal olarak çizilir.

## Güç düzeltmesi

Web ana iş parçacığında pozitif `Engine.max_fps`, Godot'un OS kare gecikmesine gidiyordu. Emscripten ana iş parçacığında bloklayan beklemeler busy-wait kullanabilir. FPS sınırı WASM içinde bekleyerek uygulanmaz: web'de 0, düşük işlemci modu sleep süresi 0; bekleme tarayıcı timer'larına bırakılır. Statik ekran düşük işlemci modunda tekrar çizilmez. Asenkron zamanlayıcı boşta yaklaşık 10 Hz, input/animasyonda en fazla 60 Hz çalışır; input geldiğinde boşta beklemesini hemen keser.

Dayanaklar: [Godot 4.7.2 Main::iteration](https://github.com/godotengine/godot/blob/4.7.2-stable/main/main.cpp), [OS kare gecikmesi](https://github.com/godotengine/godot/blob/4.7.2-stable/core/os/os.cpp), [Emscripten ana iş parçacığında bloklama](https://emscripten.org/docs/porting/pthreads.html#blocking-on-the-main-browser-thread).
