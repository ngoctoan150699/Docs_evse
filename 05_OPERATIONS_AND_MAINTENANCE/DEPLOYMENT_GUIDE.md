# HƯỚNG DẪN TRIỂN KHAI MÁY CHỦ SẢN XUẤT (DEPLOYMENT GUIDE)
## (DOCKER COMPOSE, NGINX REVERSE PROXY & CLOUDFLARE SSL DEPLOYMENT)

Tài liệu hướng dẫn triển khai toàn bộ cụm máy chủ CSMS Cloud trên hạ tầng máy chủ Ubuntu Linux sử dụng Docker Compose.

---

## 1. CẤU TRÚC CONTAINER TRONG DOCKER COMPOSE

```yaml
version: '3.8'
services:
  csms-postgres:
    image: timescale/timescaledb:latest-pg16
    restart: always
    environment:
      POSTGRES_DB: thaco_csms
      POSTGRES_USER: thaco_admin
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - pgdata:/var/lib/postgresql/data

  csms-redis:
    image: redis:7-alpine
    restart: always
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD}

  csms-ocpp-gateway:
    build:
      context: ./csms-platform/backend-go
      dockerfile: Dockerfile.gateway
    restart: always
    ports:
      - "9000:9000"
    environment:
      - PORT=9000
      - REDIS_ADDR=csms-redis:6379

  csms-worker:
    build:
      context: ./csms-platform/backend-go
      dockerfile: Dockerfile.worker
    restart: always

  csms-api:
    build:
      context: ./csms-platform/backend-go
      dockerfile: Dockerfile.api
    restart: always
    ports:
      - "8080:8080"

  csms-frontend:
    build:
      context: ./csms-platform/server
      dockerfile: Dockerfile
    restart: always
    ports:
      - "3000:3000"

  nginx:
    image: nginx:alpine
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./infra/nginx.conf:/etc/nginx/nginx.conf:ro
```

---

## 2. QUY TRÌNH TRIỂN KHAI & NÂNG CẤP HỆ THỐNG

```bash
# 1. Kéo mã nguồn mới nhất từ GitHub
git pull origin main

# 2. Build lại toàn bộ container với cache tối ưu
docker compose build

# 3. Khởi động lại dịch vụ với thời gian gián đoạn tối thiểu
docker compose up -d

# 4. Kiểm tra sức khỏe toàn bộ các container
docker compose ps
docker compose logs -f --tail=100 csms-ocpp-gateway
```
