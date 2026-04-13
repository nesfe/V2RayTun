#!/bin/bash
# === ЭТАП 5: Генерация ссылки для V2RayTun ===
# Передай аргументы: ./05-generate-link.sh <UUID> <PUBLIC_KEY> <SHORT_ID>

UUID="$1"
PUBLIC_KEY="$2"
SHORT_ID="$3"

if [ -z "$UUID" ] || [ -z "$PUBLIC_KEY" ] || [ -z "$SHORT_ID" ]; then
    echo "Использование: $0 <UUID> <PUBLIC_KEY> <SHORT_ID>"
    echo "PUBLIC_KEY (не private!) из вывода 02-install-xray.sh"
    exit 1
fi

SERVER="193.109.69.233"
PORT="443"
SNI="dzen.ru"
FLOW="xtls-rprx-vision"
FINGERPRINT="chrome"
SECURITY="reality"

# Формат VLESS URI
LINK="vless://${UUID}@${SERVER}:${PORT}?encryption=none&flow=${FLOW}&type=tcp&security=${SECURITY}&sni=${SNI}&fp=${FINGERPRINT}&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}#NL-Reality"

echo ""
echo "============================================"
echo "ССЫЛКА ДЛЯ V2RayTun:"
echo "============================================"
echo ""
echo "$LINK"
echo ""
echo "============================================"
echo ""
echo "Скопируй эту ссылку и вставь в V2RayTun"
echo "через 'Add config from clipboard' или импорт."
