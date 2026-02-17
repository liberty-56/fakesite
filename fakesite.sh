#!/bin/bash

# Значение порта по умолчанию
SPORT=9000

# Разбор аргументов
while [[ $# -gt 0 ]]; do
    case "$1" in
        --selfsni-port)
            if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                SPORT="$2"
                shift 2
            else
                echo "Ошибка: укажите корректный порт после аргумента --selfsni-port."
                exit 1
            fi
            ;;
        *)
            echo "Неизвестный аргумент: $1"
            echo "Использование: $0 [--selfsni-port <порт>]"
            exit 1
            ;;
    esac
done

WITHOUT_80=0
for arg in "$@"; do
    if [[ "$arg" == "--without-80" ]]; then
        WITHOUT_80=1
    fi
done

# Проверка системы
if ! grep -E -q "^(ID=debian|ID=ubuntu)" /etc/os-release; then
    echo "Скрипт поддерживает только Debian или Ubuntu. Завершаю работу."
    exit 1
fi

# Запрос доменного имени
read -p "Введите доменное имя: " DOMAIN
if [[ -z "$DOMAIN" ]]; then
    echo "Доменное имя не может быть пустым. Завершаю работу."
    exit 1
fi

# Получение внешнего IP сервера
external_ip=$(curl -s --max-time 3 https://api.ipify.org)

# Проверка, что curl успешно получил IP
if [[ -z "$external_ip" ]]; then
  echo "Не удалось определить внешний IP сервера. Проверьте подключение к интернету."
  exit 1
fi

echo "Внешний IP сервера: $external_ip"

# Получение A-записи домена
domain_ip=$(dig +short A "$DOMAIN")

# Проверка, что A-запись существует
if [[ -z "$domain_ip" ]]; then
  echo "Не удалось получить A-запись для домена $DOMAIN. Убедитесь, что домен существует, подробнее что делать вы можете ознакомиться тут: https://wiki.yukikras.net/ru/selfsni"
  exit 1
fi

echo "A-запись домена $DOMAIN указывает на: $domain_ip"

# Сравнение IP адресов
if [[ "$domain_ip" == "$external_ip" ]]; then
  echo "A-запись домена $DOMAIN соответствует внешнему IP сервера."
else
  echo "A-запись домена $DOMAIN не соответствует внешнему IP сервера, подробнее что делать вы можете ознакомиться тут: https://wiki.yukikras.net/ru/selfsni#a-запись-домена-не-соответствует-внешнему-ip-сервера-или-не-удалось-получить-a-запись-для-домена"
  exit 1
fi

# Проверка, занят ли порт
if ss -tuln | grep -q ":443 "; then
    echo "Порт 443 занят, пожалуйста освободите порт, подробнее что делать вы можете ознакомиться тут: https://wiki.yukikras.net/ru/selfsni#порт-44380-занят-пожалуйста-освободите-порт"
    exit 1
else
    echo "Порт 443 свободен."
fi

if [[ $WITHOUT_80 -eq 0 ]]; then
    if ss -tuln | grep -q ":80 "; then
        echo "Порт 80 занят, пожалуйста освободите порт, подробнее что делать вы можете ознакомиться тут: https://wiki.yukikras.net/ru/selfsni"
        exit 1
    else
        echo "Порт 80 свободен."
    fi
else
    echo "Пропускаем настройку порта 80 (--without-80). Порт 80 останется свободен."
fi

# Установка nginx и certbot
apt update && apt install -y nginx certbot python3-certbot-nginx git

# --- НАЧАЛО ВСТАВКИ ---
echo "Создаем кастомную страницу-заглушку..."
mkdir -p /var/www/html

# Записываем HTML код в файл.
# Важно использовать 'EOF' (в кавычках), чтобы Bash не пытался интерпретировать символы внутри HTML
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>503 - Критическая нагрузка системы</title>
    <style>
        :root {
            --bg-color: #111318;
            --card-bg: #1a1d24;
            --border-color: #2a2e38;
            --text-main: #e1e3e6;
            --text-muted: #8b949e;
            --accent-red: #ff4d4d;
            --accent-blue: #58a6ff;
            --accent-yellow: #d29922;
            --font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
        }

        body {
            background-color: var(--bg-color);
            color: var(--text-main);
            font-family: var(--font-family);
            margin: 0;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            text-align: center;
        }

        .container {
            max-width: 800px;
            padding: 20px;
            width: 100%;
            box-sizing: border-box;
        }

        /* Иконки сверху */
        .icons-wrapper {
            display: flex;
            gap: 20px;
            justify-content: center;
            margin-bottom: 20px;
            opacity: 0.9;
        }
        
        .icon {
            width: 48px;
            height: 48px;
            stroke: var(--accent-red);
            stroke-width: 1.5;
            fill: none;
        }

        h1 {
            font-size: 2.5rem;
            margin: 0 0 10px 0;
            font-weight: 700;
        }

        .status-code {
            color: var(--accent-red);
            font-size: 1.1rem;
            margin-bottom: 40px;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
        }

        /* Основная карточка */
        .main-card {
            background-color: var(--card-bg);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 40px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
        }

        .status-message {
            margin-bottom: 30px;
            color: #ff7b72;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
        }

        .status-dot {
            width: 10px;
            height: 10px;
            background-color: #ff7b72;
            border-radius: 50%;
            box-shadow: 0 0 10px #ff7b72;
        }

        /* Грид для тех. данных и таймера */
        .grid-info {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            margin-bottom: 30px;
        }

        @media (max-width: 600px) {
            .grid-info {
                grid-template-columns: 1fr;
            }
        }

        .info-box {
            background-color: rgba(255,255,255,0.02);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 20px;
            text-align: left;
        }

        .info-box h3 {
            margin: 0 0 15px 0;
            font-size: 0.9rem;
            color: var(--accent-blue);
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .data-row {
            font-family: monospace;
            font-size: 0.9rem;
            margin-bottom: 8px;
            color: var(--text-muted);
        }
        
        .data-value {
            color: #7ee787;
        }

        .timer-box {
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            text-align: center;
        }
        
        .timer-value {
            font-size: 2rem;
            font-family: monospace;
            color: var(--accent-blue);
            font-weight: bold;
            text-shadow: 0 0 15px rgba(88, 166, 255, 0.3);
        }

        /* Уведомление внизу карточки */
        .notice-box {
            background-color: rgba(210, 153, 34, 0.05);
            border: 1px solid rgba(210, 153, 34, 0.2);
            border-radius: 8px;
            padding: 15px;
            color: var(--text-muted);
            font-size: 0.9rem;
        }
        
        .notice-title {
            color: var(--accent-yellow);
            font-weight: bold;
            margin-bottom: 5px;
            display: block;
        }

        /* Футер */
        .footer-status {
            margin-top: 40px;
            font-size: 0.85rem;
            color: var(--text-muted);
            opacity: 0.6;
        }

        .loading-text {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            margin-bottom: 10px;
        }

        .spinner {
            width: 14px;
            height: 14px;
            border: 2px solid var(--text-muted);
            border-top-color: transparent;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }

        @keyframes spin {
            to { transform: rotate(360deg); }
        }
        
        /* Блок статуса в самом низу */
        .sys-status-badge {
            margin-top: 50px;
            display: inline-block;
            background: rgba(255,255,255,0.05);
            padding: 8px 16px;
            border-radius: 20px;
            border: 1px solid var(--border-color);
            font-size: 0.8rem;
        }
    </style>
</head>
<body>

    <div class="container">
        <div class="icons-wrapper">
            <svg class="icon" viewBox="0 0 24 24">
                <path d="M4 4h16v16H4z"></path>
                <path d="M9 9h6v6H9z"></path>
                <path d="M9 1V4 M15 1V4 M9 20V23 M15 20V23 M20 9H23 M20 14H23 M1 9H4 M1 14H4"></path>
            </svg>
            <svg class="icon" viewBox="0 0 24 24">
                <polyline points="22 12 18 12 15 21 9 3 6 12 2 12"></polyline>
            </svg>
            <svg class="icon" viewBox="0 0 24 24">
                <path d="M1 1l22 22"></path>
                <path d="M16.72 11.06A10.94 10.94 0 0 1 19 12.55"></path>
                <path d="M5 12.55a10.94 10.94 0 0 1 5.17-2.39"></path>
                <path d="M10.71 5.05A16 16 0 0 1 22.58 9"></path>
                <path d="M1.42 9a15.91 15.91 0 0 1 4.7-2.88"></path>
                <path d="M8.53 16.11a6 6 0 0 1 6.95 0"></path>
                <line x1="12" y1="20" x2="12.01" y2="20"></line>
            </svg>
        </div>

        <h1>Критическая нагрузка</h1>
        <div class="status-code">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path>
            </svg>
            Код состояния: 503
        </div>

        <div class="main-card">
            <div class="status-message">
                <div class="status-dot"></div>
                Система испытывает экстремальную нагрузку
            </div>

            <div class="grid-info">
                <div class="info-box">
                    <h3>>_ Технические данные</h3>
                    <div class="data-row">IP: <span class="data-value" id="user-ip">...</span></div>
                    <div class="data-row">ID: <span class="data-value" id="incident-id">Generating...</span></div>
                </div>

                <div class="info-box timer-box">
                    <h3>Автоматическое восстановление</h3>
                    <div class="timer-value" id="timer">04:59</div>
                </div>
            </div>

            <div class="notice-box">
                <span class="notice-title">Важное уведомление</span>
                Пожалуйста, не закрывайте эту страницу. Система автоматически попытается перенаправить вас на резервный сервер по истечении таймера.
            </div>
        </div>

        <div class="footer-status">
            <div class="loading-text">
                <div class="spinner"></div>
                Выполняется поиск доступных серверов для перенаправления запроса
            </div>
            <p>Если проблема сохраняется после автоматической попытки восстановления, обратитесь в техническую поддержку, указав ID инцидента.</p>
        </div>

        <div class="sys-status-badge">
            Status: Critical Load (Cluster #4)
        </div>
    </div>

    <script>
        // Имитация обратного отсчета
        let timeLeft = 299; // 5 минут
        const timerElement = document.getElementById('timer');
        
        const countdown = setInterval(() => {
            const minutes = Math.floor(timeLeft / 60);
            let seconds = timeLeft % 60;
            
            seconds = seconds < 10 ? '0' + seconds : seconds;
            timerElement.textContent = `0${minutes}:${seconds}`;
            
            if (timeLeft <= 0) {
                timeLeft = 300; // Перезапуск цикла, чтобы страница выглядела живой
            } else {
                timeLeft--;
            }
        }, 1000);

        // Генерация случайного ID инцидента
        function generateId() {
            const chars = '0123456789ABCDEF';
            let id = '';
            for (let i = 0; i < 32; i++) {
                id += chars[Math.floor(Math.random() * chars.length)];
            }
            return id;
        }
        document.getElementById('incident-id').textContent = generateId();

        // Попытка показать IP (опционально, требует внешнего API, здесь просто заглушка)
        // В реальном сценарии Nginx может передавать IP, но для заглушки сойдет статика или JS
        document.getElementById('user-ip').textContent = window.location.hostname || '95.85.xxx.xxx';
    </script>
</body>
</html>
EOF
# --- КОНЕЦ ВСТАВКИ ---

# Выпуск сертификата
if [[ $WITHOUT_80 -eq 1 ]]; then
    echo "Выпускаем сертификат с помощью TLS-ALPN-01 (порт 443), порт 80 не используется..."
    certbot certonly --nginx -d "$DOMAIN" --agree-tos -m "admin@$DOMAIN" --non-interactive --preferred-challenges tls-alpn-01
else
    echo "Выпускаем сертификат обычным способом через HTTP-01..."
    certbot --nginx -d "$DOMAIN" --agree-tos -m "admin@$DOMAIN" --non-interactive
fi

# Настройка конфигурации Nginx
cat > /etc/nginx/sites-enabled/sni.conf <<EOF
server {
EOF

if [[ $WITHOUT_80 -eq 0 ]]; then
cat >> /etc/nginx/sites-enabled/sni.conf <<EOF
    listen 80;
    server_name $DOMAIN;

    if (\$host = $DOMAIN) {
        return 301 https://\$host\$request_uri;
    }

    return 404;
EOF
fi

cat >> /etc/nginx/sites-enabled/sni.conf <<EOF
}

server {
    listen 127.0.0.1:$SPORT ssl http2 proxy_protocol;

    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers "ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384";

    ssl_stapling on;
    ssl_stapling_verify on;

    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;

    # Настройки Proxy Protocol
    real_ip_header proxy_protocol;
    set_real_ip_from 127.0.0.1;

    location / {
        root /var/www/html;
        index index.html;
    }
}
EOF

rm /etc/nginx/sites-enabled/default

# Перезапуск Nginx
nginx -t && systemctl reload nginx

# Показ путей сертификатов
CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
KEY_PATH="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
echo ""
echo ""
echo ""
echo ""
echo "Сертификат и ключ расположены в следующих путях:"
echo "Сертификат: $CERT_PATH"
echo "Ключ: $KEY_PATH"
echo ""
echo "В качестве Dest укажите: 127.0.0.1:$SPORT"
echo "В качестве SNI укажите: $DOMAIN"

echo "Скрипт завершён."
