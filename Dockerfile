#Use debian:stable-slim as a builder and then copy everything.
FROM debian:stable-slim as builder

#Set mosquitto and plugin versions.
#Change them for your needs.
ENV MOSQUITTO_VERSION=1.6.9
ENV PLUGIN_VERSION=0.6.3
ENV GO_VERSION=1.13.8

WORKDIR /app

#Get mosquitto build dependencies.
RUN apt-get update && apt-get install -y libwebsockets8 libwebsockets-dev libc-ares2 libc-ares-dev openssl uuid uuid-dev wget build-essential git
RUN mkdir -p mosquitto/auth mosquitto/conf.d

RUN wget http://mosquitto.org/files/source/mosquitto-${MOSQUITTO_VERSION}.tar.gz
RUN tar xzvf mosquitto-${MOSQUITTO_VERSION}.tar.gz && rm mosquitto-${MOSQUITTO_VERSION}.tar.gz 

#Build mosquitto.
RUN cd mosquitto-${MOSQUITTO_VERSION} && make WITH_WEBSOCKETS=yes && make install && cd ..

#Get Go.
RUN wget https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz && tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
RUN export PATH=$PATH:/usr/local/go/bin && go version && rm go${GO_VERSION}.linux-amd64.tar.gz

#Get the plugin.
RUN wget https://github.com/iegomez/mosquitto-go-auth/archive/${PLUGIN_VERSION}.tar.gz \
    && ls -l \
    && tar xvf *.tar.gz --strip-components=1 \
    && rm -Rf go*.tar.gz \
    && ls -l

#Build the plugin.
RUN export PATH=$PATH:/usr/local/go/bin && export CGO_CFLAGS="-I/usr/local/include -fPIC" && export CGO_LDFLAGS="-shared" &&  make

#Start from a new image.
FROM debian:stable-slim

#Get mosquitto dependencies.
RUN apt-get update && apt-get install -y libwebsockets8 libc-ares2 openssl uuid

#Setup mosquitto env.
RUN mkdir -p /mosquitto/config /mosquitto/data /mosquitto/log
RUN groupadd mosquitto \
    && useradd -s /sbin/nologin mosquitto -g mosquitto -d /mosquitto \
    && chown -R mosquitto:mosquitto /mosquitto/

#Copy confs, plugin so and mosquitto binary.
COPY --from=builder /app/mosquitto/ /mosquitto/
COPY --from=builder /app/go-auth.so /mosquitto/go-auth.so
COPY --from=builder /usr/local/sbin/mosquitto /usr/sbin/mosquitto

VOLUME ["/mosquitto/data", "/mosquitto/log"]

# Set up the default command
EXPOSE 1883

CMD ["/usr/sbin/mosquitto", "-c", "/mosquitto/config/mosquitto.conf"]