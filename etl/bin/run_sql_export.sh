#!/usr/bin/env bash
set -euo pipefail

############################################
# Default values
############################################
ENV_FILE="config/db.env"
SQL_FILE=""
OUT_DIR="data"
LOG_DIR="logs"

DB_VERSION=""
OVERWRITE=0

MODE="main"   # main | dev
DB_NAME=""    # resolved later

usage() {
  cat <<EOF
Usage:
  etl/bin/run_sql_export.sh --sql=PATH [options]

Required:
  --sql=PATH

Options:
  --env-file=PATH        Path to env file (default: config/db.env)
  --mode=main|dev        Target database (default: main)
  --db-version=LABEL     Version label in filename (default: timestamp)
  --overwrite            Overwrite existing output file
  --help                 Show help

Modes:
  main -> triggerIO
  dev  -> triggerIO-dev
EOF
}

############################################
# Parse arguments
############################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-file=*)   ENV_FILE="${1#*=}" ;;
    --sql=*)        SQL_FILE="${1#*=}" ;;
    --mode=*)       MODE="${1#*=}" ;;
    --db-version=*) DB_VERSION="${1#*=}" ;;
    --overwrite)    OVERWRITE=1 ;;
    --help)         usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

############################################
# Require SQL file
############################################
[[ -n "$SQL_FILE" ]] || { echo "Error: --sql=PATH is required" >&2; exit 1; }

############################################
# Go to project root
############################################
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

############################################
# Check files
############################################
[[ -f "$ENV_FILE" ]] || { echo "Env file not found: $ENV_FILE" >&2; exit 1; }
[[ -f "$SQL_FILE" ]] || { echo "SQL file not found: $SQL_FILE" >&2; exit 1; }

############################################
# Load DB config (NO DB_NAME here)
############################################
# shellcheck disable=SC1090
source "$ENV_FILE"

: "${DB_HOST:?Missing DB_HOST in $ENV_FILE}"
: "${DB_PORT:?Missing DB_PORT in $ENV_FILE}"
: "${DB_USER:?Missing DB_USER in $ENV_FILE}"
: "${DB_PASS:?Missing DB_PASS in $ENV_FILE}"

############################################
# Resolve DB name from mode
############################################
case "$MODE" in
  main) DB_NAME="triggerIO" ;;
  dev)  DB_NAME="triggerIO-dev" ;;
  *)
    echo "Error: --mode must be 'main' or 'dev' (got: $MODE)" >&2
    exit 1
    ;;
esac

############################################
# Prepare folders
############################################
mkdir -p "$OUT_DIR" "$LOG_DIR"

if [[ -z "$DB_VERSION" ]]; then
  DB_VERSION="$(date +"%Y%m%d_%H%M%S")"
fi

LOG_TS="$(date +"%Y%m%d_%H%M%S")"
BASE_NAME="$(basename "$SQL_FILE" .sql)"

OUT_TSV="$OUT_DIR/${BASE_NAME}_${DB_NAME}_${DB_VERSION}.tsv"
OUT_GZ="${OUT_TSV}.gz"
LOG_FILE="$LOG_DIR/${BASE_NAME}_${DB_NAME}_${LOG_TS}.log"

############################################
# Overwrite policy
############################################
if [[ -f "$OUT_GZ" && "$OVERWRITE" -eq 0 ]]; then
  echo "Output already exists:"
  echo "  $OUT_GZ"
  echo "Use --overwrite to regenerate it."
  exit 1
fi

if [[ "$OVERWRITE" -eq 1 ]]; then
  rm -f "$OUT_TSV" "$OUT_GZ"
fi

############################################
# Logging
############################################
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Running query..."
echo "SQL:       $SQL_FILE"
echo "Mode:      $MODE"
echo "DB:        $DB_NAME @ ${DB_HOST}:${DB_PORT}"
echo "Version:   $DB_VERSION"
echo "Output:    $OUT_GZ"
echo "Overwrite: $OVERWRITE"
echo "Log:       $LOG_FILE"
echo

START_TIME=$(date +%s)

############################################
# Run query -> TSV -> gzip
############################################
mariadb \
  --host="$DB_HOST" \
  --port="$DB_PORT" \
  --user="$DB_USER" \
  --password="$DB_PASS" \
  --database="$DB_NAME" \
  --batch --raw \
  < "$SQL_FILE" \
  > "$OUT_TSV"

gzip -f "$OUT_TSV"

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo
echo "Done in ${ELAPSED} seconds"
echo "File: $OUT_GZ"
echo "Size: $(du -h "$OUT_GZ" | awk '{print $1}')"
echo "Log saved in: $LOG_FILE"