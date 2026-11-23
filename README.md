# Atölye

Android'de yerel geliştirme ortamı: **Claude Code** ve **Codex**, telefondaki Termux içinde kullanıcının
kendi hesabıyla çalışır; Atölye bunları terminal yerine zengin bir arayüzle kullanır. Sohbet Markdown
olarak çizilir, araç çağrıları kart olarak görünür, dosya değişiklikleri ve komutlar onay kartıyla sorulur,
ajanın ürettiği dosyalar (resim, PDF, Markdown, kod) uygulama içinde önizlenir.

Atölye hiçbir şeyi içine gömmez. Termux kendi resmi kaynağından, Codex resmi GitHub sürümünden, Claude Code resmi npm paketinden
kurulur; giriş her CLI'ın kendi akışıyla yapılır, Atölye hesap bilgisi görmez.

## Yapı

```
kopru/              Termux'ta çalışan köprü (Python, tek dosya)
  atolye_kopru.py   claude ve codex süreçlerini sürer, olayları ortak modele çevirir,
                    dosyaları sunar; yalnız 127.0.0.1, anahtarla
  kur.sh            Termux kurulumu: paketler, ajanlar, köprü, allow-external-apps
uygulama/           Flutter uygulaması (Android; masaüstü ve web yalnız geliştirme için)
  lib/servis/       köprü istemcisi, Termux kanalı, kurulum sunucusu, ayarlar
  lib/model/        Calisma (uygulama durumu), Sohbet (oturum olayları)
  lib/ekran/        kurulum sihirbazı, ana düzen, sohbet, dosyalar, önizleme
  lib/arayuz/       Markdown çizici (Folio'dan), ekran sınıfı ve menteşe düzeni
  android/.../MainActivity.kt   Termux'u bulma, açma, RUN_COMMAND izni ve çağrısı
```

### Köprü protokolleri

- **Claude Code:** `claude -p --input-format stream-json --output-format stream-json --verbose
  --include-partial-messages --permission-prompt-tool stdio`. Onaylar `control_request`
  (`can_use_tool`) olarak gelir, `control_response` ile yanıtlanır. Oturum `--resume` ile sürer.
- **Codex:** `codex app-server` (JSON-RPC). `thread/start|resume`, `turn/start`, çalışırken araya yazılan
  mesaj `turn/steer`, durdurma `turn/interrupt`. Onaylar `item/commandExecution/requestApproval` ve
  `item/fileChange/requestApproval` sunucu istekleri olarak gelir.

Bu sürücüler Saçmalık Odası'ndakilerden türetildi.

### Uygulama ↔ köprü

WebSocket `ws://127.0.0.1:8765`, JSON. İlk mesaj `{"op":"hello","token":…}`. İstekler `no` ile eşlenir;
köprü olayları (`metin`, `parca`, `arac`, `arac_sonuc`, `onay`, `dosya`, `bitti`, `durum`, `kota`…)
yayınlar ve her oturumun olaylarını `~/.atolye/kayit/<id>.jsonl` dosyasına yazar; uygulama yeniden
açılınca geçmiş buradan gelir. Dosyalar aynı porttan `GET /dosya?yol=…&t=<anahtar>` ile sunulur;
çalışma kökünün (`~/projeler`) dışı reddedilir.

## Kurulum akışı (telefonda)

1. Kullanıcı ajanları seçer, kurulacaklar listelenir, onay alınır.
2. Termux yoksa Atölye resmi GitHub sürümünden cihazın mimarisine uygun APK'yı indirir,
   sürümle yayımlanan SHA-256 özetiyle doğrular ve Android'in yükleme ekranını açar
   ("Bilinmeyen uygulamaları yükle" izni bir kez istenir). Kurulum bitince Atölye Termux'u
   algılayıp sonraki adıma kendisi geçer. İstenirse F-Droid sürümü de kurulabilir.
3. Atölye `kur.sh` ve köprüyü telefonun içinden (127.0.0.1, rastgele port ve yol) sunar; tek satırlık
   komutu panoya kopyalar ve Termux'u açar. Kullanıcı yapıştırır, kurulum biter, köprü başlar.
4. `RUN_COMMAND` izni istenir (köprüyü yeniden başlatmak ve giriş ekranlarını açmak için).
5. Giriş: Termux'ta `claude` ya da `codex login` açılır.

Termux'a dışarıdan komut gönderilebilmesi için `allow-external-apps = true` gerekir; bunu kurulum
scripti yapar. Bu yüzden ilk adımdaki tek yapıştırma kaçınılmazdır.

## Neler yapılabiliyor

- **Sohbet:** Markdown yanıtlar, araç adımları tek "etkinlik" satırında, düzenlemeler ve onaylar
  kırmızı/yeşil diff olarak, çalışırken araya mesaj yazma, durdurma, dosya ekleme.
- **Başlangıç ekranı:** proje, ajan, çalışma biçimi ve konum (bu cihaz ya da SSH sunucusu) seçip
  tek adımda başlatma; hazır görevler; proje kartları; GitHub'dan klonlama.
