#!/usr/bin/env bash
# claude-usage kurulumu.
#   ./install.sh            betiği ~/.local/bin altına kurar
#   ./install.sh --timer    ayrıca her sabah 09:00'da rapor yazan systemd kullanıcı zamanlayıcısını kurar
# Rapor dizini: CLAUDE_USAGE_DIR (varsayılan ~/claude-usage)
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/claude-usage"
BIN="$HOME/.local/bin"
OUT="${CLAUDE_USAGE_DIR:-$HOME/claude-usage}"

command -v python3 >/dev/null || { echo "python3 gerekli (>= 3.8)"; exit 1; }
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' \
  || { echo "Python 3.8 veya üstü gerekli: $(python3 --version)"; exit 1; }

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
