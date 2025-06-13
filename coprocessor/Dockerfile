FROM node:22-bookworm-slim

WORKDIR /usr/src/app

COPY package.json .
COPY package-lock.json .

RUN npm install --no-save

COPY src ./src
COPY tsconfig.json .

RUN npm run build:tsc

EXPOSE 8081

CMD [ "node", "./dist/index.js" ]
