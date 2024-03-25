FROM alpine:3.18 as builder

RUN apk update &&\
    apk upgrade &&\ 
    apk add --no-cache linux-headers alpine-sdk cmake tcl openssl-dev zlib-dev

WORKDIR /tmp

# belabox patched srt
#
ARG BELABOX_SRT_VERSION=belabox
RUN mkdir -p /build; \
    git clone https://github.com/IRLServer/srt-new.git /build/srt; \
    cd /build/srt; \
    git checkout $BELABOX_SRT_VERSION; \
    ./configure; \
    make -j${nproc}; \
    make install;

# belabox srtla
#
ARG SRTLA_VERSION=main
RUN mkdir -p /build; \
    git clone https://github.com/IRLServer/srtla.git /build/srtla; \
    cd /build/srtla; \
    git checkout $SRTLA_VERSION; \
    make -j${nproc};

RUN cp /build/srtla/srtla_rec /build/srtla/srtla_send /usr/local/bin

ENV LD_LIBRARY_PATH /lib:/usr/lib:/usr/local/lib64
ARG SRT_LIVE_SERVER_VERSION=master
RUN set -xe; \
    mkdir -p /build; \
    git clone https://github.com/IRLServer/irl-srt-server.git /build/srt-live-server; \
    cd /build/srt-live-server; \
    git checkout $SRT_LIVE_SERVER_VERSION; \
    git submodule update --init; \
    cmake . -DCMAKE_BUILD_TYPE=Release; \
    make -j${nproc}; \
    cp bin/* /usr/local/bin;


# runtime container with server
#
FROM node:alpine3.18
ENV LD_LIBRARY_PATH /lib:/usr/lib:/usr/local/lib64
RUN apk add --update --no-cache openssl libstdc++ supervisor perl coreutils

COPY --from=builder /usr/local/lib /usr/local/lib
COPY --from=builder /usr/local/include /usr/local/include
COPY --from=builder /usr/local/bin /usr/local/bin

COPY files/sls.conf /etc/sls/sls.conf
COPY files/supervisord.conf /etc/supervisord.conf
COPY files/logprefix /usr/local/bin/logprefix
COPY server/ /app
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh
RUN chmod 755 /usr/local/bin/logprefix;

WORKDIR /app
RUN yarn --frozen-lockfile --production

EXPOSE 5000/udp 8181/tcp 8282/udp 3000/tcp
ENTRYPOINT ["/entrypoint.sh"]
