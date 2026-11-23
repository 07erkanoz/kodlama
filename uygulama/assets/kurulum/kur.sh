#!/data/data/com.termux/files/usr/bin/bash
# Atölye kurulumu — Termux içinde çalışır.
#
# Uygulama bu scripti telefonun kendi içinden (127.0.0.1) sunar; kullanıcı
# Termux'a tek satırı yapıştırır:
#   pkg install -y curl && curl -fsS http://127.0.0.1:PORT/ANAHTAR/kur.sh | bash -s -- --token T --ajan claude,codex
#
# Yaptıkları (her biri ekranda yazılır):
#   1. Termux paketleri: python, nodejs, git
#   2. Seçilen ajanlar resmi npm paketlerinden: Codex linux-arm64 paketiyle,
#      Claude Code resmi linux paketi + Termux glibc deposuyla
#   3. Atölye köprüsü (~/.atolye/kopru) ve "atolye-kopru" komutu
#   4. Uygulamanın Termux'a komut gönderebilmesi için allow-external-apps
# Hiçbir hesap bilgisi istenmez; giriş her CLI'ın kendi akışıyla yapılır.

set -euo pipefail

KAYNAK="${ATOLYE_KAYNAK:-}"
TOKEN=""
AJANLAR="claude"
while [ $# -gt 0 ]; do
  case "$1" in
    --token) TOKEN="$2"; shift 2 ;;
    --ajan) AJANLAR="$2"; shift 2 ;;
    --kaynak) KAYNAK="$2"; shift 2 ;;
    *) echo "bilinmeyen seçenek: $1" >&2; exit 2 ;;
  esac
done

adim() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
tamam() { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
uyar() { printf '\033[1;33m! %s\033[0m\n' "$*"; }

if [ -z "${PREFIX:-}" ] || [ ! -d "$PREFIX" ]; then
  echo "Bu script Termux içinde çalışmalı." >&2
  exit 1
fi

# Sorusuz apt: yükseltmede "yapılandırma dosyası değişti" sorusunda takılmasın.
export DEBIAN_FRONTEND=noninteractive
APT=(apt-get -y -o Dpkg::Options::=--force-confnew)

adim "Termux depoları güncelleniyor (apt update)"
if ! pkg update -y; then
  uyar "depo güncellenemedi. İnternet bağlantısını kontrol et ya da 'termux-change-repo' ile başka bir ayna seç, sonra komutu yeniden çalıştır."
  exit 1
fi

adim "Paketler yükseltiliyor (apt upgrade)"
"${APT[@]}" full-upgrade || uyar "bazı paketler yükseltilemedi, devam ediliyor"

# Ajanlar da paket kuracak: apt her zaman sorusuz çalışsın, kullanıcının
# değiştirdiği yapılandırma dosyaları korunsun.
mkdir -p "$PREFIX/etc/apt/apt.conf.d"
cat > "$PREFIX/etc/apt/apt.conf.d/99atolye" <<'APT'
// Atölye: ajanların kurduğu paketler soru sormadan kurulsun.
APT::Get::Assume-Yes "true";
Dpkg::Options { "--force-confdef"; "--force-confold"; };
APT

adim "Gerekli paketler kuruluyor"
"${APT[@]}" install python nodejs-lts git curl gh openssh
pip install --upgrade --quiet websockets
tamam "python $(python --version 2>&1 | cut -d' ' -f2), node $(node --version)"

# Termux'ta Node "android" platformu görünür; npm'in ajan paketleri ise yalnız
# linux için derlenmiş program taşır. Bu yüzden:
#   Codex  : linux-arm64 paketi seçilerek kurulur (program statik, doğrudan çalışır)
#   Claude : resmi linux paketi indirilir, Termux'un glibc deposuyla çalıştırılır
case "$(uname -m)" in
  aarch64) NPM_CPU=arm64; GLIBC_LD=ld-linux-aarch64.so.1 ;;
  x86_64) NPM_CPU=x64; GLIBC_LD=ld-linux-x86-64.so.2 ;;
  *) NPM_CPU=""; GLIBC_LD="" ;;
esac

