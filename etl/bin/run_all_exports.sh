#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# Run a fixed set of SQL exports (hardcoded list), optionally in parallel.
# Then ALWAYS run DuckDB hourly->daily rollups.
#
# Depends on:
#   - etl/bin/run_sql_export.sh
#   - etl/bin/run_duckdb_rollup.sh
#
# Daily output naming:
#   data/<table>_daily_<DBNAME>_<DBVER>.tsv[.gz]
# where DBNAME is:
#   main -> triggerIO
#   dev  -> triggerIO-dev
# ------------------------------------------------------------

ENV_FILE="config/db.env"
JOBS=1
DB_VERSION=""
OVERWRITE=0
MODE="main"   # main|dev

# Global min-valid (can be overridden per table via CLI)
MIN_VALID=0
MIN_VALID_GPS=""
MIN_VALID_MYAIR=""
MIN_VALID_SMARTWATCHHIGH=""
MIN_VALID_SMARTWATCHLOW=""

usage() {
  cat <<EOF
Usage:
  etl/bin/run_all_exports.sh [options]

Options:
  --env-file=PATH            DB env file (default: config/db.env)
  --mode=main|dev            Target database (default: main)
  --jobs=N                   Parallel jobs (default: 1)
  --db-version=LABEL         Version label used in output filenames
  --min-valid=N              Global min-valid for daily rollups (default: 0)

  # Per-table overrides (take precedence over --min-valid):
  --min-valid-gps=N
  --min-valid-myair=N
  --min-valid-smartwatchhigh=N
  --min-valid-smartwatchlow=N

  --overwrite                Overwrite existing output files (hourly + daily)
  --help                     Show help
EOF
}

############################################
# Parse arguments
############################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-file=*)   ENV_FILE="${1#*=}" ;;
    --mode=*)       MODE="${1#*=}" ;;
    --jobs=*)       JOBS="${1#*=}" ;;
    --db-version=*|--version=*) DB_VERSION="${1#*=}" ;;

    --min-valid=*)                 MIN_VALID="${1#*=}" ;;
    --min-valid-gps=*)             MIN_VALID_GPS="${1#*=}" ;;
    --min-valid-myair=*)           MIN_VALID_MYAIR="${1#*=}" ;;
    --min-valid-smartwatchhigh=*)  MIN_VALID_SMARTWATCHHIGH="${1#*=}" ;;
    --min-valid-smartwatchlow=*)   MIN_VALID_SMARTWATCHLOW="${1#*=}" ;;

    --overwrite)    OVERWRITE=1 ;;
    --help)         usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

############################################
# Validate mode + derive DBNAME label
############################################
case "$MODE" in
  main) DBNAME="triggerIO" ;;
  dev)  DBNAME="triggerIO-dev" ;;
  *) echo "Error: --mode must be 'main' or 'dev' (got: $MODE)" >&2; exit 1 ;;
esac

############################################
# Default DB_VERSION if not provided
############################################
if [[ -z "$DB_VERSION" ]]; then
  DB_VERSION="$(date +"%Y%m%d_%H%M%S")"
fi

############################################
# Validate numeric args
############################################
if ! [[ "$JOBS" =~ ^[0-9]+$ ]] || [[ "$JOBS" -lt 1 ]]; then
  echo "Error: --jobs must be a positive integer (got: $JOBS)" >&2
  exit 1
fi

is_nonneg_int() { [[ "${1:-}" =~ ^[0-9]+$ ]]; }

if ! is_nonneg_int "$MIN_VALID"; then
  echo "Error: --min-valid must be a non-negative integer (got: $MIN_VALID)" >&2
  exit 1
fi
for x in "$MIN_VALID_GPS" "$MIN_VALID_MYAIR" "$MIN_VALID_SMARTWATCHHIGH" "$MIN_VALID_SMARTWATCHLOW"; do
  if [[ -n "$x" ]] && ! is_nonneg_int "$x"; then
    echo "Error: per-table --min-valid-* must be a non-negative integer (got: $x)" >&2
    exit 1
  fi
