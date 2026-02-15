-- myair hourly -> daily (no weighted means)
-- Rule: include hourly mean/min/max only if the hour has n_valid > {{MIN_VALID}}
-- Also compute how many hours were actually used in each daily aggregation.

COPY (
  SELECT
    userId,
    deviceId,
    firmware,
    date,

    /* -------------------------
       PM (validity: n_*_valid)
    ------------------------- */

    -- PM1
    AVG(CASE WHEN n_pm1_valid  > {{MIN_VALID}} THEN pm1_mean END) AS pm1_mean_day,
    MIN(CASE WHEN n_pm1_valid  > {{MIN_VALID}} THEN pm1_min  END) AS pm1_min_day,
    MAX(CASE WHEN n_pm1_valid  > {{MIN_VALID}} THEN pm1_max  END) AS pm1_max_day,
    SUM(n_pm1_valid) AS n_pm1_valid_day,
    SUM(CASE WHEN n_pm1_valid  > {{MIN_VALID}} THEN 1 ELSE 0 END) AS pm1_hours_used_day,

    -- PM2.5
    AVG(CASE WHEN n_pm25_valid > {{MIN_VALID}} THEN pm25_mean END) AS pm25_mean_day,
    MIN(CASE WHEN n_pm25_valid > {{MIN_VALID}} THEN pm25_min  END) AS pm25_min_day,
    MAX(CASE WHEN n_pm25_valid > {{MIN_VALID}} THEN pm25_max  END) AS pm25_max_day,
    SUM(n_pm25_valid) AS n_pm25_valid_day,
    SUM(CASE WHEN n_pm25_valid > {{MIN_VALID}} THEN 1 ELSE 0 END) AS pm25_hours_used_day,

    -- PM10
    AVG(CASE WHEN n_pm10_valid > {{MIN_VALID}} THEN pm10_mean END) AS pm10_mean_day,
    MIN(CASE WHEN n_pm10_valid > {{MIN_VALID}} THEN pm10_min  END) AS pm10_min_day,
    MAX(CASE WHEN n_pm10_valid > {{MIN_VALID}} THEN pm10_max  END) AS pm10_max_day,
    SUM(n_pm10_valid) AS n_pm10_valid_day,
    SUM(CASE WHEN n_pm10_valid > {{MIN_VALID}} THEN 1 ELSE 0 END) AS pm10_hours_used_day,

    /* -------------------------
       Particle counts (validity: n_*_valid)
    ------------------------- */

    -- PC0.3
    AVG(CASE WHEN n_pc03_valid > {{MIN_VALID}} THEN pc03_mean END) AS pc03_mean_day,
    MIN(CASE WHEN n_pc03_valid > {{MIN_VALID}} THEN pc03_min  END) AS pc03_min_day,
    MAX(CASE WHEN n_pc03_valid > {{MIN_VALID}} THEN pc03_max  END) AS pc03_max_day,
    SUM(n_pc03_valid) AS n_pc03_valid_day,
    SUM(CASE WHEN n_pc03_valid > {{MIN_VALID}} THEN 1 ELSE 0 END) AS pc03_hours_used_day,

    -- PC0.5
    AVG(CASE WHEN n_pc05_valid > {{MIN_VALID}} THEN pc05_mean END) AS pc05_mean_day,
    MIN(CASE WHEN n_pc05_valid > {{MIN_VALID}} THEN pc05_min  END) AS pc05_min_day,
    MAX(CASE WHEN n_pc05_valid > {{MIN_VALID}} THEN pc05_max  END) AS pc05_max_day,
    SUM(n_pc05_valid) AS n_pc05_valid_day,
    SUM(CASE WHEN n_pc05_valid > {{MIN_VALID}} THEN 1 ELSE 0 END) AS pc05_hours_used_day,

    -- PC1
    AVG(CASE WHEN n_pc1_valid  > {{MIN_VALID}} THEN pc1_mean END) AS pc1_mean_day,
    MIN(CASE WHEN n_pc1_valid  > {{MIN_VALID}} THEN pc1_min  END) AS pc1_min_day,
    MAX(CASE WHEN n_pc1_valid  > {{MIN_VALID}} THEN pc1_max  END) AS pc1_max_day,
    SUM(n_pc1_valid) AS n_pc1_valid_day,
    SUM(CASE WHEN n_pc1_valid  > {{MIN_VALID}} THEN 1 ELSE 0 END) AS pc1_hours_used_day,

    -- PC2.5
    AVG(CASE WHEN n_pc25_valid > {{MIN_VALID}} THEN pc25_mean END) AS pc25_mean_day,
    MIN(CASE WHEN n_pc25_valid > {{MIN_VALID}} THEN pc25_min  END) AS pc25_min_day,
    MAX(CASE WHEN n_pc25_valid > {{MIN_VALID}} THEN pc25_max  END) AS pc25_max_day,
    SUM(n_pc25_valid) AS n_pc25_valid_day,
    SUM(CASE WHEN n_pc25_valid > {{MIN_VALID}} THEN 1 ELSE 0 END) AS pc25_hours_used_day,

    -- PC5
    AVG(CASE WHEN n_pc5_valid  > {{MIN_VALID}} THEN pc5_mean END) AS pc5_mean_day,
    MIN(CASE WHEN n_pc5_valid  > {{MIN_VALID}} THEN pc5_min  END) AS pc5_min_day,
    MAX(CASE WHEN n_pc5_valid  > {{MIN_VALID}} THEN pc5_max  END) AS pc5_max_day,
    SUM(n_pc5_valid) AS n_pc5_valid_day,
    SUM(CASE WHEN n_pc5_valid  > {{MIN_VALID}} THEN 1 ELSE 0 END) AS pc5_hours_used_day,

    -- PC10
    AVG(CASE WHEN n_pc10_valid > {{MIN_VALID}} THEN pc10_mean END) AS pc10_mean_day,
    MIN(CASE WHEN n_pc10_valid > {{MIN_VALID}} THEN pc10_min  END) AS pc10_min_day,
    MAX(CASE WHEN n_pc10_valid > {{MIN_VALID}} THEN pc10_max  END) AS pc10_max_day,
    SUM(n_pc10_valid) AS n_pc10_valid_day,
    SUM(CASE WHEN n_pc10_valid > {{MIN_VALID}} THEN 1 ELSE 0 END) AS pc10_hours_used_day,

    /* -------------------------
       Environmental sensors (validity: n_measurements)
    ------------------------- */

    -- Temperature
    AVG(CASE WHEN n_measurements > {{MIN_VALID}} THEN temperature_mean END) AS temperature_mean_day,
    MIN(CASE WHEN n_measurements > {{MIN_VALID}} THEN temperature_min  END) AS temperature_min_day,
    MAX(CASE WHEN n_measurements > {{MIN_VALID}} THEN temperature_max  END) AS temperature_max_day,
    SUM(CASE WHEN n_measurements > {{MIN_VALID}} THEN 1 ELSE 0 END) AS temperature_hours_used_day,

    -- Humidity
    AVG(CASE WHEN n_measurements > {{MIN_VALID}} THEN humidity_mean END) AS humidity_mean_day,
    MIN(CASE WHEN n_measurements > {{MIN_VALID}} THEN humidity_min  END) AS humidity_min_day,
    MAX(CASE WHEN n_measurements > {{MIN_VALID}} THEN humidity_max  END) AS humidity_max_day,
    SUM(CASE WHEN n_measurements > {{MIN_VALID}} THEN 1 ELSE 0 END) AS humidity_hours_used_day,

    -- Pressure
    AVG(CASE WHEN n_measurements > {{MIN_VALID}} THEN pressure_mean END) AS pressure_mean_day,
    MIN(CASE WHEN n_measurements > {{MIN_VALID}} THEN pressure_min  END) AS pressure_min_day,
    MAX(CASE WHEN n_measurements > {{MIN_VALID}} THEN pressure_max  END) AS pressure_max_day,
    SUM(CASE WHEN n_measurements > {{MIN_VALID}} THEN 1 ELSE 0 END) AS pressure_hours_used_day,

    -- Sound
    AVG(CASE WHEN n_measurements > {{MIN_VALID}} THEN sound_mean END) AS sound_mean_day,
    MIN(CASE WHEN n_measurements > {{MIN_VALID}} THEN sound_min  END) AS sound_min_day,
    MAX(CASE WHEN n_measurements > {{MIN_VALID}} THEN sound_max  END) AS sound_max_day,
    SUM(CASE WHEN n_measurements > {{MIN_VALID}} THEN 1 ELSE 0 END) AS sound_hours_used_day,

    -- UVB
    AVG(CASE WHEN n_measurements > {{MIN_VALID}} THEN uvb_mean END) AS uvb_mean_day,
    MIN(CASE WHEN n_measurements > {{MIN_VALID}} THEN uvb_min  END) AS uvb_min_day,
    MAX(CASE WHEN n_measurements > {{MIN_VALID}} THEN uvb_max  END) AS uvb_max_day,
    SUM(CASE WHEN n_measurements > {{MIN_VALID}} THEN 1 ELSE 0 END) AS uvb_hours_used_day,

    -- Light
    AVG(CASE WHEN n_measurements > {{MIN_VALID}} THEN light_mean END) AS light_mean_day,
    MIN(CASE WHEN n_measurements > {{MIN_VALID}} THEN light_min  END) AS light_min_day,
    MAX(CASE WHEN n_measurements > {{MIN_VALID}} THEN light_max  END) AS light_max_day,
    SUM(CASE WHEN n_measurements > {{MIN_VALID}} THEN 1 ELSE 0 END) AS light_hours_used_day,

    -- Total measurements (always summed)
    SUM(n_measurements) AS n_measurements_day

  FROM read_csv(
   '{{INFILE}}',
   delim='\t',
   header=true,
   compression='gzip',
   nullstr=['\\N','NULL','NA','NaN','Inf','-Inf',''],
   dateformat='%Y-%m-%d',
   types={
      -- keys
      'userId': 'DOUBLE',
      'deviceId': 'VARCHAR',
      'firmware': 'VARCHAR',
      'date': 'DATE',
      'hour': 'INTEGER',

      -- PM (double)
      'pm1_mean':  'DOUBLE', 'pm1_min':  'DOUBLE', 'pm1_max':  'DOUBLE', 'n_pm1_valid':  'BIGINT',
      'pm25_mean': 'DOUBLE', 'pm25_min': 'DOUBLE', 'pm25_max': 'DOUBLE', 'n_pm25_valid': 'BIGINT',
      'pm10_mean': 'DOUBLE', 'pm10_min': 'DOUBLE', 'pm10_max': 'DOUBLE', 'n_pm10_valid': 'BIGINT',

      -- Particle counts (double)
      'pc03_mean': 'DOUBLE', 'pc03_min': 'DOUBLE', 'pc03_max': 'DOUBLE', 'n_pc03_valid': 'BIGINT',
      'pc05_mean': 'DOUBLE', 'pc05_min': 'DOUBLE', 'pc05_max': 'DOUBLE', 'n_pc05_valid': 'BIGINT',
      'pc1_mean':  'DOUBLE', 'pc1_min':  'DOUBLE', 'pc1_max':  'DOUBLE', 'n_pc1_valid':  'BIGINT',
      'pc25_mean': 'DOUBLE', 'pc25_min': 'DOUBLE', 'pc25_max': 'DOUBLE', 'n_pc25_valid': 'BIGINT',
      'pc5_mean':  'DOUBLE', 'pc5_min':  'DOUBLE', 'pc5_max':  'DOUBLE', 'n_pc5_valid':  'BIGINT',
      'pc10_mean': 'DOUBLE', 'pc10_min': 'DOUBLE', 'pc10_max': 'DOUBLE', 'n_pc10_valid': 'BIGINT',

      -- Environmental sensors (double)
      'temperature_mean': 'DOUBLE', 'temperature_min': 'DOUBLE', 'temperature_max': 'DOUBLE',
      'humidity_mean':    'DOUBLE', 'humidity_min':    'DOUBLE', 'humidity_max':    'DOUBLE',
      'pressure_mean':    'DOUBLE', 'pressure_min':    'DOUBLE', 'pressure_max':    'DOUBLE',
      'sound_mean':       'DOUBLE', 'sound_min':       'DOUBLE', 'sound_max':       'DOUBLE',
      'uvb_mean':         'DOUBLE', 'uvb_min':         'DOUBLE', 'uvb_max':         'DOUBLE',
      'light_mean':       'DOUBLE', 'light_min':       'DOUBLE', 'light_max':       'DOUBLE',

      -- Counts
      'n_measurements': 'BIGINT'
   }
)

GROUP BY userId, deviceId, firmware, date
)
TO '{{OUTFILE}}'
(DELIMITER '\t', HEADER true);