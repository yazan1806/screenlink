FROM node:24-bookworm-slim AS ui
WORKDIR /app/desktop
COPY desktop/package*.json ./
RUN npm ci --ignore-scripts
COPY desktop/ ./
RUN npm run build
FROM node:24-bookworm-slim
ENV NODE_ENV=production
WORKDIR /app/server
COPY server/package*.json ./
RUN npm ci --omit=dev
COPY server/ ./
COPY --from=ui /app/desktop/dist /app/desktop/dist
EXPOSE 3000
CMD ["node", "index.mjs"]
