#!/bin/bash
# === ЭТАП 1: Зачистка старого мусора ===
# Запускать на целевом сервере от root

set -e
echo "=== Останавливаем и удаляем Docker-контейнеры ==="
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true
docker network prune -f 2>/dev/null || true

echo "=== Удаляем Docker полностью ==="
systemctl stop docker.socket docker.service 2>/dev/null || true
apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
apt-get purge -y docker docker.io containerd runc 2>/dev/null || true
apt-get autoremove -y
rm -rf /var/lib/docker /var/lib/containerd /etc/docker

echo "=== Удаляем Amnezia ==="
rm -rf /opt/amnezia 2>/dev/null || true
rm -rf /etc/amnezia 2>/dev/null || true

echo "=== Удаляем Outline ==="
rm -rf /opt/outline 2>/dev/null || true
rm -rf /etc/outline 2>/dev/null || true

echo "=== Чистим iptables от мусорных правил ==="
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

echo "=== Убиваем всё что слушает 443 ==="
fuser -k 443/tcp 2>/dev/null || true

echo "=== Снимаем состояние портов ==="
ss -tulpn

echo ""
echo "=== Зачистка завершена ==="
echo "Проверь вывод ss -tulpn выше."
echo "Должны остаться только sshd и systemd-resolve."
