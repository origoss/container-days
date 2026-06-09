FROM postgres:16
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY stat_collector.sh /usr/local/bin/stat_collector.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/stat_collector.sh \
    && apt update && apt install netcat-traditional