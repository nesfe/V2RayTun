#!/bin/bash
# === ЭТАП 4: Firewall — только SSH + Xray, всё остальное закрыто ===
# Запускать на целевом сервере от root

set -e

echo "=== Настраиваем UFW ==="
apt-get install -y ufw

# Сброс
ufw --force reset

# Политика по умолчанию: всё входящее закрыто
ufw default deny incoming
ufw default allow outgoing

# SSH — обязательно до включения!
ufw allow 22/tcp comment 'SSH'

# Xray Reality на 443
ufw allow 443/tcp comment 'Xray Reality'

# Включаем
ufw --force enable

echo ""
echo "=== Состояние firewall ==="
ufw status verbose

echo ""
echo "=== Готово ==="
echo "Открыты только порты 22 (SSH) и 443 (Xray)."
echo "Никаких веб-панелей, никаких лишних сервисов."
