FROM node:18-alpine as node-build

ENV NODE_ENV=production

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm install --production

COPY . .

CMD node index.js
