#!/usr/bin/env bash
set -euo pipefail

DUCKDB_BIN="${DUCKDB_BIN:-duckdb}"

TABLE=""
MODE="main"          # main|dev
DB_VERSION=""
MIN_VALID=""         # REQUIRED (no default)
OVERWRITE=0

DUCKDB_DIR="etl/duckdb"
DATA_DIR="data"
LOG_DIR="logs"

usage() {
  cat <<EOF
Usage:
  etl/bin/run_duckdb_rollup.sh --table=NAME [options]

Required:
  --table=NAME
  --min-valid=N

Options:
  --mode=main|dev        Database mode used to locate hourly input (default: main)
  --db-version=LABEL     Version label (default: timestamp)
  --overwrite            Overwrite existing output file
  --help                 Show help

Allowed tables:
  myair | gps | smartwatchhigh | smartwatchlow

Input hourly file:
  mode=main -> data/<table>_hourly_triggerIO_<dbver>.tsv.gz
  mode=dev  -> data/<table>_hourly_triggerIO-dev_<dbver>.tsv.gz

DuckDB SQL:
  etl/duckdb/<table>_daily.sql

SQL placeholders required:
  {{INFILE}}, {{OUTFILE}}, {{MIN_VALID}}
Optional:
  {{DBVER}}
EOF
}

############################################
# Parse args
############################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    --table=*)      TABLE="${1#*=}" ;;
    --mode=*)       MODE="${1#*=}" ;;
    --db-version=*) DB_VERSION="${1#*=}" ;;
    --min-valid=*)  MIN_VALID="${1#*=}" ;;
    --overwrite)    OVERWRITE=1 ;;
    --help)         usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

############################################
# Validate table
############################################
[[ -n "$TABLE" ]] || { echo "Error: --table=NAME is required" >&2; exit 1; }

case "$TABLE" in
  myair|gps|smartwatchhigh|smartwatchlow) ;;
  *)
    echo "Error: invalid --table=$TABLE" >&2
    echo "Allowed: myair | gps | smartwatchhigh | smartwatchlow" >&2
    exit 1
    ;;
esac

############################################
# Validate mode
############################################
case "$MODE" in
  main|dev) ;;
  *) echo "Error: --mode must be 'main' or 'dev' (got: $MODE)" >&2; exit 1 ;;
esac

############################################
# Default db-version if not provided
############################################
if [[ -z "$DB_VERSION" ]]; then
  DB_VERSION="$(date +"%Y%m%d_%H%M%S")"
fi

############################################
# Require min-valid (no default)
############################################
if [[ -z "$MIN_VALID" ]]; then
  echo "Error: --min-valid=N is required" >&2
  exit 1
fi

# Optional: ensure it's an integer
if ! [[ "$MIN_VALID" =~ ^[0-9]+$ ]]; then
  echo "Error: --min-valid must be a non-negative integer (got: $MIN_VALID)" >&2
  exit 1
fi

############################################
# Check duckdb
############################################
command -v "$DUCKDB_BIN" >/dev/null 2>&1 || {
  echo "DuckDB not found: $DUCKDB_BIN" >&2
  exit 1
}

############################################
# Project root
############################################
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

mkdir -p "$LOG_DIR" "$DATA_DIR"

############################################
# Resolve DB name for input matching
############################################
if [[ "$MODE" == "main" ]]; then
  DB_NAME="triggerIO"
else
  DB_NAME="triggerIO-dev"
fi

############################################
# Resolve paths
############################################
SQL_FILE="${DUCKDB_DIR}/${TABLE}_daily.sql"
IN_FILE="${DATA_DIR}/${TABLE}_hourly_${DB_NAME}_${DB_VERSION}.tsv.gz"

OUT_TSV="${DATA_DIR}/${TABLE}_daily_${DB_NAME}_${DB_VERSION}.tsv"
OUT_GZ="${OUT_TSV}.gz"

[[ -f "$SQL_FILE" ]] || { echo "SQL file not found: $SQL_FILE" >&2; exit 1; }
[[ -f "$IN_FILE"  ]] || { echo "Input file not found: $IN_FILE" >&2; exit 1; }

############################################
# Ensure SQL contains required placeholders
############################################
if ! grep -q "{{INFILE}}" "$SQL_FILE"; then
  echo "Error: SQL file must contain {{INFILE}} placeholder: $SQL_FILE" >&2
  exit 1
fi
if ! grep -q "{{OUTFILE}}" "$SQL_FILE"; then
  echo "Error: SQL file must contain {{OUTFILE}} placeholder: $SQL_FILE" >&2
  exit 1
fi
if ! grep -q "{{MIN_VALID}}" "$SQL_FILE"; then
  echo "Error: SQL file must contain {{MIN_VALID}} placeholder: $SQL_FILE" >&2
  exit 1
fi

############################################
# Overwrite policy
############################################
if [[ -f "$OUT_GZ" && "$OVERWRITE" -eq 0 ]]; then
  echo "Output already exists: $OUT_GZ"
  echo "Use --overwrite to regenerate."
  exit 1
fi

if [[ "$OVERWRITE" -eq 1 ]]; then
  rm -f "$OUT_TSV" "$OUT_GZ"
fi

############################################
# Logging
############################################
RUN_TS="$(date +"%Y%m%d_%H%M%S")"
LOG_FILE="${LOG_DIR}/${TABLE}_daily_${MODE}_${DB_VERSION}_${RUN_TS}.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "DuckDB daily aggregation"
echo "DuckDB bin:   $DUCKDB_BIN"
echo "Table:        $TABLE"
echo "Mode:         $MODE"
echo "DB version:   $DB_VERSION"
echo "Min valid:    $MIN_VALID"
echo "SQL:          $SQL_FILE"
echo "Input:        $IN_FILE"
echo "Output:       $OUT_GZ"
echo "Overwrite:    $OVERWRITE"
echo "Log:          $LOG_FILE"
echo

START_TIME=$(date +%s)

############################################
# Render SQL placeholders
############################################
SQL_TEXT="$(cat "$SQL_FILE")"
SQL_TEXT="${SQL_TEXT//\{\{DBVER\}\}/$DB_VERSION}"
SQL_TEXT="${SQL_TEXT//\{\{INFILE\}\}/$IN_FILE}"
SQL_TEXT="${SQL_TEXT//\{\{OUTFILE\}\}/$OUT_TSV}"
SQL_TEXT="${SQL_TEXT//\{\{MIN_VALID\}\}/$MIN_VALID}"

############################################
# Execute DuckDB
############################################
"$DUCKDB_BIN" -c "$SQL_TEXT"

############################################
# Compress output
############################################
if [[ ! -f "$OUT_TSV" ]]; then
  echo "Error: expected output TSV not found: $OUT_TSV" >&2
  exit 1
fi

gzip -f "$OUT_TSV"

END_TIME=$(date +%s)

echo
echo "Done in $((END_TIME - START_TIME)) seconds"
echo "File: $OUT_GZ"
echo "Size: $(du -h "$OUT_GZ" | awk '{print $1}')"
echo "Log saved in: $LOG_FILE"