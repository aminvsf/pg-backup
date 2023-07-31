#!/bin/bash

function create_postgres_backup() {

  # Set required variables.

  local postgres_password=""
  local postgres_host=""
  local postgres_port=""
  local postgres_user=""
  local postgres_database=""

  while [ $# -gt 0 ]; do
    case "$1" in
    --pg-password)
      postgres_password="$2"
      shift 2
      ;;
    --pg-host)
      postgres_host="$2"
      shift 2
      ;;
    --pg-port)
      postgres_port="$2"
      shift 2
      ;;
    --pg-user)
      postgres_user="$2"
      shift 2
      ;;
    --pg-database)
      postgres_database="$2"
      shift 2
      ;;
    *)
      echo "[ERROR] Unknown option: $1"
      exit 1
      ;;
    esac
  done

  # Validate postgres credentials.

  echo "[INFO] Validating postgres credentials ..."

  local validation_error_msg=""
  validation_error_msg=$(PGPASSWORD="$postgres_password" psql -h "$postgres_host" -p "$postgres_port" -U "$postgres_user" -d "$postgres_database" -c "SELECT 1;" 2>&1)

  if [ $? -eq 0 ]; then
    echo "[INFO] Successfully validated credentials."
  else
    echo "[ERROR] Failed to connect to Postgresql database: $validation_error_msg"
    exit 1
  fi

  # Creating postgres backup.

  echo "[INFO] Creating backup from Postgresql ..."

  local backup_creation_error_msg=""
  backup_creation_error_msg=$(PGPASSWORD="$postgres_password" pg_dump -h "$postgres_host" -p "$postgres_port" -U "$postgres_user" -d "$postgres_database" >/tmp/db_backup.sql)

  if [ $? -eq 0 ]; then
    echo "[INFO] Successfully created Postgresql backup."
  else
    echo "[ERROR] Failed to create backup from Postgresql: $backup_creation_error_msg"
    exit 1
  fi
}

function upload_postgres_backup_to_s3() {

    # Set required variables.

    local postgres_database=""

    while [ $# -gt 0 ]; do
      case "$1" in
      --pg-database)
        postgres_database="$2"
        shift 2
        ;;
      *)
        echo "[ERROR] Unknown option: $1"
        exit 1
        ;;
      esac
    done

    local NOW=""
    NOW=$(date +"%Y-%m-%d-%H%M%S")

    local access_keys=()
    for access_key in "${!ACCESS_KEY_@}"; do
      access_keys+=("$access_key")
    done

    local secret_keys=()
    for secret_key in "${!SECRET_KEY_@}"; do
      secret_keys+=("$secret_key")
    done

    local bucket_names=()
    for bucket_name in "${!BUCKET_NAME_@}"; do
      bucket_names+=("$bucket_name")
    done

    local endpoint_urls=()
    for endpoint_url in "${!ENDPOINT_URL_@}"; do
      endpoint_urls+=("$endpoint_url")
    done

    local buckets_keep_previous_backups=()
    for bucket_keep_previous_backups in "${!BUCKET_KEEP_PREVIOUS_BACKUPS_@}"; do
      buckets_keep_previous_backups+=("$bucket_keep_previous_backups")
    done

    local s3_credentials_count=0
    s3_credentials_count="${#access_keys[@]}"

    for ((i = 0; i < s3_credentials_count; i++)); do

      local ACCESS_KEY=""
      local SECRET_KEY=""
      local BUCKET_NAME=""
      local ENDPOINT_URL=""
      local BUCKET_KEEP_PREVIOUS_BACKUPS=""

      ACCESS_KEY="${!access_keys[i]}"
      SECRET_KEY="${!secret_keys[i]}"
      BUCKET_NAME="${!bucket_names[i]}"
      ENDPOINT_URL="${!endpoint_urls[i]}"
      BUCKET_KEEP_PREVIOUS_BACKUPS="${!buckets_keep_previous_backups[i]}"

      echo "[INFO] Attempting to set lifecycle policy for bucket $((i+1)) ..."

      local lifecycle_setting_error_msg=""
      lifecycle_setting_error_msg=$(s3cmd setlifecycle lifecycle.xml s3://"$BUCKET_NAME" --host=https://"$ENDPOINT_URL" --host-bucket="https://%(bucket)s.$ENDPOINT_URL" --access_key="$ACCESS_KEY" --secret_key="$SECRET_KEY")

      if [ $? -eq 0 ]; then
        echo "[INFO] Successfully set lifecycle policy for bucket $((i+1))."
      else
        echo "[WARNING] Failed to set lifecycle policy for bucket $((i+1)): $lifecycle_setting_error_msg"
      fi

      echo "[INFO] Uploading backup to S3 bucket $((i+1)) ..."

      local backup_name=""
      if [ "$BUCKET_KEEP_PREVIOUS_BACKUPS" == "true" ]; then
        backup_name="backup_$NOW.sql"
      else
        backup_name="backup.sql"
      fi

      local backup_upload_error_msg=""
      backup_creation_error_msg=$(s3cmd put /tmp/db_backup.sql s3://"$BUCKET_NAME"/postgres-backups/"$postgres_database"/"$backup_name" --host=https://"$ENDPOINT_URL" --host-bucket="https://%(bucket)s.$ENDPOINT_URL" --access_key="$ACCESS_KEY" --secret_key="$SECRET_KEY")

      if [ $? -eq 0 ]; then
        echo "[INFO] Successfully uploaded backup to bucket $((i+1))."
      else
        echo "[ERROR] Failed to upload backup to bucket $((i+1)): $backup_upload_error_msg"
      fi

    done
}

POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_HOST=${POSTGRES_HOST}
POSTGRES_PORT=${POSTGRES_PORT}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_DATABASE=${POSTGRES_DATABASE}

main () {
  echo "[INFO] Backup started."

  create_postgres_backup --pg-password "$POSTGRES_PASSWORD" --pg-host "$POSTGRES_HOST" --pg-port "$POSTGRES_PORT" --pg-user "$POSTGRES_USER" --pg-database "$POSTGRES_DATABASE"
  upload_postgres_backup_to_s3 --pg-database "$POSTGRES_DATABASE"

  echo "[INFO] Backup finished."
}

main
