# Atölye

Android'de yerel geliştirme ortamı: **Claude Code** ve **Codex**, telefondaki Termux içinde kullanıcının
kendi hesabıyla çalışır; Atölye bunları terminal yerine zengin bir arayüzle kullanır. Sohbet Markdown
olarak çizilir, araç çağrıları kart olarak görünür, dosya değişiklikleri ve komutlar onay kartıyla sorulur,
ajanın ürettiği dosyalar (resim, PDF, Markdown, kod) uygulama içinde önizlenir.

Atölye hiçbir şeyi içine gömmez. Termux kendi resmi kaynağından, ajanlar kendi resmi npm paketlerinden
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
2. Termux yoksa F-Droid ya da GitHub sayfası açılır; dönünce Atölye Termux'u algılar.
3. Atölye `kur.sh` ve köprüyü telefonun içinden (127.0.0.1, rastgele port ve yol) sunar; tek satırlık
   komutu panoya kopyalar ve Termux'u açar. Kullanıcı yapıştırır, kurulum biter, köprü başlar.
4. `RUN_COMMAND` izni istenir (köprüyü yeniden başlatmak ve giriş ekranlarını açmak için).
5. Giriş: Termux'ta `claude` ya da `codex login` açılır.

Termux'a dışarıdan komut gönderilebilmesi için `allow-external-apps = true` gerekir; bunu kurulum
scripti yapar. Bu yüzden ilk adımdaki tek yapıştırma kaçınılmazdır.

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

## Bilinen sınırlar ve sıradakiler

- Telefonda henüz denenmedi: Claude Code ve Codex'in Termux'ta (Android, bionic) npm ile çalışması
  cihazda doğrulanmalı. Çalışmazsa kurulum scripti uyarır; glibc/proot yolu gerekebilir.
- Android 12+ arka plan süreç sınırı (phantom process killer): köprü `termux-wake-lock` alır, yine de
  pil optimizasyonunun kapatılması önerilir.
- Folio'nun DOCX/XLSX önizleyicileri henüz alınmadı; şimdilik resim, PDF, Markdown ve metin önizlenir.
- Lisans: köprü sürücüleri GPLv3 Saçmalık Odası'ndan, Markdown çizici tescilli Folio'dan türetildi;
  Atölye dağıtılmadan önce lisansı belirlenmeli.
