FROM node:alpine as build
WORKDIR /usr/app
COPY . /usr/app
RUN npm i
RUN npm run build

FROM nginx:1.23.1-alpine
EXPOSE 80
COPY ./docker/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /usr/app/dist /usr/share/nginx/html
