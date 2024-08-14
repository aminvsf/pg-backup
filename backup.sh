#!/bin/bash

# Creating Backup
echo "[INFO] Creating backup..."
backup_name="${PG_DATABASE}"_"$(date +%Y%m%d%H%M%S)".sql
export PGPASSWORD=${PG_PASSWORD}
if ! pg_dump -h "${PG_HOST}" -p "${PG_PORT}" -U "${PG_USER}" -d "${PG_DATABASE}" > "$backup_name"; then
  echo "[ERROR] Creating backup failed."
  rm "$backup_name"
  exit 1
fi

# Compressing Backup
echo "[INFO] Compressing backup..."
if ! tar -czf "$backup_name".tar.gz "$backup_name"; then
  echo "[ERROR] Compressing backup failed."
  rm "$backup_name"
  rm "$backup_name".tar.gz
  exit 1
fi

# Uploading Backup
echo "[INFO] Uploading backup..."
collect_keys() {
  local prefix="$1"
  local -n array_ref="$2"
  for key in $(compgen -v); do
    if [[ $key == $prefix* ]]; then
      array_ref+=("$key")
    fi
  done
}
access_keys=()
secret_keys=()
endpoint_urls=()
bucket_urls=()
bucket_names=()
collect_keys "ACCESS_KEY_" access_keys
collect_keys "SECRET_KEY_" secret_keys
collect_keys "ENDPOINT_URL_" endpoint_urls
collect_keys "BUCKET_URL_" bucket_urls
collect_keys "BUCKET_NAME_" bucket_names
buckets_count="${#bucket_names[@]}"
for ((i = 0; i < buckets_count; i++)); do
  echo "[INFO] Uploading backup to bucket $((i+1))..."
  s3cmd put "$backup_name".tar.gz \
  s3://"${!bucket_names[i]}"/"${PG_DATABASE}"/ \
  --host="${!endpoint_urls[i]}" \
  --host-bucket="${!bucket_urls[i]}" \
  --access_key="${!access_keys[i]}" \
  --secret_key="${!secret_keys[i]}" > /dev/null
done
