# Start with the express-c development image
FROM ghcr.io/williamcotton/express-c:1.1.0 AS buildstage

ENV LD_LIBRARY_PATH /usr/local/lib

WORKDIR /app

COPY . .
