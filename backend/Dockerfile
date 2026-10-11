
# Stage 1: Install production dependencies
FROM node:24-alpine AS dependencies

WORKDIR /app

COPY package*.json ./

RUN npm ci --omit=dev


# Stage 2: Minimal application runtime
FROM node:24-alpine AS runtime

ENV NODE_ENV=production

WORKDIR /app

# Apply Alpine security updates and create a non-root user.
RUN apk upgrade --no-cache && \
    addgroup -S -g 10001 opsflow && \
    adduser -S -D -H -u 10001 -G opsflow opsflow && \
    rm -rf /usr/local/lib/node_modules/npm \
           /usr/local/bin/npm \
           /usr/local/bin/npx \
           /opt/yarn* \
           /usr/local/bin/corepack

# Copy only production dependencies.
COPY --from=dependencies /app/node_modules ./node_modules

# Copy application source and package metadata.
COPY --chown=10001:10001 src ./src
COPY --chown=10001:10001 package*.json ./

USER 10001:10001

EXPOSE 3000

CMD ["node", "src/server.js"]
