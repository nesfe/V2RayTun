# Xray Reality VLESS — автоустановка для V2RayTun

Автоматическая установка Xray с VLESS Reality на Ubuntu. Один скрипт делает всё: чистит сервер от мусора, ставит Xray, настраивает firewall и выдаёт готовую ссылку для V2RayTun.

## Быстрый старт

Подключись к серверу по SSH от root и выполни:

```bash
bash <(curl -sL https://raw.githubusercontent.com/nesfe/V2RayTun/main/install.sh)
```

Скрипт спросит только SNI (домен для маскировки), всё остальное сделает сам.

В конце выдаст `vless://` ссылку — вставляешь её в [V2RayTun](https://apps.apple.com/app/v2raytun/id6476628951) и подключаешься.

## Что делает скрипт

1. **Зачистка** — удаляет Docker, Amnezia, Outline и весь мусор
2. **Установка Xray** — последняя версия, нативно без Docker
3. **Генерация ключей** — UUID, Reality keypair, Short ID
4. **Конфигурация** — VLESS Reality с маскировкой под выбранный SNI
5. **Firewall** — только SSH (22) и Xray (443), всё остальное закрыто
6. **Ссылка** — готовый `vless://` URL для импорта в клиент

## Почему это скрытно

- **Reality** — использует настоящий TLS-сертификат чужого сайта, DPI видит валидный TLS
- **xtls-rprx-vision** — убирает характерные для прокси паттерны трафика
- **Fingerprint Chrome** — TLS-отпечаток неотличим от обычного браузера
- **Порт 443** — стандартный HTTPS
- **Никаких панелей** — снаружи сервер не отвечает ни на что, кроме валидного Reality-хэндшейка

## Требования

- Ubuntu 20.04 / 22.04 / 24.04
- Root-доступ
- Чистый или грязный VPS (скрипт сам вычистит)

## Поэтапная установка

Если хочешь контролировать каждый шаг:

```bash
git clone https://github.com/nesfe/V2RayTun.git
cd V2RayTun
bash 01-cleanup.sh
bash 02-install-xray.sh
# запиши UUID, Private Key, Public Key, Short ID
bash 03-configure.sh "UUID" "PRIVATE_KEY" "SHORT_ID"
bash 04-firewall.sh
bash 05-generate-link.sh "UUID" "PUBLIC_KEY" "SHORT_ID"
```

## Управление после установки

```bash
systemctl status xray        # статус
journalctl -u xray -n 50     # логи
systemctl restart xray        # перезапуск
ss -tulpn                     # открытые порты
ufw status                    # firewall
cat /root/v2raytun-link.txt   # ссылка для клиента
```

## Совместимые клиенты

- [V2RayTun](https://apps.apple.com/app/v2raytun/id6476628951) (iOS)
- [V2RayTun](https://play.google.com/store/apps/details?id=com.v2raytun.android) (Android)
- [Hiddify](https://github.com/hiddify/hiddify-app) (iOS / Android / Desktop)
- [v2rayN](https://github.com/2dust/v2rayN) (Windows)
- [v2rayNG](https://github.com/2dust/v2rayNG) (Android)
- Любой клиент с поддержкой VLESS Reality
