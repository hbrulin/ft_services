
FROM alpine:latest

RUN apk update && apk add influxdb \
&& apk add --no-cache --upgrade bash

EXPOSE 8086
CMD influxd run -config /etc/influxdb.conf