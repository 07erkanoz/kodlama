#!/data/data/com.termux/files/usr/bin/bash
# Atölye kurulumu — Termux içinde çalışır.
#
# Uygulama bu scripti telefonun kendi içinden (127.0.0.1) sunar; kullanıcı
# Termux'a tek satırı yapıştırır:
#   pkg install -y curl && curl -fsS http://127.0.0.1:PORT/ANAHTAR/kur.sh | bash -s -- --token T --ajan claude,codex
#
# Yaptıkları (her biri ekranda yazılır):
#   1. Termux paketleri: python, nodejs, git
#   2. Seçilen ajan CLI'ları resmi npm paketlerinden (Claude Code, Codex)
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

adim "Termux paketleri güncelleniyor"
yes | pkg update -y || uyar "paket listesi güncellenemedi, devam ediliyor"
pkg install -y python nodejs-lts git curl
pip install --upgrade --quiet websockets
tamam "python $(python --version 2>&1 | cut -d' ' -f2), node $(node --version)"

IFS=',' read -ra SECILEN <<< "$AJANLAR"
for ajan in "${SECILEN[@]}"; do
  case "$ajan" in
    claude)
      adim "Claude Code kuruluyor (npm: @anthropic-ai/claude-code)"
      if npm install -g @anthropic-ai/claude-code && claude --version; then
        tamam "Claude Code kuruldu"
      else
        uyar "Claude Code bu cihazda çalıştırılamadı; uygulama ayrıntıyı gösterecek"
      fi
      ;;
    codex)
      adim "Codex kuruluyor (npm: @openai/codex)"
      if npm install -g @openai/codex && codex --version; then
        tamam "Codex kuruldu"
      else
        uyar "Codex bu cihazda çalıştırılamadı; uygulama ayrıntıyı gösterecek"
      fi
      ;;
    *) uyar "bilinmeyen ajan: $ajan" ;;
  esac
done

adim "Atölye köprüsü kuruluyor"
mkdir -p "$HOME/.atolye/kopru" "$HOME/projeler"
if [ -n "$KAYNAK" ]; then
  curl -fsS "$KAYNAK/atolye_kopru.py" -o "$HOME/.atolye/kopru/atolye_kopru.py"
elif [ -f "$(dirname "$0")/atolye_kopru.py" ]; then
  cp "$(dirname "$0")/atolye_kopru.py" "$HOME/.atolye/kopru/"
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
