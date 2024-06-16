#!/bin/bash

function create_backup {
  local pg_host=""
  local pg_port=""
  local pg_database=""
  local pg_user=""
  local pg_password=""
  while [ $# -gt 0 ]; do
    case "$1" in
    --pg-host)
      pg_host="$2"
      shift 2
      ;;
    --pg-port)
      pg_port="$2"
      shift 2
      ;;
    --pg-database)
      pg_database="$2"
      shift 2
      ;;
    --pg-user)
      pg_user="$2"
      shift 2
      ;;
    --pg-password)
      pg_password="$2"
      shift 2
      ;;
    *)
      echo "[ERROR] Unknown option: $1"
      exit 1
      ;;
    esac
  done

  echo "[INFO] Creating backup..."
  local backup_name
  backup_name="$pg_database"_"$(date +%Y%m%d)".sql
  export PGPASSWORD=$pg_password
  pg_dump -h "$pg_host" -p "$pg_port" -U "$pg_user" -d "$pg_database" > "$backup_name"

  echo "[INFO] Compressing backup..."
  local compressed_backup_name
  compressed_backup_name="$backup_name".tar.xz
  tar -cf "$compressed_backup_name" "$backup_name"

  echo "[INFO] Uploading backup..."
  local access_keys=()
  for access_key in "${!ACCESS_KEY_@}"; do
    access_keys+=("$access_key")
  done
  local secret_keys=()
  for secret_key in "${!SECRET_KEY_@}"; do
    secret_keys+=("$secret_key")
  done
  local endpoint_urls=()
  for endpoint_url in "${!ENDPOINT_URL_@}"; do
    endpoint_urls+=("$endpoint_url")
  done
  local bucket_urls=()
  for bucket_url in "${!BUCKET_URL_@}"; do
    bucket_urls+=("$bucket_url")
  done
  local bucket_names=()
  for bucket_name in "${!BUCKET_NAME_@}"; do
    bucket_names+=("$bucket_name")
  done

  local buckets_count="${#bucket_names[@]}"
  for ((i = 0; i < buckets_count; i++)); do
    echo "[INFO] Uploading to bucket $((i+1))..."
    local access_key="${!access_keys[i]}"
    local secret_key="${!secret_keys[i]}"
    local endpoint_url="${!endpoint_urls[i]}"
    local bucket_url="${!bucket_urls[i]}"
    local bucket_name="${!bucket_names[i]}"
    s3cmd put "$compressed_backup_name" \
    s3://"$bucket_name"/"$pg_database"/ \
    --host="$endpoint_url" \
    --host-bucket="$bucket_url" \
    --access_key="$access_key" \
    --secret_key="$secret_key"
  done
}

pg_host=${PG_HOST}
pg_port=${PG_PORT}
pg_database=${PG_DATABASE}
pg_user=${PG_USER}
pg_password=${PG_PASSWORD}

function main {
  create_backup \
  --pg-host "$pg_host" \
  --pg-port "$pg_port" \
  --pg-database "$pg_database" \
  --pg-user "$pg_user" \
  --pg-password "$pg_password"
}

main
