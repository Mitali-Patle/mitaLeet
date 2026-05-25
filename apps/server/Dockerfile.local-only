FROM node:20-alpine
WORKDIR /app

COPY package*.json ./
# Skip postinstall (prisma generate) here — schema.prisma not copied yet
RUN npm ci --ignore-scripts

COPY . .
# Now schema is present: generate the Prisma client for the correct binary target
RUN npx prisma generate
RUN npm run build

ENV NODE_ENV=production
EXPOSE 3000
# Regenerate at runtime to ensure binary matches the actual runtime environment,
# then run migrations, then start the server
CMD ["sh", "-c", "npx prisma generate && npx prisma migrate deploy && node dist/main"]
