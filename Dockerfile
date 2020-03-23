FROM alpine:latest as ords

ARG ORDS_VERSION=19.2.0.199.1647
ARG ORDS_URL=https://your.local.mirror/ords-${ORDS_VERSION}.zip

ADD ${ORDS_URL} ords.zip
RUN unzip ords.zip

FROM tomcat:8.5-jre8-alpine

ENV ORDS_HOME=/opt/oracle/ords \
    ORDS_VERSION=${ORDS_VERSION} \
    DB_USERNAME=www_user \
    DB_PASSWORD=password \
    DB_HOSTNAME=database.wm.edu \
    DB_PORT=1521 \
    DB_INITIALSIZE=25 \
    DB_MAXTOTAL=100 \
    URI_PATH=ssb8 \
    DEFAULT_PAGE=twbkwbis.P_GenMenu?name=homepage


RUN mkdir -p $ORDS_HOME && mkdir -p $ORDS_HOME/params
COPY --from=ords /ords.war $ORDS_HOME/ords.war
COPY run.sh $ORDS_HOME
RUN chmod +x $ORDS_HOME/run.sh && rm -rf /usr/local/tomcat/webapps/*
COPY static /opt/static

RUN apk add --no-cache tzdata curl \
    && cp /usr/share/zoneinfo/America/New_York /etc/localtime \
    && addgroup -g 91 -S tomcat \
    && adduser -S -G tomcat -u 91 -h /usr/local/tomcat tomcat \
    && chown -R tomcat:tomcat /usr/local/tomcat /opt/oracle/

HEALTHCHECK CMD curl -f http://localhost:8080/$URI_PATH/ || exit 1

USER tomcat

CMD $ORDS_HOME/run.sh