done

############################################
# Setup
############################################
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

RUNNER="etl/bin/run_sql_export.sh"
ROLLUP_RUNNER="etl/bin/run_duckdb_rollup.sh"

[[ -x "$RUNNER" ]] || { echo "Runner not executable: $RUNNER" >&2; exit 1; }
[[ -x "$ROLLUP_RUNNER" ]] || { echo "Rollup runner not executable: $ROLLUP_RUNNER" >&2; exit 1; }
[[ -f "$ENV_FILE" ]] || { echo "Env file not found: $ENV_FILE" >&2; exit 1; }

############################################
# Fixed SQL list (EDIT HERE)
############################################
SQL_FILES=(
  "etl/sql/gps_hourly.sql"
  "etl/sql/myair_hourly.sql"
  "etl/sql/smartwatchhigh_hourly.sql"
  "etl/sql/smartwatchlow_hourly.sql"
  "etl/sql/accounts.sql"
  "etl/sql/sleep_daily.sql"
)

for f in "${SQL_FILES[@]}"; do
  [[ -f "$f" ]] || { echo "SQL file not found: $f" >&2; exit 1; }
done

############################################
# Global run log (automatic)
############################################
mkdir -p logs
RUN_TS="$(date +"%Y%m%d_%H%M%S")"
OUT_LOG="logs/run_all_${MODE}_${DB_VERSION}_${RUN_TS}.log"
exec > >(tee -a "$OUT_LOG") 2>&1

############################################
# Build runner arguments (hourly exports)
############################################
RUN_ARGS=( "--env-file=$ENV_FILE" "--mode=$MODE" "--db-version=$DB_VERSION" )
if [[ "$OVERWRITE" -eq 1 ]]; then
  RUN_ARGS+=( "--overwrite" )
fi

############################################
# Summary
############################################
echo "Project root:  $PROJECT_ROOT"
echo "Env file:      $ENV_FILE"
echo "Mode:          $MODE"
echo "DB name tag:   $DBNAME"
echo "Jobs:          $JOBS"
echo "DB version:    $DB_VERSION"
echo "Overwrite:     $OVERWRITE"
echo "Daily rollups: 1"
echo "Min valid (global): $MIN_VALID"
echo "Min valid overrides: gps=${MIN_VALID_GPS:-<none>}, myair=${MIN_VALID_MYAIR:-<none>}, smartwatchhigh=${MIN_VALID_SMARTWATCHHIGH:-<none>}, smartwatchlow=${MIN_VALID_SMARTWATCHLOW:-<none>}"
echo "Run log:       $OUT_LOG"
echo

echo "Will run ${#SQL_FILES[@]} SQL scripts:"
for f in "${SQL_FILES[@]}"; do
  echo "  - $f"
done
echo

############################################
# Function to run one hourly export
############################################
run_one() {
  local sql_file="$1"

  set +e
  local output
  output=$("$RUNNER" --sql="$sql_file" "${RUN_ARGS[@]}" 2>&1)
  local status=$?
  set -e

  if [[ $status -eq 0 ]]; then
    echo "$output"
    return 0
  fi

  if echo "$output" | grep -q "Output already exists\|Output file already exists"; then
    echo "Skipping (already exists): $sql_file"
    return 0
  fi

  echo "$output"
  echo "Export failed: $sql_file" >&2
  exit 1
}

export -f run_one
export RUNNER RUN_ARGS

############################################
# Sequential or parallel hourly exports
############################################
if [[ "$JOBS" -eq 1 ]]; then
  for f in "${SQL_FILES[@]}"; do
    run_one "$f"
  done
else
  printf '%s\0' "${SQL_FILES[@]}" \
    | xargs -0 -n 1 -P "$JOBS" bash -lc 'run_one "$0"'
fi

echo
echo "All hourly exports completed."

