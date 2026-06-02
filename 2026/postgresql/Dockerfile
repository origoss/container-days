FROM postgres:16
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY stat_collector.sh /usr/local/bin/stat_collector.sh
RUN apt update && apt install netcat-traditional
