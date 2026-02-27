#!/bin/bash

# 1. Установка зависимостей и репозитория Caddy
sudo apt update && sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list

# 2. Установка Caddy
sudo apt update && sudo apt install -y caddy

# 3. Подтягивание конфига и заглушки (укажите ваш RAW URL)
RAW_URL="https://raw.githubusercontent.com/liberty-56/fakesite/caddy-setup/main"

curl -sL "$RAW_URL/Caddyfile" -o /etc/caddy/Caddyfile
curl -sL "$RAW_URL/index.html" -o /srv/index.html

# 4. Права доступа
chown -R caddy:caddy /srv
chown caddy:caddy /etc/caddy/Caddyfile

# 5. Перезапуск
systemctl restart caddy

# 6. Финальное уведомление и открытие редактора
echo -e "\n\033[1;33m[!] ВНИМАНИЕ: Не забудь дописать поддомен в .liberty-net.online\033[0m"
sleep 2
nano /etc/caddy/Caddyfile

# Перезагрузка после ручной правки
systemctl reload caddy
echo "Конфигурация обновлена и применена!"
