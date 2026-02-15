/* =========================================================
   smartwatchlow -> hourly aggregates + bind user_smartwatch
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
  FROM smartwatchlow AS t
),

second_bucket_min_created_at AS (
  SELECT
    deviceId,
    firmware,
    event_ts,
    MIN(created_at) AS min_created_at
  FROM build_event_ts
  GROUP BY deviceId, firmware, event_ts
),

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

smartwatchlow_strict_second_dedup AS (
  SELECT s.*
  FROM build_event_ts AS s
  JOIN second_bucket_unique_minimum AS u
    ON  s.deviceId   = u.deviceId
    AND s.firmware   = u.firmware
    AND s.event_ts   = u.event_ts
    AND s.created_at = u.min_created_at
),

user_smartwatch_unique_device AS (
  SELECT
    deviceId,
    MIN(userId) AS userId
  FROM user_smartwatchlow
  GROUP BY deviceId
  HAVING COUNT(DISTINCT userId) = 1
),

smartwatchlow_strict_second_dedup_with_user AS (
  SELECT
    d.*,
    u.userId
  FROM smartwatchlow_strict_second_dedup AS d
  JOIN user_smartwatch_unique_device AS u
    ON u.deviceId = d.deviceId
)

-- 7) Hourly aggregation
SELECT
  d.userId,
  d.deviceId,
  d.firmware,
  DATE(d.event_ts) AS date,
  HOUR(d.event_ts) AS hour,

  /* Activity (increments) */
  SUM(d.step) AS steps_sum,
  SUM(d.cal)  AS cal_sum,

  /* Blood pressure (treat 0 as missing) */
  CAST(AVG(CASE WHEN d.bphigh > 0 THEN d.bphigh END) AS DOUBLE) AS bphigh_mean,
  CAST(MIN(CASE WHEN d.bphigh > 0 THEN d.bphigh END) AS DOUBLE) AS bphigh_min,
  CAST(MAX(CASE WHEN d.bphigh > 0 THEN d.bphigh END) AS DOUBLE) AS bphigh_max,
  SUM(CASE WHEN d.bphigh > 0 THEN 1 ELSE 0 END) AS n_bphigh_valid,

  CAST(AVG(CASE WHEN d.bplow > 0 THEN d.bplow END) AS DOUBLE) AS bplow_mean,
  CAST(MIN(CASE WHEN d.bplow > 0 THEN d.bplow END) AS DOUBLE) AS bplow_min,
  CAST(MAX(CASE WHEN d.bplow > 0 THEN d.bplow END) AS DOUBLE) AS bplow_max,
  SUM(CASE WHEN d.bplow > 0 THEN 1 ELSE 0 END) AS n_bplow_valid,

  /* Temperatures (treat 0 as missing) */
  CAST(AVG(CASE WHEN d.bodytemp > 0 THEN d.bodytemp END) AS DOUBLE) AS bodytemp_mean,
  CAST(MIN(CASE WHEN d.bodytemp > 0 THEN d.bodytemp END) AS DOUBLE) AS bodytemp_min,
  CAST(MAX(CASE WHEN d.bodytemp > 0 THEN d.bodytemp END) AS DOUBLE) AS bodytemp_max,
  SUM(CASE WHEN d.bodytemp > 0 THEN 1 ELSE 0 END) AS n_bodytemp_valid,

  CAST(AVG(CASE WHEN d.skintemp > 0 THEN d.skintemp END) AS DOUBLE) AS skintemp_mean,
  CAST(MIN(CASE WHEN d.skintemp > 0 THEN d.skintemp END) AS DOUBLE) AS skintemp_min,
  CAST(MAX(CASE WHEN d.skintemp > 0 THEN d.skintemp END) AS DOUBLE) AS skintemp_max,
  SUM(CASE WHEN d.skintemp > 0 THEN 1 ELSE 0 END) AS n_skintemp_valid,

  COUNT(*) AS n_measurements

FROM smartwatchlow_strict_second_dedup_with_user AS d
GROUP BY d.userId, d.deviceId, d.firmware, DATE(d.event_ts), HOUR(d.event_ts)
ORDER BY d.userId, d.deviceId, d.firmware, date, hour;