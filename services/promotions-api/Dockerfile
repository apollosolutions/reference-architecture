FROM node:22-bookworm-slim AS builder

WORKDIR /usr/src/app

COPY package.json .
COPY package-lock.json* ./

RUN npm install

COPY tsconfig.json .
COPY src ./src

RUN npm run build

FROM node:22-bookworm-slim

WORKDIR /usr/src/app

COPY package.json .
COPY package-lock.json* ./

RUN npm install --omit=dev

COPY --from=builder /usr/src/app/dist ./dist

EXPOSE 4010

CMD ["node", "dist/index.js"]
