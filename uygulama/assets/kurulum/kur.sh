#!/data/data/com.termux/files/usr/bin/bash
# Atölye kurulumu — Termux içinde çalışır.
#
# İki aşama vardır:
#
#   onyukleme  Kullanıcının Termux'a tek satırla yapıştırdığı kısım: depoları günceller,
#              Python'u kurar, köprüyü indirip başlatır, uygulamanın Termux'a komut
#              gönderebilmesi için allow-external-apps'i açar ve Atölye'ye geri döner.
#              Birkaç dakika sürer.
#   paketler   Köprü başladıktan sonra uygulamanın köprü üzerinden çalıştırdığı kısım:
#              geliştirme araçları ve seçilen ajanlar. Çıktısı uygulamada canlı görünür;
#              kullanıcı Termux'u açmaz. Tekrar çalıştırmak güvenlidir.
#   hepsi      İkisi art arda (elle çalıştırma, eski uygulamalarla uyum).
#
# Uygulama betiği telefonun kendi içinden (127.0.0.1) sunar; ilk satır:
#   curl -fsS http://127.0.0.1:PORT/ANAHTAR | bash
# Hiçbir hesap bilgisi istenmez; giriş her CLI'ın kendi akışıyla, tarayıcıda yapılır.

set -euo pipefail

KAYNAK="${ATOLYE_KAYNAK:-}"
TOKEN=""
AJANLAR="claude"
ASAMA="hepsi"
while [ $# -gt 0 ]; do
  case "$1" in
    --token) TOKEN="$2"; shift 2 ;;
    --ajan) AJANLAR="$2"; shift 2 ;;
    --kaynak) KAYNAK="$2"; shift 2 ;;
    --asama) ASAMA="$2"; shift 2 ;;
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
KOPRU_KLASORU="$HOME/.atolye/kopru"

# Uygulama arka plana düşünce kendi sunucusu uzun süre yanıt vermeyebilir: köprü
# ve rehber, uzun işlerden ÖNCE, ilk saniyelerde alınır.
dosyalari_al() {
  adim "Atölye köprüsü alınıyor"
  mkdir -p "$KOPRU_KLASORU" "$HOME/projeler"
  if [ -n "$KAYNAK" ]; then
    curl -fsS "$KAYNAK/atolye_kopru.py" -o "$KOPRU_KLASORU/atolye_kopru.py.yeni"
    mv -f "$KOPRU_KLASORU/atolye_kopru.py.yeni" "$KOPRU_KLASORU/atolye_kopru.py"
    # ajanlara verilen Termux rehberi (paket kurma, Termux'a özgü sorunlar)
    curl -fsS "$KAYNAK/termux_rehberi.md" -o "$KOPRU_KLASORU/termux_rehberi.md" || uyar "ajan rehberi indirilemedi"
  elif [ -f "$(dirname "$0")/atolye_kopru.py" ]; then
    cp "$(dirname "$0")/atolye_kopru.py" "$KOPRU_KLASORU/"
    cp "$(dirname "$0")/termux_rehberi.md" "$KOPRU_KLASORU/" 2>/dev/null || true
  else
    echo "köprü dosyası bulunamadı (--kaynak verilmedi)" >&2
    exit 1
  fi
  tamam "köprü dosyaları hazır"
}

dis_uygulamalara_izin() {
  adim "Uygulamanın Termux'a komut gönderme izni"
  mkdir -p "$HOME/.termux"
  local props="$HOME/.termux/termux.properties"
  touch "$props"
  if grep -q '^\s*allow-external-apps' "$props"; then
    sed -i 's/^\s*allow-external-apps.*/allow-external-apps = true/' "$props"
  else
    echo "allow-external-apps = true" >> "$props"
  fi
  command -v termux-reload-settings >/dev/null && termux-reload-settings || true
  tamam "allow-external-apps = true"
}

