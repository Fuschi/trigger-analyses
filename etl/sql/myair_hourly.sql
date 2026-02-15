/* =========================================================
   myair -> hourly aggregates + bind user_myair
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
  FROM myair AS t
),

-- Minimum created_at for each (deviceId, firmware, event_ts) second-bucket
second_bucket_min_created_at AS (
  SELECT deviceId, firmware, event_ts, MIN(created_at) AS min_created_at
  FROM build_event_ts
  GROUP BY deviceId, firmware, event_ts
),

-- Count how many rows exist for each exact created_at inside each second-bucket
second_bucket_created_at_counts AS (
  SELECT deviceId, firmware, event_ts, created_at, COUNT(*) AS cnt_at_created
  FROM build_event_ts
  GROUP BY deviceId, firmware, event_ts, created_at
),

-- Keep only buckets where the minimum created_at is unique
second_bucket_unique_minimum AS (
  SELECT m.deviceId, m.firmware, m.event_ts, m.min_created_at
  FROM second_bucket_min_created_at AS m
  JOIN second_bucket_created_at_counts AS c
    ON  c.deviceId = m.deviceId
    AND c.firmware = m.firmware
    AND c.event_ts = m.event_ts
    AND c.created_at = m.min_created_at
  WHERE c.cnt_at_created = 1
),

-- Final strict second-level deduplicated rows
myair_strict_second_dedup AS (
  SELECT y.*
  FROM build_event_ts AS y
  JOIN second_bucket_unique_minimum AS u
    ON  y.deviceId = u.deviceId
    AND y.firmware = u.firmware
    AND y.event_ts = u.event_ts
    AND y.created_at = u.min_created_at
),

-- Keep only deviceIds that map to exactly one distinct userId
user_myair_unique_device AS (
  SELECT
    deviceId,
    MIN(userId) AS userId
  FROM user_myair
  GROUP BY deviceId
  HAVING COUNT(DISTINCT userId) = 1
),

-- Bind (inner join) strict-dedup rows with user mapping
myair_strict_second_dedup_with_user AS (
  SELECT
    d.*,
    u.userId
  FROM myair_strict_second_dedup AS d
  JOIN user_myair_unique_device AS u
    ON u.deviceId = d.deviceId
)

-- Aggregate strict-deduplicated second-level data at hourly resolution
SELECT
  d.userId,
  d.deviceId,
  d.firmware,
  DATE(d.event_ts) AS date,
  HOUR(d.event_ts) AS hour,

  -- Particulate mass (>= 0 considered valid)
  CAST(AVG(CASE WHEN d.pm1  >= 0 THEN d.pm1  END) AS DOUBLE) AS pm1_mean,
  CAST(MIN(CASE WHEN d.pm1  >= 0 THEN d.pm1  END) AS DOUBLE) AS pm1_min,
  CAST(MAX(CASE WHEN d.pm1  >= 0 THEN d.pm1  END) AS DOUBLE) AS pm1_max,
  SUM(CASE WHEN d.pm1  >= 0 THEN 1 ELSE 0 END) AS n_pm1_valid,

  CAST(AVG(CASE WHEN d.pm25 >= 0 THEN d.pm25 END) AS DOUBLE) AS pm25_mean,
  CAST(MIN(CASE WHEN d.pm25 >= 0 THEN d.pm25 END) AS DOUBLE) AS pm25_min,
  CAST(MAX(CASE WHEN d.pm25 >= 0 THEN d.pm25 END) AS DOUBLE) AS pm25_max,
  SUM(CASE WHEN d.pm25 >= 0 THEN 1 ELSE 0 END) AS n_pm25_valid,

  CAST(AVG(CASE WHEN d.pm10 >= 0 THEN d.pm10 END) AS DOUBLE) AS pm10_mean,
  CAST(MIN(CASE WHEN d.pm10 >= 0 THEN d.pm10 END) AS DOUBLE) AS pm10_min,
  CAST(MAX(CASE WHEN d.pm10 >= 0 THEN d.pm10 END) AS DOUBLE) AS pm10_max,
  SUM(CASE WHEN d.pm10 >= 0 THEN 1 ELSE 0 END) AS n_pm10_valid,

  -- Particle counts (>= 0 considered valid)
  CAST(AVG(CASE WHEN d.pc03 >= 0 THEN d.pc03 END) AS DOUBLE) AS pc03_mean,
  CAST(MIN(CASE WHEN d.pc03 >= 0 THEN d.pc03 END) AS DOUBLE) AS pc03_min,
  CAST(MAX(CASE WHEN d.pc03 >= 0 THEN d.pc03 END) AS DOUBLE) AS pc03_max,
  SUM(CASE WHEN d.pc03 >= 0 THEN 1 ELSE 0 END) AS n_pc03_valid,

  CAST(AVG(CASE WHEN d.pc05 >= 0 THEN d.pc05 END) AS DOUBLE) AS pc05_mean,
  CAST(MIN(CASE WHEN d.pc05 >= 0 THEN d.pc05 END) AS DOUBLE) AS pc05_min,
  CAST(MAX(CASE WHEN d.pc05 >= 0 THEN d.pc05 END) AS DOUBLE) AS pc05_max,
  SUM(CASE WHEN d.pc05 >= 0 THEN 1 ELSE 0 END) AS n_pc05_valid,

  CAST(AVG(CASE WHEN d.pc1  >= 0 THEN d.pc1  END) AS DOUBLE) AS pc1_mean,
  CAST(MIN(CASE WHEN d.pc1  >= 0 THEN d.pc1  END) AS DOUBLE) AS pc1_min,
  CAST(MAX(CASE WHEN d.pc1  >= 0 THEN d.pc1  END) AS DOUBLE) AS pc1_max,
  SUM(CASE WHEN d.pc1  >= 0 THEN 1 ELSE 0 END) AS n_pc1_valid,

  CAST(AVG(CASE WHEN d.pc25 >= 0 THEN d.pc25 END) AS DOUBLE) AS pc25_mean,
  CAST(MIN(CASE WHEN d.pc25 >= 0 THEN d.pc25 END) AS DOUBLE) AS pc25_min,
  CAST(MAX(CASE WHEN d.pc25 >= 0 THEN d.pc25 END) AS DOUBLE) AS pc25_max,
  SUM(CASE WHEN d.pc25 >= 0 THEN 1 ELSE 0 END) AS n_pc25_valid,

  CAST(AVG(CASE WHEN d.pc5  >= 0 THEN d.pc5  END) AS DOUBLE) AS pc5_mean,
  CAST(MIN(CASE WHEN d.pc5  >= 0 THEN d.pc5  END) AS DOUBLE) AS pc5_min,
  CAST(MAX(CASE WHEN d.pc5  >= 0 THEN d.pc5  END) AS DOUBLE) AS pc5_max,
  SUM(CASE WHEN d.pc5  >= 0 THEN 1 ELSE 0 END) AS n_pc5_valid,

  CAST(AVG(CASE WHEN d.pc10 >= 0 THEN d.pc10 END) AS DOUBLE) AS pc10_mean,
  CAST(MIN(CASE WHEN d.pc10 >= 0 THEN d.pc10 END) AS DOUBLE) AS pc10_min,
  CAST(MAX(CASE WHEN d.pc10 >= 0 THEN d.pc10 END) AS DOUBLE) AS pc10_max,
  SUM(CASE WHEN d.pc10 >= 0 THEN 1 ELSE 0 END) AS n_pc10_valid,

  -- Environmental variables (NOT NULL by schema)
  CAST(AVG(d.temperature) AS DOUBLE) AS temperature_mean,
  CAST(MIN(d.temperature) AS DOUBLE) AS temperature_min,
  CAST(MAX(d.temperature) AS DOUBLE) AS temperature_max,

  CAST(AVG(d.humidity) AS DOUBLE) AS humidity_mean,
  CAST(MIN(d.humidity) AS DOUBLE) AS humidity_min,
  CAST(MAX(d.humidity) AS DOUBLE) AS humidity_max,

  CAST(AVG(d.pressure) AS DOUBLE) AS pressure_mean,
  CAST(MIN(d.pressure) AS DOUBLE) AS pressure_min,
  CAST(MAX(d.pressure) AS DOUBLE) AS pressure_max,

  CAST(AVG(d.sound) AS DOUBLE) AS sound_mean,
  CAST(MIN(d.sound) AS DOUBLE) AS sound_min,
  CAST(MAX(d.sound) AS DOUBLE) AS sound_max,

  CAST(AVG(d.uvb) AS DOUBLE) AS uvb_mean,
  CAST(MIN(d.uvb) AS DOUBLE) AS uvb_min,
  CAST(MAX(d.uvb) AS DOUBLE) AS uvb_max,

  CAST(AVG(d.light) AS DOUBLE) AS light_mean,
  CAST(MIN(d.light) AS DOUBLE) AS light_min,
  CAST(MAX(d.light) AS DOUBLE) AS light_max,

  COUNT(*) AS n_measurements

FROM myair_strict_second_dedup_with_user AS d
GROUP BY d.userId, d.deviceId, d.firmware, DATE(d.event_ts), HOUR(d.event_ts)
ORDER BY d.userId, d.deviceId, d.firmware, date, hour;