# Atölye

Android'de yerel geliştirme ortamı: **Claude Code** ve **Codex**, telefondaki Termux içinde kullanıcının
kendi hesabıyla çalışır; Atölye bunları terminal yerine zengin bir arayüzle kullanır. Sohbet Markdown
olarak çizilir, araç çağrıları kart olarak görünür, dosya değişiklikleri ve komutlar onay kartıyla sorulur,
ajanın ürettiği dosyalar (resim, PDF, Markdown, kod) uygulama içinde önizlenir.

Atölye hiçbir şeyi içine gömmez. Termux kendi resmi kaynağından, Codex Termux paket deposundan, Claude Code resmi npm paketinden
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

Kullanıcı Termux'a **yalnızca bir kez, kısa tek bir satır** yapıştırır; kurulumun geri kalanı ve
girişler Atölye'nin içinde, Termux açılmadan yürür.

1. Kullanıcı ajanları seçer, kurulacaklar listelenir, onay alınır.
2. Termux yoksa Atölye resmi GitHub sürümünden cihazın mimarisine uygun APK'yı indirir,
   sürümle yayımlanan SHA-256 özetiyle doğrular ve Android'in yükleme ekranını açar
   ("Bilinmeyen uygulamaları yükle" izni bir kez istenir). Kurulum bitince Atölye Termux'u
   algılayıp sonraki adıma kendisi geçer. İstenirse F-Droid sürümü de kurulabilir.