claude_kur() {
  if [ -z "$NPM_CPU" ]; then
    uyar "Claude Code bu işlemcide desteklenmiyor: $(uname -m)"
    return 1
  fi
  # Önceki denemeden kalan, Termux'ta çalışmayan npm kurulumunu kaldır.
  npm uninstall -g @anthropic-ai/claude-code >/dev/null 2>&1 || true

  echo "Termux glibc deposu ve araçları kuruluyor…"
  "${APT[@]}" install glibc-repo || return 1
  pkg update -y || return 1
  "${APT[@]}" install glibc-runner patchelf || return 1
  local glibc="$PREFIX/glibc" ld="$PREFIX/glibc/lib/$GLIBC_LD"
  if [ ! -f "$ld" ]; then
    uyar "glibc yükleyicisi bulunamadı: $ld"
    return 1
  fi

  local surum paket gecici hedef="$HOME/.atolye/claude"
  surum="$(npm view @anthropic-ai/claude-code version)" || return 1
  paket="@anthropic-ai/claude-code-linux-$NPM_CPU@$surum"
  echo "İndiriliyor: $paket (yaklaşık 100 MB, açılınca 350 MB)…"
  gecici="$(mktemp -d)"
  if ! (cd "$gecici" && npm pack "$paket" --silent >/dev/null && tar xzf ./*.tgz); then
    rm -rf "$gecici"
    return 1
  fi
  mkdir -p "$hedef"
  mv -f "$gecici/package/claude" "$hedef/claude.yeni"
  rm -rf "$gecici"
  # Programın yükleyicisini Termux'un glibc'sine yönlendir.
  patchelf --set-interpreter "$ld" --set-rpath "$glibc/lib" "$hedef/claude.yeni" || return 1
  chmod 755 "$hedef/claude.yeni"
  mv -f "$hedef/claude.yeni" "$hedef/claude"

  # glibc'nin ad çözümü için (Android'de /etc/resolv.conf yok).
  mkdir -p "$glibc/etc"
  [ -s "$glibc/etc/resolv.conf" ] || printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n' > "$glibc/etc/resolv.conf"

  # Termux'un LD_PRELOAD'ı (bionic) glibc sürecine yüklenemez: Claude için
  # kaldırılır, Claude'un açtığı kabuklara BASH_ENV ile geri verilir.
  cat > "$HOME/.atolye/termux-ortam.sh" <<'SH'
[ -n "$ATOLYE_LD_PRELOAD" ] && export LD_PRELOAD="$ATOLYE_LD_PRELOAD"
SH
  cat > "$PREFIX/bin/claude" <<SH
#!$PREFIX/bin/sh
# Atölye: Claude Code'un resmi linux paketi, Termux glibc ile.
export ATOLYE_LD_PRELOAD="\${LD_PRELOAD:-}"
export BASH_ENV="\$HOME/.atolye/termux-ortam.sh"
export DISABLE_AUTOUPDATER=1
unset LD_PRELOAD
exec "\$HOME/.atolye/claude/claude" "\$@"
SH
  chmod 755 "$PREFIX/bin/claude"
  hash -r
  claude --version
}

codex_kur() {
  if [ -z "$NPM_CPU" ]; then
    uyar "Codex bu işlemcide desteklenmiyor: $(uname -m)"
    return 1
  fi
  npm install -g --os=linux --cpu="$NPM_CPU" @openai/codex || return 1
  hash -r

  # npm başlatıcısındaki /usr/bin/env yolu Termux'ta bulunmaz.
  local baslatici ilk_satir
  baslatici="$(readlink -f "$PREFIX/bin/codex")" || return 1
  if [ ! -x "$baslatici" ] || [ ! -x "$PREFIX/bin/node" ]; then
    uyar "Codex başlatıcısı veya Node bulunamadı"
    return 1
  fi
  IFS= read -r ilk_satir < "$baslatici" || return 1
  if [ "$ilk_satir" = '#!/usr/bin/env node' ]; then
    sed -i "1c\\#!$PREFIX/bin/node" "$baslatici" || return 1
  fi
  "$PREFIX/bin/codex" --version || return 1

  # Android uygulamaları zaten yalıtılmıştır; Codex'in kum aracı bubblewrap
  # burada çalışmaz (Linux namespace izni yok). Komutlar kumsuz çalışsın;
  # onaylar yine onay politikasına göre sorulur.
  local ayar="$HOME/.codex/config.toml"
  mkdir -p "$HOME/.codex"
  touch "$ayar"
  if ! grep -q '^[[:space:]]*sandbox_mode' "$ayar"; then
    # üst düzey anahtar, ilk [tablo]dan önce gelmeli: dosyanın başına yaz
    { printf '# Atölye: Android/Termux, bubblewrap kullanılamaz\nsandbox_mode = "danger-full-access"\n\n'; cat "$ayar"; } > "$ayar.yeni"
    mv -f "$ayar.yeni" "$ayar"
  fi

  # Etkileşimli codex arka plan sunucusu (daemon) açmaya çalışır; o da
  # bubblewrap ister. Termux'ta etkileşimli kullanım --no-daemon ile.
  local rc="$HOME/.bashrc"
  touch "$rc"
  if ! grep -q 'atolye-codex' "$rc"; then
    cat >> "$rc" <<'RC'

# atolye-codex: Android'de Codex'in arka plan sunucusu çalışmaz
codex() {
  case "${1:-}" in
    exec|e|review|login|logout|mcp|mcp-server|app-server|remote-control|completion|update|doctor|sandbox|debug|apply|a|cloud|features|help|plugin|--version|-V|--help|-h)
      command codex "$@" ;;
    resume|fork)
      local alt="$1"; shift; command codex "$alt" --no-daemon "$@" ;;
    *)
      command codex --no-daemon "$@" ;;
  esac
}
RC
  fi
}

IFS=',' read -ra SECILEN <<< "$AJANLAR"
for ajan in "${SECILEN[@]}"; do
  case "$ajan" in
    claude)
      adim "Claude Code kuruluyor (resmi linux paketi + Termux glibc)"
      if claude_kur; then
        tamam "Claude Code kuruldu"
      else
        uyar "Claude Code kurulamadı; yukarıdaki hataya bak. Komutu yeniden çalıştırmak güvenlidir."
      fi
      ;;
    codex)
      adim "Codex kuruluyor (npm: @openai/codex, linux-$NPM_CPU)"
      if codex_kur; then
        tamam "Codex kuruldu"
      else
        uyar "Codex kurulamadı; yukarıdaki hataya bak. Komutu yeniden çalıştırmak güvenlidir."
      fi
      ;;
    *) uyar "bilinmeyen ajan: $ajan" ;;
  esac
done

adim "Atölye köprüsü kuruluyor"
mkdir -p "$HOME/.atolye/kopru" "$HOME/projeler"
if [ -n "$KAYNAK" ]; then
  curl -fsS "$KAYNAK/atolye_kopru.py" -o "$HOME/.atolye/kopru/atolye_kopru.py"
  # ajanlara verilen Termux rehberi (paket kurma, Termux'a özgü sorunlar)
  curl -fsS "$KAYNAK/termux_rehberi.md" -o "$HOME/.atolye/kopru/termux_rehberi.md" || \
    uyar "ajan rehberi indirilemedi"
elif [ -f "$(dirname "$0")/atolye_kopru.py" ]; then
  cp "$(dirname "$0")/atolye_kopru.py" "$HOME/.atolye/kopru/"
  cp "$(dirname "$0")/termux_rehberi.md" "$HOME/.atolye/kopru/" 2>/dev/null || true
else
  echo "köprü dosyası bulunamadı (--kaynak verilmedi)" >&2
  exit 1
fi

cat > "$PREFIX/bin/atolye-kopru" <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
# Atölye köprüsünü başlatır; zaten çalışıyorsa bir şey yapmaz.
if curl -fsS -m 2 "http://127.0.0.1:${ATOLYE_PORT:-8765}/saglik" >/dev/null 2>&1; then
  exit 0
fi
command -v termux-wake-lock >/dev/null && termux-wake-lock
mkdir -p "$HOME/.atolye"
exec python "$HOME/.atolye/kopru/atolye_kopru.py" "$@" >>"$HOME/.atolye/kopru.log" 2>&1
SH
chmod +x "$PREFIX/bin/atolye-kopru"

if [ -n "$TOKEN" ]; then
  python "$HOME/.atolye/kopru/atolye_kopru.py" --token "$TOKEN" --token-goster >/dev/null
fi
tamam "köprü hazır: atolye-kopru"

adim "Uygulamanın Termux'a komut gönderme izni"
mkdir -p "$HOME/.termux"
PROPS="$HOME/.termux/termux.properties"
touch "$PROPS"
if grep -q '^\s*allow-external-apps' "$PROPS"; then
  sed -i 's/^\s*allow-external-apps.*/allow-external-apps = true/' "$PROPS"
else
  echo "allow-external-apps = true" >> "$PROPS"
fi
command -v termux-reload-settings >/dev/null && termux-reload-settings || true
tamam "allow-external-apps = true"

adim "Köprü başlatılıyor"
nohup atolye-kopru >/dev/null 2>&1 &
sleep 2
if curl -fsS -m 3 http://127.0.0.1:8765/saglik >/dev/null; then
  tamam "köprü çalışıyor (127.0.0.1:8765)"
else
  uyar "köprü başlamadı: ~/.atolye/kopru.log dosyasına bakın"
fi

printf '\n\033[1;32mKurulum bitti.\033[0m Atölye uygulamasına dönebilirsiniz.\n'
printf 'Giriş için uygulamadaki "Giriş yap" adımı Termux'"'"'ta %s komutunu açacak.\n' "$AJANLAR"
