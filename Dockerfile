# Start with the express-c development image
FROM ghcr.io/williamcotton/express-c:master AS buildstage

ENV LD_LIBRARY_PATH /usr/local/lib

WORKDIR /app

COPY . .

# Build the production app
RUN make app-prod

# Copy the shared objects to the /app/sdeps directory
RUN ldd /app/build/app | tr -s '[:blank:]' '\n' | grep '^/' | \
  xargs -I % sh -c 'mkdir -p $(dirname sdeps%); cp % sdeps%;'

# Grab a fresh copy of our linux image
FROM ubuntu:jammy AS deploystage

WORKDIR /app

# Copy the shared objects to our new image
COPY --from=buildstage /app/sdeps/lib /usr/lib
COPY --from=buildstage /app/sdeps/usr/local/lib /usr/lib

# Copy binaries to the new image
COPY --from=buildstage /usr/local/bin /usr/local/bin

# Copy the app executable
COPY --from=buildstage /app/build/app /app/build/app

# Copy our database migrations
COPY --from=buildstage /app/db/migrations /app/db/migrations

# Run the app
CMD /app/build/app
