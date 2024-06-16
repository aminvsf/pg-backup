FROM debian:bookworm-slim

ARG PG_VERSION=16

# Install PostgreSQL client and s3cmd.
RUN apt-get update && \
    apt-get install -y apt-utils && \
    apt-get install -y s3cmd postgresql-common && \
    bash /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y && \
    apt-get install postgresql-client-$PG_VERSION -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY backup.sh .
RUN chmod +x /backup.sh
