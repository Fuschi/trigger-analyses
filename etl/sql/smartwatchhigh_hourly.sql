/* =========================================================
   smartwatchhigh -> hourly aggregates + bind user_smartwatch
   - strict second-level de-duplication (drop ambiguous seconds)
   - keep only deviceIds mapping to exactly one userId
========================================================= */

WITH
-- Build second resolution measurement timestamp from separate date/time fields
build_event_ts AS (
  SELECT
    t.*,
    STR_TO_DATE(
      CONCAT(t.year,'-',LPAD(t.month,2,'0'),'-',LPAD(t.day,2,'0'),' ',
             LPAD(t.hour,2,'0'),':',LPAD(t.minute,2,'0'),':',LPAD(t.second,2,'0')),
      '%Y-%m-%d %H:%i:%s'
    ) AS event_ts
  FROM smartwatchhigh AS t
),

-- 1) Minimum created_at for each (deviceId, firmware, event_ts) second-bucket
second_bucket_min_created_at AS (
  SELECT
    deviceId,
    firmware,
    event_ts,
    MIN(created_at) AS min_created_at
  FROM build_event_ts
  GROUP BY deviceId, firmware, event_ts
),

-- 2) Count how many rows exist for each exact created_at inside each second-bucket
second_bucket_created_at_counts AS (
  SELECT
    deviceId,
    firmware,
    event_ts,
    created_at,
    COUNT(*) AS cnt_at_created
  FROM build_event_ts
  GROUP BY deviceId, firmware, event_ts, created_at
),

-- 3) Keep only buckets where the minimum created_at is unique
second_bucket_unique_minimum AS (
  SELECT
    m.deviceId,
    m.firmware,
    m.event_ts,
    m.min_created_at
  FROM second_bucket_min_created_at AS m
  JOIN second_bucket_created_at_counts AS c
    ON  c.deviceId   = m.deviceId
    AND c.firmware   = m.firmware
    AND c.event_ts   = m.event_ts
    AND c.created_at = m.min_created_at
  WHERE c.cnt_at_created = 1
),

-- 4) Final strict second-level deduplicated rows
smartwatchhigh_strict_second_dedup AS (
  SELECT h.*
  FROM build_event_ts AS h
  JOIN second_bucket_unique_minimum AS u
    ON  h.deviceId   = u.deviceId
    AND h.firmware   = u.firmware
    AND h.event_ts   = u.event_ts
    AND h.created_at = u.min_created_at
),

-- 5) Keep only deviceIds that map to exactly one distinct userId
user_smartwatch_unique_device AS (
  SELECT
    deviceId,
    MIN(userId) AS userId
  FROM user_smartwatchhigh
  GROUP BY deviceId
  HAVING COUNT(DISTINCT userId) = 1
),

-- 6) Bind strict-dedup rows with user mapping
smartwatchhigh_strict_second_dedup_with_user AS (
  SELECT
    d.*,
    u.userId
  FROM smartwatchhigh_strict_second_dedup AS d
  JOIN user_smartwatch_unique_device AS u
    ON u.deviceId = d.deviceId
)

-- 7) Aggregate strict-deduplicated second-level data at hourly resolution
SELECT
  d.userId,
  d.deviceId,
  d.firmware,
  DATE(d.event_ts) AS date,
  HOUR(d.event_ts) AS hour,

  /* Heart rate (>0 valid) */
  CAST(AVG(CASE WHEN d.heartrate > 0 THEN d.heartrate END) AS DOUBLE) AS heartrate_mean,
  CAST(MIN(CASE WHEN d.heartrate > 0 THEN d.heartrate END) AS DOUBLE) AS heartrate_min,
  CAST(MAX(CASE WHEN d.heartrate > 0 THEN d.heartrate END) AS DOUBLE) AS heartrate_max,
  SUM(CASE WHEN d.heartrate > 0 THEN 1 ELSE 0 END)                    AS n_heartrate_valid,

  /* Oxygen saturation (1..100 valid) */
  CAST(AVG(CASE WHEN d.oxygens BETWEEN 1 AND 100 THEN d.oxygens END) AS DOUBLE) AS oxygens_mean,
  CAST(MIN(CASE WHEN d.oxygens BETWEEN 1 AND 100 THEN d.oxygens END) AS DOUBLE) AS oxygens_min,
  CAST(MAX(CASE WHEN d.oxygens BETWEEN 1 AND 100 THEN d.oxygens END) AS DOUBLE) AS oxygens_max,
  SUM(CASE WHEN d.oxygens BETWEEN 1 AND 100 THEN 1 ELSE 0 END)                 AS n_oxygens_valid,

  /* Breath rate (1..100 valid) */
  CAST(AVG(CASE WHEN d.breathrate BETWEEN 1 AND 100 THEN d.breathrate END) AS DOUBLE) AS breathrate_mean,
  CAST(MIN(CASE WHEN d.breathrate BETWEEN 1 AND 100 THEN d.breathrate END) AS DOUBLE) AS breathrate_min,
  CAST(MAX(CASE WHEN d.breathrate BETWEEN 1 AND 100 THEN d.breathrate END) AS DOUBLE) AS breathrate_max,
  SUM(CASE WHEN d.breathrate BETWEEN 1 AND 100 THEN 1 ELSE 0 END)                    AS n_breathrate_valid,

  /* Sleep rate (>0 valid) */
  CAST(AVG(CASE WHEN d.sleeprate > 0 THEN d.sleeprate END) AS DOUBLE) AS sleeprate_mean,
  CAST(MIN(CASE WHEN d.sleeprate > 0 THEN d.sleeprate END) AS DOUBLE) AS sleeprate_min,
  CAST(MAX(CASE WHEN d.sleeprate > 0 THEN d.sleeprate END) AS DOUBLE) AS sleeprate_max,
  SUM(CASE WHEN d.sleeprate > 0 THEN 1 ELSE 0 END)                   AS n_sleeprate_valid,

  COUNT(*) AS n_measurements

FROM smartwatchhigh_strict_second_dedup_with_user AS d
GROUP BY d.userId, d.deviceId, d.firmware, DATE(d.event_ts), HOUR(d.event_ts)
ORDER BY d.userId, d.deviceId, d.firmware, date, hour;