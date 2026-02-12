#!/usr/bin/env bash

set -euo pipefail  # stop if error

############################################
# Default values
############################################

ENV_FILE="config/db.env"
SQL_FILE=""              # <-- no default 
OUT_DIR="data"
LOG_DIR="logs"
FORMAT="tsv"             # tsv or csv
COMPRESS=1               # 1 = gzip, 0 = no compression

############################################
# Parse arguments
############################################

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-file=*)
      ENV_FILE="${1#*=}"
      ;;
    --sql=*)
      SQL_FILE="${1#*=}"
      ;;
    --format=*)
      FORMAT="${1#*=}"
      ;;
    --no-compress)
      COMPRESS=0
      ;;
    --help)
      echo "Usage:"
      echo "  ./run_sql_export.sh --sql=PATH [options]"
      echo ""
      echo "Required:"
      echo "  --sql=PATH         Path to SQL file"
      echo ""
      echo "Options:"
      echo "  --env-file=PATH    Path to env file (default: config/db.env)"
      echo "  --format=tsv|csv   Output format (default: tsv)"
      echo "  --no-compress      Disable gzip compression"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
done

############################################
# Require SQL file
############################################

if [[ -z "$SQL_FILE" ]]; then
  echo "Error: --sql=PATH is required"
  exit 1
fi

############################################
# Go to project root
############################################

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

############################################
# Check files
############################################

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Env file not found: $ENV_FILE"
  exit 1
fi

if [[ ! -f "$SQL_FILE" ]]; then
  echo "SQL file not found: $SQL_FILE"
  exit 1
fi

############################################
# Optional CSV conversion
############################################

if [[ "$FORMAT" != "tsv" && "$FORMAT" != "csv" ]]; then
  echo "FORMAT must be 'tsv' or 'csv'"
  exit 1
fi

if [[ "$FORMAT" == "csv" ]]; then
  sed -i 's/\t/,/g' "$OUTPUT_FILE"
fi

############################################
# Load DB config
############################################

source "$ENV_FILE"

if [[ -z "$DB_HOST" || -z "$DB_PORT" || -z "$DB_NAME" || -z "$DB_USER" || -z "$DB_PASS" ]]; then
  echo "Missing DB configuration in $ENV_FILE"
  exit 1
fi

############################################
# Prepare folders
############################################

mkdir -p "$OUT_DIR"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BASE_NAME=$(basename "$SQL_FILE" .sql)

OUTPUT_FILE="$OUT_DIR/${BASE_NAME}_${DB_NAME}_${TIMESTAMP}.${FORMAT}"
LOG_FILE="$LOG_DIR/${BASE_NAME}_${DB_NAME}_${TIMESTAMP}.log"

exec > >(tee -a "$LOG_FILE") 2>&1

############################################
# Run query
############################################

echo "Running query..."
echo "SQL: $SQL_FILE"
echo "Output: $OUTPUT_FILE"
echo "Log: $LOG_FILE"

START_TIME=$(date +%s)

mariadb \
  --host="$DB_HOST" \
  --port="$DB_PORT" \
  --user="$DB_USER" \
  --password="$DB_PASS" \
  --database="$DB_NAME" \
  --batch --raw \
  < "$SQL_FILE" \
  > "$OUTPUT_FILE"

############################################
# Optional compression
############################################

if [[ "$COMPRESS" -eq 1 ]]; then
  gzip "$OUTPUT_FILE"
  OUTPUT_FILE="${OUTPUT_FILE}.gz"
fi

############################################
# Summary
############################################

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo "Done in ${ELAPSED} seconds"
echo "File: $OUTPUT_FILE"
echo "Size: $(du -h "$OUTPUT_FILE" | awk '{print $1}')"
echo "Log saved in: $LOG_FILE"

