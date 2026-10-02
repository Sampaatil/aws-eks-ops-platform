# syntax=docker/dockerfile:1

FROM node:24-alpine AS dependencies

WORKDIR /app

COPY package*.json ./

RUN npm ci --omit=dev


FROM node:24-alpine AS runtime

ENV NODE_ENV=production

WORKDIR /app

RUN addgroup -S opsflow && \
    adduser -S opsflow -G opsflow

COPY --from=dependencies /app/node_modules ./node_modules

COPY --chown=opsflow:opsflow src ./src

COPY --chown=opsflow:opsflow package*.json ./

USER opsflow

EXPOSE 3000

CMD ["node", "src/server.js"]