FROM node:24-alpine AS dependencies

WORKDIR /app

COPY package*.json ./

RUN npm ci --omit=dev


FROM node:24-alpine AS runtime

ENV NODE_ENV=production

WORKDIR /app

# Create dedicated non-root application user with fixed UID/GID.
# Fixed numeric IDs allow Kubernetes to verify runAsNonRoot.
# Apply available Alpine security updates before dropping privileges.
RUN apk upgrade --no-cache zlib && \
    addgroup -S -g 10001 opsflow && \
    adduser -S -D -H -u 10001 -G opsflow opsflow

COPY --from=dependencies /app/node_modules ./node_modules

COPY --chown=10001:10001 src ./src

COPY --chown=10001:10001 package*.json ./

USER 10001:10001

EXPOSE 3000

CMD ["node", "src/server.js"]