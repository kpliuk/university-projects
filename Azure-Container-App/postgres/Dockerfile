FROM postgres:15-alpine

COPY start-postgres.sh /usr/local/bin/start-postgres.sh

RUN chmod +x /usr/local/bin/start-postgres.sh

ENTRYPOINT ["start-postgres.sh"]
CMD ["postgres"]
