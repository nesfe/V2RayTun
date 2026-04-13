#!/bin/bash
# === ЭТАП 2: Установка Xray и генерация ключей ===
# Запускать на целевом сервере от root

set -e

echo "=== Устанавливаем Xray ==="
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

echo "=== Генерируем UUID ==="
UUID=$(/usr/local/bin/xray uuid)
echo "UUID: $UUID"

echo "=== Генерируем ключи Reality ==="
KEYS=$(/usr/local/bin/xray x25519)
PRIVATE_KEY=$(echo "$KEYS" | grep "Private" | awk '{print $3}')
PUBLIC_KEY=$(echo "$KEYS" | grep "Public" | awk '{print $3}')
echo "Private Key: $PRIVATE_KEY"
echo "Public Key: $PUBLIC_KEY"

echo "=== Генерируем Short ID ==="
SHORT_ID=$(openssl rand -hex 8)
echo "Short ID: $SHORT_ID"

echo ""
echo "============================================"
echo "СОХРАНИ ЭТИ ЗНАЧЕНИЯ:"
echo "============================================"
echo "UUID:        $UUID"
echo "Private Key: $PRIVATE_KEY"
echo "Public Key:  $PUBLIC_KEY"
echo "Short ID:    $SHORT_ID"
echo "============================================"
echo ""
echo "Теперь подставь эти значения в конфиг /usr/local/etc/xray/config.json"
