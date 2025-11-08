# ------------------------------------------------------------------
# ETAPA BUILDER: USANDO NODE:20-SLIM Y APT-GET
# ------------------------------------------------------------------
FROM node:20-slim AS builder

# En la etapa builder
RUN apt-get update && apt-get install -y \
    git ffmpeg wget curl bash openssl build-essential python3 \
    libvips-dev libvips \
    **dos2unix** \
    && rm -rf /var/lib/apt/lists/*
    
LABEL version="2.3.1" description="Api to control whatsapp features through http requests." 
LABEL maintainer="Davidson Gomes" git="https://github.com/DavidsonGomes"
LABEL contact="contato@evolution-api.com"

WORKDIR /evolution

COPY ./package*.json ./
COPY ./tsconfig.json ./
COPY ./tsup.config.ts ./

# CORRECCIÓN FINAL: Instalación Forzada de NPM
# Esto ignora el script de compilación fallido de 'baileys' y resuelve el 'exit code: 2'.
RUN npm cache clean --force && npm install --no-scripts

COPY ./src ./src
COPY ./public ./public
COPY ./prisma ./prisma
COPY ./manager ./manager
COPY ./.env.example ./.env
COPY ./runWithProvider.js ./

COPY ./Docker ./Docker

RUN chmod +x ./Docker/scripts/* && dos2unix ./Docker/scripts/*

RUN ./Docker/scripts/generate_database.sh

RUN npm run build

# ------------------------------------------------------------------
# ETAPA FINAL: ENTORNO DE EJECUCIÓN SLIM
# ------------------------------------------------------------------
FROM node:20-slim AS final

# Paquetes de ejecución
RUN apt-get update && \
    apt-get install -y \
    git ffmpeg wget curl bash openssl build-essential python3 \
    libvips-dev libvips \
    && rm -rf /var/lib/apt/lists/*

ENV TZ=America/Sao_Paulo
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

ENV DOCKER_ENV=true

EXPOSE 8080

# ENTRYPOINT corregido para la ruta interna
ENTRYPOINT ["/bin/bash", "-c", ". ./Docker/scripts/deploy_database.sh && npm run start:prod" ]