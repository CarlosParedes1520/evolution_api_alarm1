# ---------- BUILDER ----------
FROM node:20-slim AS builder

# Paquetes necesarios para dependencias nativas y GIT
RUN apt-get update && apt-get install -y \
  git ca-certificates \
  build-essential python3 pkg-config \
  curl bash openssl dos2unix \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /evolution

# Ajustes útiles para node-gyp y sharp (seguro dejarlos)
ENV npm_config_python=/usr/bin/python3
ENV npm_config_build_from_source=false
ENV npm_config_sharp_ignore_global_libvips=1

# Copiamos metadatos primero para cachear npm ci
COPY package*.json ./
COPY tsconfig.json ./
COPY tsup.config.ts ./

# Verificación rápida
RUN which git && git --version && node -v && npm -v

# Instalar dependencias (NO usar --no-scripts para que corra prepare)
RUN npm ci --no-audit --no-fund

# Copiar el resto del proyecto
COPY src ./src
COPY public ./public
COPY prisma ./prisma
COPY manager ./manager
COPY .env.example ./.env
COPY runWithProvider.js ./
COPY Docker ./Docker

# Normalizar EOL y permisos de scripts
RUN chmod +x ./Docker/scripts/* && dos2unix ./Docker/scripts/*

# (Opcional) Generar base de datos / Prisma si tu proyecto lo requiere
# Descomenta si aplica:
# RUN ./Docker/scripts/generate_database.sh

# Compilar
RUN npm run build

# Podar devDependencies para runtime más liviano
RUN npm prune --omit=dev


# ---------- FINAL (RUNTIME) ----------
FROM node:20-slim AS final

RUN apt-get update && apt-get install -y \
  tzdata ffmpeg bash openssl curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

ENV TZ=America/Sao_Paulo
ENV NODE_ENV=production
ENV DOCKER_ENV=true

WORKDIR /evolution

# Copiar solo lo necesario desde el builder
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

# Usa bash porque el script es .sh y encadenamos comandos
ENTRYPOINT ["/bin/bash", "-c", ". ./Docker/scripts/deploy_database.sh && npm run start:prod" ]
