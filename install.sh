#!/bin/bash
# ============================================================
# XRAY REALITY VLESS — АВТОМАТИЧЕСКАЯ УСТАНОВКА
# ============================================================
# Запускать от root на чистом или грязном Ubuntu 22.04
# Скрипт сам зачистит мусор, поставит Xray, настроит firewall
# и выдаст готовую ссылку для V2RayTun.
# ============================================================

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_step() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""
}

print_ok() {
    echo -e "${GREEN}[OK] $1${NC}"
}

print_warn() {
    echo -e "${YELLOW}[!] $1${NC}"
}

print_err() {
    echo -e "${RED}[ОШИБКА] $1${NC}"
}

# Проверка root
if [ "$(id -u)" -ne 0 ]; then
    print_err "Запусти от root: sudo bash install.sh"
    exit 1
fi

# Определяем IP сервера
SERVER_IP=$(curl -s --max-time 10 https://api.ipify.org || curl -s --max-time 10 https://ifconfig.me || echo "")
if [ -z "$SERVER_IP" ]; then
    print_err "Не удалось определить внешний IP. Проверь интернет."
    exit 1
fi
print_ok "Внешний IP сервера: $SERVER_IP"

# Запрашиваем SNI
echo ""
echo -e "${YELLOW}Введи домен для маскировки (SNI).${NC}"
echo "Требования: сайт должен поддерживать TLS 1.3"
echo "Примеры: dzen.ru, www.google.com, www.microsoft.com"
echo ""
read -p "SNI [dzen.ru]: " SNI
SNI=${SNI:-dzen.ru}

# Проверяем TLS 1.3 на SNI
echo "Проверяю TLS 1.3 на ${SNI}..."
TLS_CHECK=$(echo | openssl s_client -connect "${SNI}:443" -servername "$SNI" 2>/dev/null | grep -c "TLSv1.3" || true)
if [ "$TLS_CHECK" -ge 1 ]; then
    print_ok "${SNI} поддерживает TLS 1.3"
else
    print_warn "${SNI} может не поддерживать TLS 1.3. Продолжаю, но учти риск."
fi

# ============================================================
# ЭТАП 1: ЗАЧИСТКА
# ============================================================
print_step "ЭТАП 1/5: Зачистка старого мусора"

# Docker
if command -v docker &>/dev/null; then
    print_warn "Найден Docker, удаляю..."
    docker stop $(docker ps -aq) 2>/dev/null || true
    docker rm $(docker ps -aq) 2>/dev/null || true
    docker network prune -f 2>/dev/null || true
    systemctl stop docker.socket docker.service 2>/dev/null || true
    apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
    apt-get purge -y docker docker.io containerd runc 2>/dev/null || true
    rm -rf /var/lib/docker /var/lib/containerd /etc/docker
    print_ok "Docker удалён"
else
    print_ok "Docker не найден, пропускаю"
fi

# Amnezia / Outline
rm -rf /opt/amnezia /etc/amnezia 2>/dev/null || true
rm -rf /opt/outline /etc/outline 2>/dev/null || true
print_ok "Остатки Amnezia/Outline удалены"

# Старый Xray (если был)
systemctl stop xray 2>/dev/null || true
systemctl disable xray 2>/dev/null || true

# iptables — чистка
iptables -F 2>/dev/null || true
iptables -X 2>/dev/null || true
iptables -t nat -F 2>/dev/null || true
iptables -t nat -X 2>/dev/null || true
iptables -t mangle -F 2>/dev/null || true
iptables -t mangle -X 2>/dev/null || true
iptables -P INPUT ACCEPT 2>/dev/null || true
iptables -P FORWARD ACCEPT 2>/dev/null || true
iptables -P OUTPUT ACCEPT 2>/dev/null || true
print_ok "iptables очищены"

# Убиваем всё на 443
fuser -k 443/tcp 2>/dev/null || true

apt-get autoremove -y -qq
print_ok "Зачистка завершена"

# ============================================================
# ЭТАП 2: УСТАНОВКА XRAY
# ============================================================
print_step "ЭТАП 2/5: Установка Xray"

bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

if [ ! -f /usr/local/bin/xray ]; then
    print_err "Xray не установился. Проверь интернет и повтори."
    exit 1
fi

XRAY_VERSION=$(/usr/local/bin/xray version | head -1)
print_ok "Установлен: $XRAY_VERSION"

# ============================================================
# ЭТАП 3: ГЕНЕРАЦИЯ КЛЮЧЕЙ И КОНФИГА
# ============================================================
print_step "ЭТАП 3/5: Генерация ключей и конфигурация"

UUID=$(/usr/local/bin/xray uuid)

# Генерируем ключи, ловим и stdout и stderr
KEYS=$(/usr/local/bin/xray x25519 2>&1)

# Парсим: берём значение после двоеточия в каждой строке
PRIVATE_KEY=$(echo "$KEYS" | head -1 | sed 's/.*: *//')
PUBLIC_KEY=$(echo "$KEYS" | sed -n '2p' | sed 's/.*: *//')
SHORT_ID=$(openssl rand -hex 8)

# Проверяем что ключи не пустые
if [ -z "$PRIVATE_KEY" ]; then
    print_err "Не удалось получить Private Key!"
    echo "Вывод xray x25519:"
    echo "$KEYS"
    exit 1
fi
if [ -z "$PUBLIC_KEY" ]; then
    print_err "Не удалось получить Public Key!"
    echo "Вывод xray x25519:"
    echo "$KEYS"
    exit 1
fi

print_ok "UUID:        $UUID"
print_ok "Private Key: $PRIVATE_KEY"
print_ok "Public Key:  $PUBLIC_KEY"
print_ok "Short ID:    $SHORT_ID"

# Пишем конфиг — используем одинарные кавычки в HEREDOC чтобы ничего не раскрывалось
# потом подставляем через sed
cat > /usr/local/etc/xray/config.json << 'XEOF'
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
            "id": "PLACEHOLDER_UUID",
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
          "dest": "PLACEHOLDER_SNI:443",
          "xver": 0,
          "serverNames": [
            "PLACEHOLDER_SNI"
          ],
          "privateKey": "PLACEHOLDER_PRIVATE_KEY",
          "shortIds": [
            "PLACEHOLDER_SHORT_ID"
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

# Подставляем реальные значения через sed
sed -i "s|PLACEHOLDER_UUID|${UUID}|g" /usr/local/etc/xray/config.json
sed -i "s|PLACEHOLDER_PRIVATE_KEY|${PRIVATE_KEY}|g" /usr/local/etc/xray/config.json
sed -i "s|PLACEHOLDER_SHORT_ID|${SHORT_ID}|g" /usr/local/etc/xray/config.json
sed -i "s|PLACEHOLDER_SNI|${SNI}|g" /usr/local/etc/xray/config.json

print_ok "Конфиг записан в /usr/local/etc/xray/config.json"

# Проверяем конфиг
echo "Проверяю конфиг..."
if /usr/local/bin/xray run -test -config /usr/local/etc/xray/config.json 2>&1; then
    print_ok "Конфиг валиден"
else
    print_err "Конфиг невалиден! Содержимое:"
    cat /usr/local/etc/xray/config.json
    exit 1
fi

# ============================================================
# ЭТАП 4: FIREWALL
# ============================================================
print_step "ЭТАП 4/5: Настройка Firewall"

apt-get install -y -qq ufw
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 443/tcp comment 'Xray Reality'
ufw --force enable
print_ok "Firewall настроен: открыты только 22 (SSH) и 443 (Xray)"

# ============================================================
# ЭТАП 5: ЗАПУСК И ССЫЛКА
# ============================================================
print_step "ЭТАП 5/5: Запуск Xray и генерация ссылки"

systemctl enable xray
systemctl restart xray
sleep 2

if systemctl is-active --quiet xray; then
    print_ok "Xray запущен и работает"
else
    print_err "Xray не запустился! Смотри логи: journalctl -u xray -n 50"
    exit 1
fi

# Проверяем что порт слушает
if ss -tulpn | grep -q ':443'; then
    print_ok "Порт 443 слушает"
else
    print_err "Порт 443 не слушает! Смотри логи: journalctl -u xray -n 50"
    exit 1
fi

# Генерируем ссылку
LINK="vless://${UUID}@${SERVER_IP}:443?encryption=none&flow=xtls-rprx-vision&type=tcp&security=reality&sni=${SNI}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}#Reality-${SNI}"

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "Сервер:     ${CYAN}${SERVER_IP}${NC}"
echo -e "Порт:       ${CYAN}443${NC}"
echo -e "Протокол:   ${CYAN}VLESS Reality${NC}"
echo -e "SNI:        ${CYAN}${SNI}${NC}"
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  ССЫЛКА ДЛЯ V2RayTun:${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${YELLOW}${LINK}${NC}"
echo ""
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Скопируй ссылку выше и вставь в V2RayTun."
echo ""
echo "Проверка: подключись и открой https://whatismyipaddress.com/"
echo "IP должен быть: ${SERVER_IP}"
echo ""
echo -e "${CYAN}Полезные команды:${NC}"
echo "  systemctl status xray        — статус"
echo "  journalctl -u xray -n 50     — логи"
echo "  systemctl restart xray       — перезапуск"
echo "  ss -tulpn                    — открытые порты"
echo "  ufw status                   — firewall"

# Сохраняем ссылку и данные в файл
cat > /root/v2raytun-link.txt << LINKEOF
VLESS Link:
${LINK}

UUID:        ${UUID}
Private Key: ${PRIVATE_KEY}
Public Key:  ${PUBLIC_KEY}
Short ID:    ${SHORT_ID}
Server:      ${SERVER_IP}
SNI:         ${SNI}
LINKEOF

print_ok "Ссылка и ключи сохранены в /root/v2raytun-link.txt"
