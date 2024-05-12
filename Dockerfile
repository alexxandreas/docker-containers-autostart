FROM --platform=linux/amd64 node:14-alpine

RUN apk add ffmpeg

RUN apk add --no-cache tzdata
ENV TZ=Europe/Moscow
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

WORKDIR /opt/app

COPY package.json package.json
COPY package-lock.json package-lock.json
RUN npm ci

COPY index.js index.js
COPY src/ src/

ENTRYPOINT []
CMD node index.js