#!/bin/bash
set -e

CONFIG_FILE="/projects/carik/config/config.json"
export CONFIG_FILE

# Dukungan debug: docker run carik-bot bash
if [ "$#" -gt 0 ]; then
  case "$1" in
    bash|sh|/bin/bash|/bin/sh)
      exec "$@"
      ;;
  esac
fi

# Injeksi TELEGRAM_TOKEN secara idempoten via jq (aman untuk karakter khusus)
if [ -n "$TELEGRAM_TOKEN" ] && [ -f "$CONFIG_FILE" ]; then
  if command -v jq >/dev/null 2>&1; then
    tmp=$(mktemp)
    if jq --arg token "$TELEGRAM_TOKEN" '.telegram.default.token = $token' "$CONFIG_FILE" > "$tmp" 2>/dev/null; then
      cat "$tmp" > "$CONFIG_FILE"
      echo "[init] TELEGRAM_TOKEN injected to telegram.default.token"
    else
      echo "[warn] jq inject gagal, config tidak diubah" >&2
    fi
    rm -f "$tmp"
  elif command -v python3 >/dev/null 2>&1; then
    python3 << 'PYEOF' || true
import json, os, sys
p = os.environ.get("CONFIG_FILE", "/projects/carik/config/config.json")
t = os.environ.get("TELEGRAM_TOKEN", "")
try:
    with open(p, "r") as f:
        d = json.load(f)
    d.setdefault("telegram", {}).setdefault("default", {})["token"] = t
    with open(p, "w") as f:
        json.dump(d, f, indent=2)
    print("[init] TELEGRAM_TOKEN injected via python3")
except Exception as e:
    print(f"[warn] python inject gagal: {e}", file=sys.stderr)
PYEOF
  else
    echo "[warn] jq/python3 tidak tersedia, fallback sed (rentan karakter khusus)" >&2
    esc_token=$(printf '%s\n' "$TELEGRAM_TOKEN" | sed 's/[&|\/\\]/\\&/g; s/"/\\"/g')
    sed -i "s|\"token\": \"\"|\"token\": \"$esc_token\"|g" "$CONFIG_FILE" || true
  fi
fi

# Penanganan PORT kustom internal (default 80)
if [ -n "$PORT" ] && [ "$PORT" != "80" ]; then
  if [ -f /etc/apache2/ports.conf ]; then
    sed -i "s/Listen 80/Listen $PORT/g" /etc/apache2/ports.conf 2>/dev/null || true
    if [ -f /etc/apache2/sites-available/000-default.conf ]; then
      sed -i "s/:80/:$PORT/g" /etc/apache2/sites-available/000-default.conf 2>/dev/null || true
    fi
    for f in /etc/apache2/sites-available/*.conf; do
      [ -f "$f" ] && sed -i "s/:80/:$PORT/g" "$f" 2>/dev/null || true
    done
    echo "[init] Apache Listen port diubah ke $PORT"
  fi
fi

# Pastikan direktori runtime ada dan milik www-data (named volumes mount sebagai root)
mkdir -p /projects/carik/ztemp /projects/carik/data
if ! chown -R www-data:www-data /projects/carik/ztemp /projects/carik/data 2>/dev/null; then
  echo "[warn] chown www-data gagal (user mungkin belum ada di base image)" >&2
fi
chmod -R 775 /projects/carik/ztemp /projects/carik/data 2>/dev/null || true

echo
echo "============================================================"
echo " Carik Bot Engine (FastPlaz / Object Pascal Runtime)"
echo "============================================================"
echo " Status       : Aktif"
echo " Container    : http://localhost:${PORT:-80}/carik/"
if [ -n "$HOST_PORT" ]; then
  echo " Host         : http://localhost:$HOST_PORT/carik/"
else
  echo " Host         : http://localhost:8080/carik/ (via compose HOST_PORT)"
fi
echo " NLP Engine   : FastPlaz SimpleAI (files/nlp/)"
echo "============================================================"
echo

if [ "$#" -gt 0 ]; then
  exec "$@"
else
  exec /usr/sbin/apache2ctl -D FOREGROUND
fi
