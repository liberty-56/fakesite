#!/bin/bash

# Цвета для красоты
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. Запрос домена у пользователя
echo -e "${YELLOW}>>> Введите полный домен (например, sub.liberty-net.online):${NC}"
read USER_DOMAIN

# 2. Установка Caddy
echo -e "${YELLOW}>>> Установка Caddy...${NC}"
sudo apt update && sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update && sudo apt install -y caddy

# 3. Загрузка шаблона и заглушки
# ЗАМЕНИТЕ ЭТУ ССЫЛКУ НА ВАШУ!
RAW_URL="https://raw.githubusercontent.com/liberty-56/fakesite/main"

echo -e "${YELLOW}>>> Загрузка конфигурации...${NC}"
curl -sL "$RAW_URL/Caddyfile.template" -o /etc/caddy/Caddyfile
curl -sL "$RAW_URL/index.html" -o /srv/index.html

# 4. Автоматическая подстановка домена в конфиг
# Мы используем sed, чтобы заменить DOMAIN_PLACEHOLDER на то, что вы ввели
sed -i "s/DOMAIN_PLACEHOLDER/$USER_DOMAIN/g" /etc/caddy/Caddyfile

# 5. Права и запуск
chown -R caddy:caddy /srv
chown caddy:caddy /etc/caddy/Caddyfile
systemctl restart caddy

echo -e "${YELLOW}>>> ГОТОВО! Caddy запущен на домене: $USER_DOMAIN${NC}"
