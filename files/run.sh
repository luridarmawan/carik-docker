#!/bin/bash
set -e

CONFIG_FILE="/projects/carik/config/config.json"

# Inisialisasi token Telegram jika didefinisikan via environment variable
if [ -n "$TELEGRAM_TOKEN" ] && [ -f "$CONFIG_FILE" ]; then
    sed -i "s|\"token\": \"\"|\"token\": \"$TELEGRAM_TOKEN\"|g" "$CONFIG_FILE"
fi

# Inisialisasi port kustom Apache jika diperlukan
if [ -n "$PORT" ] && [ "$PORT" != "80" ]; then
    sed -i "s/Listen 80/Listen $PORT/g" /etc/apache2/ports.conf 2>/dev/null || true
    sed -i "s/:80/:$PORT/g" /etc/apache2/sites-available/*.conf 2>/dev/null || true
fi

# Pastikan kepemilikan direktori kerja runtime oleh web server
mkdir -p /projects/carik/ztemp /projects/carik/data /projects/carik/files
chown -R www-data:www-data /projects/carik/ztemp /projects/carik/data /projects/carik/files 2>/dev/null || true

echo
echo "============================================================"
echo " Carik Bot Engine (FastPlaz / Object Pascal Runtime)"
echo "============================================================"
echo " Status      : Aktif"
echo " Web BaseURL : http://localhost:${PORT:-8080}/carik/"
echo " NLP Engine  : FastPlaz SimpleAI (files/nlp/)"
echo "============================================================"
echo

exec /usr/sbin/apache2ctl -D FOREGROUND
