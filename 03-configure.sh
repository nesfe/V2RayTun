#!/bin/bash
# === ЭТАП 3: Подстановка ключей в конфиг ===
# Запускать на целевом сервере от root
# Передай аргументы: ./03-configure.sh <UUID> <PRIVATE_KEY> <SHORT_ID>

set -e

UUID="$1"
PRIVATE_KEY="$2"
SHORT_ID="$3"

if [ -z "$UUID" ] || [ -z "$PRIVATE_KEY" ] || [ -z "$SHORT_ID" ]; then
    echo "Использование: $0 <UUID> <PRIVATE_KEY> <SHORT_ID>"
    echo "Возьми значения из вывода 02-install-xray.sh"
    exit 1
fi

CONFIG='/usr/local/etc/xray/config.json'

cat > "$CONFIG" << XEOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "dzen.ru:443",
          "xver": 0,
          "serverNames": [
            "dzen.ru",
            "www.dzen.ru"
          ],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": [
            "${SHORT_ID}"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "block"
      },
      {
        "type": "field",
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "block"
      }
    ]
  }
}
XEOF

echo "Конфиг записан в $CONFIG"
echo "=== Проверяем конфиг ==="
/usr/local/bin/xray run -test -config "$CONFIG"

echo "=== Запускаем Xray ==="
systemctl enable xray
systemctl restart xray
systemctl status xray --no-pager

echo ""
echo "=== Xray запущен ==="
