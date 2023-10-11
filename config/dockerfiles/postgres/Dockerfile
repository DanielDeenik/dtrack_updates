# syntax=docker/dockerfile:1

# Build
FROM postgres:15 as postgres-build
RUN apt-get update && apt-get install -y wget build-essential libarchive-tools make postgresql-server-dev-15
RUN wget https://bitbucket.org/neadwerx/cyanaudit/get/master.zip -O /tmp/cyanaudit.zip
RUN mkdir /tmp/cyanaudit && bsdtar -xvf /tmp/cyanaudit.zip --strip-components=1 -C /tmp/cyanaudit
RUN rm -rf /tmp/cyanaudit/dist
RUN mkdir -p /tmp/build/cyanaudit && cp -a /tmp/cyanaudit /tmp/build/
RUN cd /tmp/build/cyanaudit && make && make install DESTDIR=/build

# Production
FROM postgres:15
RUN apt-get update && \
    apt-get install -y postgresql-plpython3-15 python3-pip libdbi-perl libdbd-pg-perl && \
    pip3 install --break-system-packages asyncio guardpost[jwt] && \
    cpan Parse::CSV Date::Parse
COPY --from=postgres-build /build /
COPY --from=postgres-build /tmp/cyanaudit /opt/cyanaudit
