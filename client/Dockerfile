FROM node:alpine as build
ARG BACKEND_URL
ARG OTEL_COLLECTOR_URL
WORKDIR /usr/app
COPY . /usr/app
ENV VITE_BACKEND_URL=$BACKEND_URL
ENV VITE_OTEL_COLLECTOR_URL=$OTEL_COLLECTOR_URL
RUN npm i
RUN npm run build

FROM nginx:1.23.1-alpine
EXPOSE 80
COPY ./docker/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /usr/app/dist /usr/share/nginx/html