kopruyu_baslat() {
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
    python "$KOPRU_KLASORU/atolye_kopru.py" --token "$TOKEN" --token-goster >/dev/null
  fi

  adim "Köprü başlatılıyor"
  nohup atolye-kopru >/dev/null 2>&1 &
  sleep 2
  if curl -fsS -m 3 "http://127.0.0.1:${ATOLYE_PORT:-8765}/saglik" >/dev/null; then
    tamam "köprü çalışıyor (127.0.0.1:${ATOLYE_PORT:-8765})"
  else
    uyar "köprü başlamadı: ~/.atolye/kopru.log dosyasına bakın"
    return 1
  fi
}

# Termux'tan Atölye'ye geri dön (bulunamazsa ya da izin verilmezse sessizce geç).
atolyeye_don() {
  command -v am >/dev/null 2>&1 || return 0
  am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER \
    -f 0x10200000 -n tr.com.lifeos.atolye/.MainActivity >/dev/null 2>&1 || true
}

faz_onyukleme() {
  dosyalari_al
  dis_uygulamalara_izin

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

  adim "Python kuruluyor"
  "${APT[@]}" install python curl
  pip install --upgrade --quiet websockets
  tamam "python $(python --version 2>&1 | cut -d' ' -f2)"

  kopruyu_baslat
}

# Termux'ta Node "android" platformu görünür; npm'in ajan paketleri ise yalnız
# linux için derlenmiş program taşır. Bu yüzden:
#   Codex  : Termux paket deposundan kurulur
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
  # Eski npm kurulumu aynı komut yolunu kullanır.
  if [ -L "$PREFIX/bin/codex" ]; then
    local hedef
    hedef="$(readlink "$PREFIX/bin/codex")" || return 1
    case "$hedef" in
      */node_modules/@openai/codex/*) npm uninstall -g @openai/codex || return 1 ;;
    esac
  fi
  "${APT[@]}" install codex || return 1
  hash -r
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

faz_paketler() {
  adim "Depo listesi tazeleniyor"
  pkg update -y || uyar "depo listesi tazelenemedi, devam ediliyor"

  adim "Geliştirme araçları kuruluyor (Node.js, Git, GitHub CLI, OpenSSH)"
  "${APT[@]}" install nodejs-lts git gh openssh
  tamam "node $(node --version), $(git --version | cut -d' ' -f3)"

  IFS=',' read -ra SECILEN <<< "$AJANLAR"
  BASARISIZ=()
  for ajan in "${SECILEN[@]}"; do
    case "$ajan" in
      "") ;;
      claude)
        adim "Claude Code kuruluyor (resmi linux paketi + Termux glibc)"
        if claude_kur; then
          tamam "Claude Code kuruldu"
        else
          uyar "Claude Code kurulamadı; yukarıdaki hataya bak. Komutu yeniden çalıştırmak güvenlidir."
          BASARISIZ+=("claude")
        fi
        ;;
      codex)
        adim "Codex kuruluyor (Termux paketi)"
        if codex_kur; then
          tamam "Codex kuruldu"
        else
          uyar "Codex kurulamadı; yukarıdaki hataya bak. Komutu yeniden çalıştırmak güvenlidir."
          BASARISIZ+=("codex")
        fi
        ;;
      *) uyar "bilinmeyen ajan: $ajan" ;;
    esac
  done
  if [ ${#BASARISIZ[@]} -gt 0 ]; then
    uyar "kurulamayanlar: ${BASARISIZ[*]}"
    return 3
  fi
}

case "$ASAMA" in
  onyukleme) faz_onyukleme; atolyeye_don ;;
  paketler) faz_paketler ;;
  hepsi) faz_onyukleme; faz_paketler || SONUC=$?; atolyeye_don; exit "${SONUC:-0}" ;;
  *) echo "bilinmeyen aşama: $ASAMA" >&2; exit 2 ;;
esac

printf '\n\033[1;32mKurulum bitti.\033[0m Atölye uygulamasına dönebilirsiniz.\n'
