# Nyaya API image (used by deploy/staging). Build context: backend/.
FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build && npm prune --omit=dev

FROM node:24-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /app/package.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
# Migrations are applied on start; the seed reads the question bank.
COPY --from=build /app/drizzle ./drizzle
COPY --from=build /app/seed ./seed
USER node
EXPOSE 3000
CMD ["node", "dist/main.js"]
