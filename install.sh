#!/usr/bin/env bash
# claude-usage kurulumu.
#   ./install.sh            betiği ~/.local/bin altına kurar
#   ./install.sh --timer    ayrıca her sabah 09:00'da rapor yazan systemd kullanıcı zamanlayıcısını kurar
# Depoyu klonlamadan:
#   curl -fsSL https://raw.githubusercontent.com/DavutKeskin/claude-usage/main/install.sh | bash [-s -- --timer]
# Rapor dizini: CLAUDE_USAGE_DIR (varsayılan ~/claude-usage)
set -euo pipefail

RAW="${CLAUDE_USAGE_RAW:-https://raw.githubusercontent.com/DavutKeskin/claude-usage/main}"
BIN="$HOME/.local/bin"
OUT="${CLAUDE_USAGE_DIR:-$HOME/claude-usage}"

command -v python3 >/dev/null || { echo "python3 gerekli (>= 3.8)"; exit 1; }
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' \
  || { echo "Python 3.8 veya üstü gerekli: $(python3 --version)"; exit 1; }

# Dosya olarak çalıştırıldıysa yanındaki betik; curl | bash ile geldiyse GitHub'dan indirilir.
SELF="${BASH_SOURCE[0]:-}"
if [ -n "$SELF" ] && [ -f "$(dirname "$SELF")/claude-usage" ]; then
  SRC="$(cd "$(dirname "$SELF")" && pwd)/claude-usage"
else
  SRC="$(mktemp)"
  trap 'rm -f "$SRC"' EXIT
  if command -v curl >/dev/null; then
    curl -fsSL "$RAW/claude-usage" -o "$SRC"
  elif command -v wget >/dev/null; then
    wget -qO "$SRC" "$RAW/claude-usage"
  else
    echo "İndirmek için curl veya wget gerekli"; exit 1
  fi
  head -1 "$SRC" | grep -q python3 || { echo "İndirme başarısız: $RAW/claude-usage"; exit 1; }
fi

mkdir -p "$BIN"
install -m 755 "$SRC" "$BIN/claude-usage"
echo "Kuruldu: $BIN/claude-usage"
case ":$PATH:" in
  *":$BIN:"*) ;;
  *) echo "Uyarı: $BIN PATH içinde değil. Kabuk profilinize ekleyin: export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac

[ "${1:-}" = "--timer" ] || { echo "Deneyin: claude-usage"; exit 0; }

if command -v systemctl >/dev/null && systemctl --user show-environment >/dev/null 2>&1; then
  UNIT="$HOME/.config/systemd/user"
  mkdir -p "$UNIT" "$OUT"
  cat > "$UNIT/claude-usage.service" <<UNITEOF
[Unit]
Description=Claude Code günlük kullanım raporu ($OUT)
After=network-online.target

[Service]
Type=oneshot
ExecStart=$BIN/claude-usage -o $OUT
UNITEOF
  cat > "$UNIT/claude-usage.timer" <<UNITEOF
[Unit]
Description=Claude Code kullanım raporu, her sabah 09:00 (kaçırılırsa açılışta)

[Timer]
OnCalendar=*-*-* 09:00:00
Persistent=true
Unit=claude-usage.service

[Install]
WantedBy=timers.target
UNITEOF
  systemctl --user daemon-reload
  systemctl --user enable --now claude-usage.timer
  echo "Zamanlayıcı kuruldu. Raporlar: $OUT/YYYY-MM-DD.md ve $OUT/latest.md"
  echo "Kontrol: systemctl --user list-timers claude-usage.timer"
  echo "Not: oturum açık değilken de çalışsın isterseniz (ör. uzak sunucu): loginctl enable-linger \$USER"
else
  echo "systemd kullanıcı oturumu bulunamadı. Eşdeğer crontab satırı (crontab -e ile ekleyin):"
  echo "  0 9 * * * $BIN/claude-usage -o $OUT >/dev/null 2>&1"
fi
