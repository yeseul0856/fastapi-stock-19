#!/usr/bin/env bash
# EC2 서버에서 실행: 의존성 설치 → 서비스/nginx 설정 반영 → 재시작 → 헬스체크
set -euo pipefail

APP_DIR=/home/ubuntu/fastapi-stock-19
cd "$APP_DIR"

# uv 설치 (최초 1회)
if ! command -v uv >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/uv" ]; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi
export PATH="$HOME/.local/bin:$PATH"

# nginx 설치 (최초 1회)
if ! command -v nginx >/dev/null 2>&1; then
    sudo apt-get update -y
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nginx
fi

# 파이썬 + 의존성 설치 (uv.lock 기준)
uv sync --frozen --no-dev

# systemd 서비스 반영
sudo cp deploy/fastapi-stock.service /etc/systemd/system/fastapi-stock.service
sudo systemctl daemon-reload
sudo systemctl enable fastapi-stock >/dev/null 2>&1
sudo systemctl restart fastapi-stock

# nginx 설정 반영
sudo cp deploy/nginx.conf /etc/nginx/sites-available/fastapi-stock
sudo ln -sf /etc/nginx/sites-available/fastapi-stock /etc/nginx/sites-enabled/fastapi-stock
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl enable nginx >/dev/null 2>&1
sudo systemctl reload nginx || sudo systemctl restart nginx

# 헬스체크
for i in $(seq 1 20); do
    if curl -fsS http://127.0.0.1/ >/dev/null; then
        echo "Deploy OK"
        exit 0
    fi
    sleep 2
done
echo "Health check failed" >&2
sudo journalctl -u fastapi-stock -n 50 --no-pager >&2
exit 1
