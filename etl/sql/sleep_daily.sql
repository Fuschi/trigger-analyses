/* -------------------------------------------------
   sleep -> daily
   - strict daily-bucket dedup:
       keep unique MIN(created_at) per (deviceId, firmware, date)
       drop buckets where MIN(created_at) is not unique
   - user mapping: keep only deviceIds mapping to exactly one userId
------------------------------------------------- */

WITH
build_date AS (
  SELECT
    t.*,
    STR_TO_DATE(
      CONCAT(t.year, '-', LPAD(t.month,2,'0'), '-', LPAD(t.day,2,'0')),
      '%Y-%m-%d'
    ) AS date
  FROM sleep AS t
),

day_bucket_min_created_at AS (
  SELECT
    deviceId,
    firmware,
    date,
    MIN(created_at) AS min_created_at
  FROM build_date
  GROUP BY deviceId, firmware, date
),

day_bucket_created_at_counts AS (
  SELECT
    deviceId,
    firmware,
    date,
    created_at,
    COUNT(*) AS cnt_at_created
  FROM build_date
  GROUP BY deviceId, firmware, date, created_at
),

day_bucket_unique_minimum AS (
  SELECT
    m.deviceId,
    m.firmware,
    m.date,
    m.min_created_at
  FROM day_bucket_min_created_at AS m
  JOIN day_bucket_created_at_counts AS c
    ON  c.deviceId   = m.deviceId
    AND c.firmware   = m.firmware
    AND c.date       = m.date
    AND c.created_at = m.min_created_at
  WHERE c.cnt_at_created = 1
),

sleep_strict_day_dedup AS (
  SELECT b.*
  FROM build_date AS b
  JOIN day_bucket_unique_minimum AS u
    ON  b.deviceId   = u.deviceId
    AND b.firmware   = u.firmware
    AND b.date       = u.date
    AND b.created_at = u.min_created_at
),

user_sleep_unique_device AS (
  SELECT
    deviceId,
    MIN(userId) AS userId
  FROM user_sleep
  GROUP BY deviceId
  HAVING COUNT(DISTINCT userId) = 1
),

sleep_daily AS (
  SELECT
    d.*,
    u.userId
  FROM sleep_strict_day_dedup AS d
  JOIN user_sleep_unique_device AS u
    ON u.deviceId = d.deviceId
)

SELECT
  s.userId,
  s.deviceId,
  s.firmware,
  s.date,

  /* Daily values (already aggregated) -> force numeric types */
  CAST(s.sleepduration       AS DOUBLE) AS sleepduration,
  CAST(s.awake               AS DOUBLE) AS awake,
  CAST(s.insomnia            AS DOUBLE) AS insomnia,
  CAST(s.remsleep            AS DOUBLE) AS remsleep,
  CAST(s.lightsleep          AS DOUBLE) AS lightsleep,
  CAST(s.deepsleep           AS DOUBLE) AS deepsleep,
  CAST(s.sleepquality        AS DOUBLE) AS sleepquality,
  CAST(s.fallsleepefficiency AS DOUBLE) AS fallsleepefficiency,

  s.created_at
FROM sleep_daily AS s
ORDER BY
  s.deviceId,
  s.userId,
  s.date;