3. **Önyükleme (Termux'ta, tek yapıştırma).** Atölye `kur.sh` ve köprüyü telefonun içinden
   (127.0.0.1, rastgele port ve yol) sunar; panoya `curl -fsS http://127.0.0.1:PORT/GIZLI | bash`
   kopyalar ve Termux'u açar. Sunucu betiğin başına token ve ajan seçimini gömer. Betik köprüyü
   ve rehberi hemen indirir (uygulama arka plana düşse de), `allow-external-apps = true` yazar,
   depoları günceller, Python'u kurar, köprüyü başlatır ve `am start` ile Atölye'ye geri döner.
4. **Paketler ve ajanlar (uygulamada, canlı).** Uygulama `kur` işlemiyle betiği köprüye gönderir
   (`--asama paketler`); köprü onu çocuk süreç olarak çalıştırır ve çıktıyı `kurulum` olaylarıyla
   akıtır: adımlar, ilerleme, hata. Node.js, Git, GitHub CLI, OpenSSH ve seçilen ajanlar kurulur;
   Claude Code resmi linux paketi + Termux glibc ile, Codex Termux paketiyle. Eksik yoksa adım atlanır.
5. İzinler: `RUN_COMMAND` (köprü kapanırsa Atölye açabilsin) ve Termux için pil kısıtlamasını kaldırma.
6. **Giriş (uygulamada).** `giris_baslat` işlemi CLI'ın giriş komutunu köprüde çalıştırır
   (`claude auth login`, `codex login --device-auth`, `gh auth login --web`); adres ve cihaz kodu
   `giris` olaylarıyla gelir, uygulama tarayıcıyı açar, kodu panoya kopyalar. Claude bir kod isterse
   uygulamadaki kutudan `giris_kod` ile gönderilir. Kimlik bilgilerine Atölye dokunmaz.

Sonradan ajan kurmak/güncellemek, köprüyü güncellemek (`kopru_guncelle`: uygulamadaki köprü dosyasını
köprü kendisi yazıp yeniden başlar) ve girişi yenilemek Ayarlar'dan aynı işlemlerle yapılır. Köprü
bir işlemi bilmiyorsa (`durum` yanıtındaki `yetenekler` listesinde yoksa) uygulama eski yola, Termux
penceresine düşer.

Termux'a dışarıdan komut gönderilebilmesi için `allow-external-apps = true` gerekir ve bu dosyayı
yalnızca Termux'un içinden yazmak mümkündür; ilk yapıştırma bu yüzden kaçınılmazdır. Bu, Termux'un
bilerek koyduğu bir güvenlik kapısıdır; aşılmaz.

## Neler yapılabiliyor

- **Sohbet:** Markdown yanıtlar, araç adımları tek "etkinlik" satırında, düzenlemeler ve onaylar
  kırmızı/yeşil diff olarak, çalışırken araya mesaj yazma, durdurma, dosya ekleme.
- **Başlangıç ekranı:** proje, ajan, çalışma biçimi ve konum (bu cihaz ya da SSH sunucusu) seçip
  tek adımda başlatma; proje kartları; GitHub'dan klonlama.
- **Dosyalar:** bu oturumda değişenler, klasör gezgini; önizleme: resim, SVG, PDF, ses, video,
  Word/PowerPoint (Markdown'a çevrilerek), Excel/CSV (tablo), HTML, Markdown, kod. Her dosya
  başka bir uygulamada açılabilir ya da paylaşılabilir.
- **Git:** dal, ileri/geri, değişen dosyalar ve diff'leri, commit (ya da "ajana yaptır"),
  push/pull, GitHub'da PR (gh).
- **Ayarlar:** ajanlar (kur, güncelle, giriş), GitHub girişi (uygulama içinde), SSH anahtarı oluşturma/kopyalama ve
  GitHub'a ekleme, SSH sunucuları (ekle, dene, sil), tema.
- **Uzak oturum:** ajan SSH ile kayıtlı bir sunucuda çalışır (`ssh … bash -lc 'cd … && exec claude …'`);
  sohbet, onaylar ve diff'ler aynı arayüzde. Uzak dosya önizleme ve Git paneli henüz yok.
- **Sesli konuşma (Codex):** sohbetteki mikrofon düğmesi Codex'in realtime sesini açar. Ses
  WebRTC ile doğrudan telefonla OpenAI arasında akar; köprü yalnızca SDP teklifini
  `thread/realtime/start` ile Codex'e iletir. Konuşma sohbetin thread'ine bağlıdır: sesle istenen
  iş Codex'e devredilir, Codex aynı projede çalışır, araçlar ve onaylar sohbette görünür (onaylar
  dokunarak verilir). "Kapat/yeter/görüşürüz" ya da 60 sn sessizlik konuşmayı bitirir.
  Codex'in deneysel API'sidir (`experimentalApi`); yalnızca bu cihazdaki Codex oturumlarında.
- **Bulutta APK derleme:** Git panelinde, GitHub'daki bir Flutter projesi için. "İş akışını ekle"
  `.github/workflows/atolye-apk.yml` yazar (arm64 release APK, `apk` yapıtı); "İmza anahtarını
  kur" openssl ile kalıcı bir PKCS12 anahtarı üretir (yedeği `~/.atolye/imza/`), `gh secret set`
  ile depoya koyar, iş akışı APK'yı `apksigner` ile imzalar; böylece yeni sürüm eskisinin
  üstüne kurulur. "Derle" `gh workflow run` ile başlatır (ajan da başlatabilir); bitenler
  listede "Kur" ile indirilir (`gh run download`) ve Android'in yükleme ekranı açılır.
- **Uygulama içi önizleme:** ajanın başlattığı geliştirme sunucusu (Vite, Flask, http.server…)
  Atölye'nin içinde WebView'da açılır: sohbetteki `localhost`/`127.0.0.1` bağlantıları, HTML
  dosyaları ve oturum menüsündeki "Yerel sunucuyu önizle" (yaygın portları tarar, port elle de
  yazılır). WebView olmayan platformlarda tarayıcıda açılır.
- **Paylaş menüsü:** başka bir uygulamadan metin, bağlantı, ekran görüntüsü ya da dosya
  "Atölye"ye paylaşılınca hedef sorulur (açık oturum, son oturumlar, yeni oturum); metin yazma
  kutusuna, dosyalar ek olarak gelir. Gönderme kullanıcıdadır.

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

Android dışında uygulama "Elle bağlan" ekranını açar: port ve anahtar girilir. Termux'a özgü
arayüzleri (kurulum paneli, ajan kur/güncelle) masaüstünde görmek için
`flutter build web --dart-define=ATOLYE_TERMUX_DENE=true`; köprüyü de sahte bir `PREFIX`, sahte
`pkg`/`apt-get` betikleri ve geçici `HOME`, `CODEX_HOME`, `CLAUDE_CONFIG_DIR` ile başlat.

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
  - **Codex** Termux paket deposundan `pkg install codex` ile kurulur.
    Termux'ta etkileşimli kullanım için `codex --no-daemon` çalıştırılabilir.
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