############################################
# Helper: effective min-valid per table
############################################
effective_min_valid() {
  local t="$1"
  case "$t" in
    gps)            echo "${MIN_VALID_GPS:-$MIN_VALID}" ;;
    myair)          echo "${MIN_VALID_MYAIR:-$MIN_VALID}" ;;
    smartwatchhigh) echo "${MIN_VALID_SMARTWATCHHIGH:-$MIN_VALID}" ;;
    smartwatchlow)  echo "${MIN_VALID_SMARTWATCHLOW:-$MIN_VALID}" ;;
    *)              echo "$MIN_VALID" ;;
  esac
}

############################################
# ALWAYS: DuckDB daily rollups
############################################
echo
echo "Running DuckDB daily rollups..."

DAILY_TABLES=("gps" "myair" "smartwatchhigh" "smartwatchlow")

# If overwrite is off, we skip by checking the FINAL expected filename (with DBNAME tag)
# If overwrite is on, we let rollup run and then replace.
ROLLUP_OVERWRITE_ARG=()
if [[ "$OVERWRITE" -eq 1 ]]; then
  ROLLUP_OVERWRITE_ARG=("--overwrite")
fi

mkdir -p data

for t in "${DAILY_TABLES[@]}"; do
  mv_t="$(effective_min_valid "$t")"

  # Final target names (with dbname tag)
  final_tsv="data/${t}_daily_${DBNAME}_${DB_VERSION}.tsv"
  final_gz="${final_tsv}.gz"

  if [[ "$OVERWRITE" -eq 0 ]]; then
    if [[ -f "$final_tsv" || -f "$final_gz" ]]; then
      echo "Skipping daily (already exists): $t -> $(basename "$final_tsv")[.gz]"
      continue
    fi
  fi

  echo
  echo "Daily rollup: table=$t  min-valid=$mv_t"

  set +e
  output=$("$ROLLUP_RUNNER" \
    --table="$t" \
    --mode="$MODE" \
    --db-version="$DB_VERSION" \
    --min-valid="$mv_t" \
    "${ROLLUP_OVERWRITE_ARG[@]}" 2>&1)
  status=$?
  set -e

  if [[ $status -ne 0 ]]; then
    # If rollup runner itself reports "already exists", align skip semantics
    if [[ "$OVERWRITE" -eq 0 ]] && echo "$output" | grep -q "Output already exists\|Output file already exists"; then
      echo "Skipping daily (already exists): $t"
      continue
    fi
    echo "$output"
    echo "Daily rollup failed: $t" >&2
    exit 1
  fi

  echo "$output"

  # ---- Ensure final filename includes DBNAME tag ----
  #
  # We assume run_duckdb_rollup.sh might produce:
  #   data/<table>_daily_<DBVER>.tsv[.gz]
  # If it already produces the tagged name, we do nothing.
  #
  src_tsv="data/${t}_daily_${DB_VERSION}.tsv"
  src_gz="${src_tsv}.gz"

  if [[ -f "$final_tsv" || -f "$final_gz" ]]; then
    # Already correct naming (or rollup runner wrote it)
    echo "Daily output present (tagged): $(basename "$final_tsv")[.gz]"
    continue
  fi

  if [[ -f "$src_gz" ]]; then
    [[ "$OVERWRITE" -eq 1 ]] && rm -f "$final_gz" "$final_tsv"
    mv -f "$src_gz" "$final_gz"
    echo "Renamed daily output -> $(basename "$final_gz")"
    continue
  fi

  if [[ -f "$src_tsv" ]]; then
    [[ "$OVERWRITE" -eq 1 ]] && rm -f "$final_tsv" "$final_gz"
    mv -f "$src_tsv" "$final_tsv"
    echo "Renamed daily output -> $(basename "$final_tsv")"
    continue
  fi

  # If we reach here, we didn't find expected outputs. Fail loudly.
  echo "Error: daily rollup succeeded but output file not found for table '$t'." >&2
  echo "Looked for: $final_tsv(.gz) or $src_tsv(.gz)" >&2
  exit 1
done

echo
echo "All daily rollups completed."
echo
echo "All exports completed."