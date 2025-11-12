FROM node:22-bookworm-slim

WORKDIR /usr/src/app

COPY package.json .
COPY package-lock.json .

RUN npm install --no-save

COPY src ./src
COPY tsconfig.json .
COPY codegen.ts .
COPY schema.graphql .
COPY keys ./keys
RUN npm run build

# COPY ./src/keys /dist/keys
EXPOSE 4001

CMD [ "node", "--require","./dist/tracing.js","./dist/index.js" ]
