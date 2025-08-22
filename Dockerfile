# ---- build deps + compile ----
FROM node:22-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# ---- runtime (thin) ----
FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production

# copy only what runtime needs
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/dist ./dist
# (Option A) start Node directly — no package.json needed in final image
# CMD ["node","dist/main.js"]

# (Option B) keep npm script: also copy package files
COPY --from=deps /app/package*.json ./

EXPOSE 3000
# Healthcheck (optional)
HEALTHCHECK --interval=10s --timeout=3s --retries=10 \
  CMD wget -qO- http://127.0.0.1:3000/ >/dev/null 2>&1 || exit 1

# If using Option B:
CMD ["npm","run","start:prod"]
# If you prefer Option A, comment the line above and uncomment the Node CMD.
