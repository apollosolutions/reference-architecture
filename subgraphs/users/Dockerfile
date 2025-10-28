FROM node:22-bookworm-slim

WORKDIR /usr/src/app

COPY package.json .
COPY package-lock.json .

RUN npm install --no-save

COPY src ./src
COPY tsconfig.json .
COPY codegen.ts .

RUN npm run build

# Copy schema to /app directory for operator to access
RUN mkdir -p /app
COPY schema.graphql /app/schema.graphql

EXPOSE 4001

CMD [ "node", "--require","./dist/tracing.js","./dist/index.js" ]