- **Dosyalar:** bu oturumda değişenler, klasör gezgini; önizleme: resim, SVG, PDF, ses, video,
  Word/PowerPoint (Markdown'a çevrilerek), Excel/CSV (tablo), HTML, Markdown, kod. Her dosya
  başka bir uygulamada açılabilir ya da paylaşılabilir.
- **Git:** dal, ileri/geri, değişen dosyalar ve diff'leri, commit (ya da "ajana yaptır"),
  push/pull, GitHub'da PR (gh).
- **Ayarlar:** GitHub girişi (gh, Termux'ta tarayıcıyla), SSH anahtarı oluşturma/kopyalama ve
  GitHub'a ekleme, SSH sunucuları (ekle, dene, sil), tema.
- **Uzak oturum:** ajan SSH ile kayıtlı bir sunucuda çalışır (`ssh … bash -lc 'cd … && exec claude …'`);
  sohbet, onaylar ve diff'ler aynı arayüzde. Uzak dosya önizleme ve Git paneli henüz yok.

## Ekran düzenleri

| Genişlik | Cihaz | Düzen |
|---|---|---|
| < 600 | telefon, kapalı katlanır | sohbet tam ekran; oturumlar ve dosyalar çekmece; önizleme tam sayfa |
| 600–840 | açık katlanır, küçük tablet | oturumlar \| sohbet; dosyalar çekmece |
| ≥ 840 | tablet | oturumlar \| sohbet \| dosyalar ya da önizleme |
| dikey menteşe | kitap duruşunda katlanır | sohbet \| dosyalar/önizleme, menteşeye göre bölünür |

Durum `Calisma` nesnesinde tutulur; katlayıp açınca ya da döndürünce sohbet kesilmez
(`configChanges` ve `resizeableActivity`).

## Geliştirme

```bash
cd uygulama && flutter analyze && flutter test
```

Köprüyü masaüstünde denemek ve uygulamayı ona bağlamak için:

```bash
python3 -m pip install websockets
python3 kopru/atolye_kopru.py --token-goster
python3 kopru/atolye_kopru.py
```

Android dışında uygulama "Elle bağlan" ekranını açar: port ve anahtar girilir.

`kopru/` altındaki dosyalar değişince uygulamanın kurulum varlıklarını eşitle (test bunu denetler):

```bash
uygulama/tool/esitle.sh
```

## Android derlemesi ve imza

```bash
cd uygulama && flutter build apk --release --split-per-abi
```

Çıktılar `uygulama/build/app/outputs/flutter-apk/` altında; telefonların çoğu için
`app-arm64-v8a-release.apk`.

Release imzası depoda değildir: anahtar `~/atolye-imza-yedek/atolye-release.jks`, şifreler
`uygulama/android/key.properties` dosyasında (git'e girmez; yedeği anahtarın yanında). Bu dosya
yoksa release derlemesi debug anahtarıyla imzalanır. Yayımlanan her sürüm aynı anahtarla
imzalanmalı; Android güncellemeyi yalnız aynı imzanın üstüne kurar. Anahtar kaybolursa uygulama
kaldırılmadan güncellenemez, bu yüzden klasörü güvenli bir yere yedekle.

Sertifika SHA-256: `0F:61:61:69:52:D5:1B:CA:A8:2E:B5:40:80:91:A9:33:32:91:98:5A:28:6C:27:80:4E:12:67:F6:9C:DD:5B:1E`

## Bilinen sınırlar ve sıradakiler

- Termux'ta Node "android" platformu görünür, ajan paketleri ise linux programı taşır:
  - **Codex** resmi GitHub sürümündeki Linux musl ikilisinden kurulur (arm64 veya x86_64).
    Kurulum arşivin SHA-256 özetini doğrular. Termux'ta etkileşimli kullanım için `codex --no-daemon` çalıştırılabilir.
  - **Claude Code** resmi `@anthropic-ai/claude-code-linux-arm64` paketinden indirilir, yükleyicisi
    Termux'un `glibc-repo` deposundaki glibc'ye `patchelf` ile yönlendirilir
    (`~/.atolye/claude/claude`, başlatıcı `$PREFIX/bin/claude`). Termux'un bionic `LD_PRELOAD`'ı
    glibc sürecine yüklenemediği için başlatıcı onu kaldırır, Claude'un açtığı kabuklara `BASH_ENV`
    ile geri verir. Kendi kendini güncelleme kapalıdır; güncellemek için kurulum komutu yeniden
    çalıştırılır. Bu yol bilgisayarda taklit edilerek denendi, telefonda doğrulanmalı.
- Android 12+ arka plan süreç sınırı (phantom process killer): köprü `termux-wake-lock` alır, yine de
  pil optimizasyonunun kapatılması önerilir.
- Folio'nun DOCX/XLSX önizleyicileri henüz alınmadı; şimdilik resim, PDF, Markdown ve metin önizlenir.
- Lisans: köprü sürücüleri GPLv3 Saçmalık Odası'ndan, Markdown çizici tescilli Folio'dan türetildi;
  Atölye dağıtılmadan önce lisansı belirlenmeli.
