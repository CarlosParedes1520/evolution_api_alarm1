# ---------- BUILDER ----------
FROM node:20-bookworm-slim AS builder

ARG CACHE_BUSTER=2025-11-08-01
RUN echo ">>> USING BOOKWORM builder | CACHE_BUSTER=${CACHE_BUSTER}"

# En la etapa builder
RUN apt-get update && apt-get install -y git ca-certificates build-essential python3 pkg-config curl bash openssl dos2unix libvips-dev **libglib2.0-dev** && rm -rf /var/lib/apt/lists/*

# Pruebas visibles en logs (deben aparecer sí o sí)
RUN node -v && npm -v && git --version
RUN dpkg -l | grep -E 'libvips|vips' || true
RUN pkg-config --modversion vips-cpp || true

WORKDIR /evolution

# sharp: compilar con libvips del sistema
ENV npm_config_python=/usr/bin/python3
ENV npm_config_build_from_source=true
ENV npm_config_sharp_ignore_global_libvips=0

COPY package*.json ./
COPY tsconfig.json ./
COPY tsup.config.ts ./

RUN npm ci --no-audit --no-fund

COPY src ./src
COPY public ./public
COPY prisma ./prisma
COPY manager ./manager
COPY .env.example ./.env
COPY runWithProvider.js ./
COPY Docker ./Docker

RUN chmod +x ./Docker/scripts/* && dos2unix ./Docker/scripts/*

# RUN ./Docker/scripts/generate_database.sh  # si lo necesitas en build
RUN npm run build
RUN npm prune --omit=dev

# ---------- FINAL ----------
FROM node:20-bookworm-slim AS final

ARG CACHE_BUSTER=2025-11-08-01
RUN echo ">>> USING BOOKWORM final | CACHE_BUSTER=${CACHE_BUSTER}"

RUN apt-get update && apt-get install -y \
  tzdata ffmpeg bash openssl curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

ENV TZ=America/Sao_Paulo
ENV NODE_ENV=production
ENV DOCKER_ENV=true

WORKDIR /evolution

COPY --from=builder /evolution/package.json ./package.json
COPY --from=builder /evolution/package-lock.json ./package-lock.json
COPY --from=builder /evolution/node_modules ./node_modules
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/manager ./manager
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/.env ./.env
COPY --from=builder /evolution/Docker ./Docker
COPY --from=builder /evolution/runWithProvider.js ./runWithProvider.js
COPY --from=builder /evolution/tsup.config.ts ./tsup.config.ts

EXPOSE 8080
ENTRYPOINT ["/bin/bash", "-c", ". ./Docker/scripts/deploy_database.sh && npm run start:prod" ]
