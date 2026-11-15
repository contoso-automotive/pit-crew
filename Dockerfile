# Pit Crew container image. Two stages: build with dev tools, ship without them.
# Alpine keeps the image small, which the Azure Well-Architected Framework recommends
# for a smaller attack surface and faster starts.
FROM node:26-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json tsconfig.build.json ./
COPY src ./src
RUN npm run build

FROM node:26-alpine
ENV NODE_ENV=production PORT=8080
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /app/dist ./dist
COPY data ./data
COPY public ./public
# Run as the image's unprivileged node user, never as root.
USER node
EXPOSE 8080
CMD ["node", "dist/server.js"]
