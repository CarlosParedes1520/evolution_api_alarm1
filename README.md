# ---------- BUILDER ----------
FROM node:20-slim AS builder
RUN apt-get update && apt-get install -y \
  git ca-certificates build-essential python3 pkg-config \
  curl bash openssl dos2unix \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /evolution
COPY package*.json ./
RUN npm ci --no-audit --no-fund

COPY . .
RUN chmod +x ./Docker/scripts/* && dos2unix ./Docker/scripts/*

# Si tienes un script de DB:
# RUN ./Docker/scripts/generate_database.sh

RUN npm run build

# ---------- FINAL ----------
FROM node:20-slim AS final
RUN apt-get update && apt-get install -y \
  tzdata ffmpeg bash openssl curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /evolution
ENV NODE_ENV=production DOCKER_ENV=true TZ=America/Sao_Paulo

COPY --from=builder /evolution/package*.json ./
COPY --from=builder /evolution/node_modules ./node_modules
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/manager ./manager
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/Docker ./Docker
COPY --from=builder /evolution/runWithProvider.js ./

EXPOSE 8080
ENTRYPOINT ["/bin/bash", "-c", ". ./Docker/scripts/deploy_database.sh && npm run start:prod" ]
