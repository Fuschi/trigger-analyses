/* =========================================================
   myair -> hourly aggregates
   - strict second-level de-duplication (drop ambiguous seconds)
   - then hourly aggregates (AVG/MIN/MAX + valid counters)

   Strict rule:
   For each (deviceId, firmware, event_ts) second-bucket:
     1) compute MIN(created_at)
     2) keep the row with created_at = MIN(created_at)
     3) BUT if more than 1 row share that minimum created_at, drop the whole bucket
========================================================= */

WITH
-- Minimum created_at for each (deviceId, firmware, event_ts) second-bucket
second_bucket_min_created_at AS (
  SELECT deviceId, firmware, event_ts, MIN(created_at) AS min_created_at
  FROM myair
  GROUP BY deviceId, firmware, event_ts
),
-- Count how many rows exist for each exact created_at inside each second-bucket
second_bucket_created_at_counts AS (
  SELECT deviceId, firmware, event_ts, created_at, COUNT(*) AS cnt_at_created
  FROM myair
  GROUP BY deviceId, firmware, event_ts, created_at
),
-- Keep only buckets where the minimum created_at is unique
second_bucket_unique_minimum AS (
  SELECT m.deviceId, m.firmware, m.event_ts, m.min_created_at
  FROM second_bucket_min_created_at AS m
  JOIN second_bucket_created_at_counts AS c
    ON  c.deviceId = m.deviceId AND c.firmware = m.firmware
    AND c.event_ts = m.event_ts AND c.created_at = m.min_created_at
  WHERE c.cnt_at_created = 1
),
-- Final strict second-level deduplicated rows
myair_strict_second_dedup AS (
  SELECT y.*
  FROM myair AS y
  JOIN second_bucket_unique_minimum AS u
    ON  y.deviceId = u.deviceId AND y.firmware = u.firmware
    AND y.event_ts = u.event_ts AND y.created_at = u.min_created_at
)
-- Aggregate strict-deduplicated second-level data at hourly resolution
SELECT
  d.deviceId,
  d.firmware,
  DATE(d.event_ts) AS date,
  HOUR(d.event_ts) AS hour,

  -- Particulate mass (>= 0 considered valid)
  AVG(CASE WHEN d.pm1  >= 0 THEN d.pm1  END) AS pm1_mean,
  MIN(CASE WHEN d.pm1  >= 0 THEN d.pm1  END) AS pm1_min,
  MAX(CASE WHEN d.pm1  >= 0 THEN d.pm1  END) AS pm1_max,
  SUM(CASE WHEN d.pm1  >= 0 THEN 1 ELSE 0 END) AS n_pm1_valid,

  AVG(CASE WHEN d.pm25 >= 0 THEN d.pm25 END) AS pm25_mean,
  MIN(CASE WHEN d.pm25 >= 0 THEN d.pm25 END) AS pm25_min,
  MAX(CASE WHEN d.pm25 >= 0 THEN d.pm25 END) AS pm25_max,
  SUM(CASE WHEN d.pm25 >= 0 THEN 1 ELSE 0 END) AS n_pm25_valid,

  AVG(CASE WHEN d.pm10 >= 0 THEN d.pm10 END) AS pm10_mean,
  MIN(CASE WHEN d.pm10 >= 0 THEN d.pm10 END) AS pm10_min,
  MAX(CASE WHEN d.pm10 >= 0 THEN d.pm10 END) AS pm10_max,
  SUM(CASE WHEN d.pm10 >= 0 THEN 1 ELSE 0 END) AS n_pm10_valid,

  -- Particle counts (>= 0 considered valid)
  AVG(CASE WHEN d.pc03 >= 0 THEN d.pc03 END) AS pc03_mean,
  MIN(CASE WHEN d.pc03 >= 0 THEN d.pc03 END) AS pc03_min,
  MAX(CASE WHEN d.pc03 >= 0 THEN d.pc03 END) AS pc03_max,
  SUM(CASE WHEN d.pc03 >= 0 THEN 1 ELSE 0 END) AS n_pc03_valid,

  AVG(CASE WHEN d.pc05 >= 0 THEN d.pc05 END) AS pc05_mean,
  MIN(CASE WHEN d.pc05 >= 0 THEN d.pc05 END) AS pc05_min,
  MAX(CASE WHEN d.pc05 >= 0 THEN d.pc05 END) AS pc05_max,
  SUM(CASE WHEN d.pc05 >= 0 THEN 1 ELSE 0 END) AS n_pc05_valid,

  AVG(CASE WHEN d.pc1  >= 0 THEN d.pc1  END) AS pc1_mean,
  MIN(CASE WHEN d.pc1  >= 0 THEN d.pc1  END) AS pc1_min,
  MAX(CASE WHEN d.pc1  >= 0 THEN d.pc1  END) AS pc1_max,
  SUM(CASE WHEN d.pc1  >= 0 THEN 1 ELSE 0 END) AS n_pc1_valid,

  AVG(CASE WHEN d.pc25 >= 0 THEN d.pc25 END) AS pc25_mean,
  MIN(CASE WHEN d.pc25 >= 0 THEN d.pc25 END) AS pc25_min,
  MAX(CASE WHEN d.pc25 >= 0 THEN d.pc25 END) AS pc25_max,
  SUM(CASE WHEN d.pc25 >= 0 THEN 1 ELSE 0 END) AS n_pc25_valid,

  AVG(CASE WHEN d.pc5  >= 0 THEN d.pc5  END) AS pc5_mean,
  MIN(CASE WHEN d.pc5  >= 0 THEN d.pc5  END) AS pc5_min,
  MAX(CASE WHEN d.pc5  >= 0 THEN d.pc5  END) AS pc5_max,
  SUM(CASE WHEN d.pc5  >= 0 THEN 1 ELSE 0 END) AS n_pc5_valid,

  AVG(CASE WHEN d.pc10 >= 0 THEN d.pc10 END) AS pc10_mean,
  MIN(CASE WHEN d.pc10 >= 0 THEN d.pc10 END) AS pc10_min,
  MAX(CASE WHEN d.pc10 >= 0 THEN d.pc10 END) AS pc10_max,
  SUM(CASE WHEN d.pc10 >= 0 THEN 1 ELSE 0 END) AS n_pc10_valid,

  -- Environmental variables (NOT NULL by schema)
  AVG(d.temperature) AS temperature_mean,
  MIN(d.temperature) AS temperature_min,
  MAX(d.temperature) AS temperature_max,

  AVG(d.humidity) AS humidity_mean,
  MIN(d.humidity) AS humidity_min,
  MAX(d.humidity) AS humidity_max,

  AVG(d.pressure) AS pressure_mean,
  MIN(d.pressure) AS pressure_min,
  MAX(d.pressure) AS pressure_max,

  AVG(d.sound) AS sound_mean,
  MIN(d.sound) AS sound_min,
  MAX(d.sound) AS sound_max,

  AVG(d.uvb) AS uvb_mean,
  MIN(d.uvb) AS uvb_min,
  MAX(d.uvb) AS uvb_max,

  AVG(d.light) AS light_mean,
  MIN(d.light) AS light_min,
  MAX(d.light) AS light_max,

  COUNT(*) AS n_measurements

FROM myair_strict_second_dedup AS d
GROUP BY d.deviceId, d.firmware, DATE(d.event_ts), HOUR(d.event_ts)
ORDER BY d.deviceId, d.firmware, date, hour;