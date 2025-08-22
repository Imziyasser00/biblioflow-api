FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production

# runtime deps + built code
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/dist ./dist

# Optional but handy
EXPOSE 3000
# Healthcheck: considers the app "up" if it responds at /
HEALTHCHECK --interval=10s --timeout=3s --retries=10 \
  CMD wget -qO- http://127.0.0.1:3000/ >/dev/null 2>&1 || exit 1

# Start Nest without npm (avoids needing package.json)
CMD ["node","dist/main.js"]
