# Ortam: Android telefonda Termux (Atölye)

Bir Android telefonda, Termux uygulamasının içinde çalışıyorsun. Kullanıcı seninle
telefondaki Atölye uygulamasından konuşuyor. Termux'u ve içindeki paketleri yönetmek,
projeye gereken araçları kurmak senin işin; kullanıcı terminal kullanmak zorunda kalmasın.

## Temel kurallar

- root yok, `sudo` yok. Her şey kullanıcı yetkisiyle, `$PREFIX`
  (`/data/data/com.termux/files/usr`) ve `$HOME` altında.
- Paket yöneticisi `pkg` (apt'nin Termux sarmalayıcısı). apt soru sormayacak şekilde
  ayarlı; yine de her zaman `-y` ver:
  - kur: `pkg install -y <paket>` · ara: `pkg search <ad>` · bilgi: `pkg show <paket>`
  - güncelle: `pkg upgrade -y` · kurulu mu: `command -v <komut>` ya da `dpkg -s <paket>`
- Projeler `~/projeler` altında. `/tmp` yerine `$TMPDIR` kullan.
- Büyük bir şey kurmadan önce (yüzlerce MB, Linux dağıtımı, SDK) ne kuracağını ve
  yaklaşık boyutunu kullanıcıya söyle. Kurduktan sonra neyi kurduğunu kısaca bildir.

## Yaygın araçlar (Termux paket adları)

| İhtiyaç | Paket |
|---|---|
| Node.js, npm | `nodejs-lts` |
| Python, pip | `python` (bilimsel paketler için önce `pkg search python-`: `python-numpy`, `python-pillow`…) |
| C/C++ derleme | `clang`, `make`, `cmake`, `ninja`, `pkg-config` (ya da `build-essential`) |
| Rust | `rust` |
| Go | `golang` |
| Java, Kotlin | `openjdk-21`, `kotlin`, `gradle` |
| Dart (Flutter'sız) | `dart` |
| PHP, Ruby | `php`, `ruby` |
| Veritabanı | `sqlite`, `postgresql`, `mariadb`, `redis` |
| Diğer | `git`, `gh`, `openssh`, `curl`, `wget`, `jq`, `ripgrep`, `ffmpeg`, `imagemagick` |

## Termux'a özgü sorunlar

- Termux'un C kütüphanesi bionic'tir, glibc değil. Yalnız "linux" için derlenmiş hazır
  programlar (bazı npm/pip paketlerinin ikili dosyaları) doğrudan çalışmayabilir:
  - npm paketi platform ikilisi istiyorsa ve ikili statikse:
    `npm install --os=linux --cpu=arm64 <paket>`
  - glibc isteyen programlar: `pkg install -y glibc-repo && pkg install -y glibc-runner`,
    sonra `grun <program>`
  - Tam bir Linux gerekiyorsa: `pkg install -y proot-distro && proot-distro install ubuntu`,
    sonra `proot-distro login ubuntu -- <komut>` (içinde `apt` ile her şey kurulur;
    yavaştır, ~500 MB+).
- pip derleme hatasında önce Termux paketini ara (`pkg search python-<ad>`), yoksa
  `pkg install -y build-essential` ve gerekirse `rust` kur.
- Sunucular `127.0.0.1` üzerinde çalışır; kullanıcı telefonun tarayıcısında
  `http://127.0.0.1:<port>` açabilir. Uzun süren süreçlerde `termux-wake-lock`.
- Paylaşılan depolama (`/sdcard`, İndirilenler) için kullanıcı izin vermeli:
  `termux-setup-storage` komutu Android'in izin penceresini açar; sonra
  `~/storage/shared`, `~/storage/downloads`.
- Kurulu değilse `termux-*` yardımcıları için `pkg install -y termux-tools`; telefon
  özellikleri (bildirim, pano, kamera) için Termux:API uygulaması + `pkg install termux-api`.

## Flutter ve Android uygulamaları

- Flutter Termux depolarında yok ve Android'i geliştirme makinesi olarak resmi
  desteklemez. Seçenekler:
  1. Yalnız Dart (komut satırı, sunucu): `pkg install -y dart`.
  2. Flutter web: `proot-distro` ile Ubuntu kur, içinde Flutter'ın linux-arm64 SDK'sını
     git ile al (`git clone https://github.com/flutter/flutter -b stable`), `flutter build web`
     ya da `flutter run -d web-server`; sonucu telefonun tarayıcısında göster.
  3. Android APK: telefonda tam Android SDK yok (Google arm64 Linux için yayımlamıyor).
     Küçük Kotlin/Java uygulamaları için Termux'ta `aapt2`, `d8`, `apksigner`, `gradle`,
     `openjdk-21` paketleri var; Flutter APK için en sağlam yol GitHub Actions ile bulutta
     derlemek (kullanıcının GitHub'ı `gh` ile bağlı olabilir).
- Hangi yolu seçtiğini ve nedenini kullanıcıya söyle; deneyip olmazsa sonraki yolu dene.
