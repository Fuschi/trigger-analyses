/* =========================================================
   gps -> hourly aggregates + bind user_gps
   - strict second-level de-duplication (drop ambiguous seconds)
   - keep only deviceIds mapping to exactly one userId
   - then hourly aggregates (AVG/MIN/MAX + counters)

   Strict rule:
   For each (deviceId, firmware, event_ts) second-bucket:
     1) compute MIN(created_at)
     2) keep the row with created_at = MIN(created_at)
     3) BUT if more than 1 row share that minimum created_at, drop the whole bucket
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
  FROM gps AS t
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
gps_strict_second_dedup AS (
  SELECT g.*
  FROM build_event_ts AS g
  JOIN second_bucket_unique_minimum AS u
    ON  g.deviceId   = u.deviceId
    AND g.firmware   = u.firmware
    AND g.event_ts   = u.event_ts
    AND g.created_at = u.min_created_at
),

-- 5) Keep only deviceIds that map to exactly one distinct userId
user_gps_unique_device AS (
  SELECT
    deviceId,
    MIN(userId) AS userId
  FROM user_gps
  GROUP BY deviceId
  HAVING COUNT(DISTINCT userId) = 1
),

-- 6) Bind strict-dedup rows with user mapping
gps_strict_second_dedup_with_user AS (
  SELECT
    d.*,
    u.userId
  FROM gps_strict_second_dedup AS d
  JOIN user_gps_unique_device AS u
    ON u.deviceId = d.deviceId
)

-- 7) Aggregate strict-deduplicated second-level GPS at hourly resolution
SELECT
  d.userId,
  d.deviceId,
  d.firmware,
  DATE(d.event_ts) AS date,
  HOUR(d.event_ts) AS hour,

  /* Coordinates: only accepted accuracy */
  CAST(AVG(CASE WHEN d.accuracy BETWEEN 0 AND 100 THEN d.latitude  END) AS DOUBLE) AS latitude_mean,
  CAST(MIN(CASE WHEN d.accuracy BETWEEN 0 AND 100 THEN d.latitude  END) AS DOUBLE) AS latitude_min,
  CAST(MAX(CASE WHEN d.accuracy BETWEEN 0 AND 100 THEN d.latitude  END) AS DOUBLE) AS latitude_max,

  CAST(AVG(CASE WHEN d.accuracy BETWEEN 0 AND 100 THEN d.longitude END) AS DOUBLE) AS longitude_mean,
  CAST(MIN(CASE WHEN d.accuracy BETWEEN 0 AND 100 THEN d.longitude END) AS DOUBLE) AS longitude_min,
  CAST(MAX(CASE WHEN d.accuracy BETWEEN 0 AND 100 THEN d.longitude END) AS DOUBLE) AS longitude_max,

  CAST(AVG(CASE WHEN d.accuracy BETWEEN 0 AND 100 THEN d.accuracy  END) AS DOUBLE) AS accuracy_mean,
  CAST(MIN(CASE WHEN d.accuracy BETWEEN 0 AND 100 THEN d.accuracy  END) AS DOUBLE) AS accuracy_min,
  CAST(MAX(CASE WHEN d.accuracy BETWEEN 0 AND 100 THEN d.accuracy  END) AS DOUBLE) AS accuracy_max,

  /* Counts */
  COUNT(*) AS n_measurements,
  SUM(CASE WHEN d.accuracy BETWEEN 0 AND 100 THEN 1 ELSE 0 END) AS n_accuracy_valid

FROM gps_strict_second_dedup_with_user AS d
GROUP BY d.userId, d.deviceId, d.firmware, DATE(d.event_ts), HOUR(d.event_ts)
ORDER BY d.userId, d.deviceId, d.firmware, date, hour;