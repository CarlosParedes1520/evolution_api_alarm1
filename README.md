FROM node:20-slim AS builder

RUN apt-get update && apt-get install -y \
  git ca-certificates \
  build-essential python3 pkg-config \
  curl bash openssl dos2unix \

  libvips-dev libvips \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /evolution
ENV npm_config_python=/usr/bin/python3

ENV npm_config_build_from_source=false
ENV npm_config_sharp_ignore_global_libvips=1

COPY ./package*.json ./
COPY ./tsconfig.json ./ 
COPY ./tsup.config.ts ./


RUN which git && git --version && node -v && npm -v


RUN npm ci --no-audit --no-fund


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
