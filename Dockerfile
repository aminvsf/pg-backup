FROM ubuntu:22.04

# Timezone (You can set your desired timezone!)
ENV TZ=Asia/Tehran

# Run the update.
RUN apt-get update && apt-get upgrade -y

# Install apt-utils, PostgreSQL client and s3cmd CLI.
RUN apt-get install -y apt-utils ca-certificates
RUN DEBIAN_FRONTEND=noninteractive TZ=Asia/Tehran apt-get install -y postgresql-client s3cmd

# Copy the backup script
COPY backup.sh /

# Copy the lifecycle file.
COPY lifecycle.xml /

# Make the backup script executable.
RUN chmod +x /backup.sh
