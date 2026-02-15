-- smartwatchhigh hourly -> daily (no weighted means)
-- Rule: include hourly mean/min/max only if the hour has n_valid > {{MIN_VALID}}
-- Also compute how many hours were actually used in each daily aggregation.

COPY (
  SELECT
    userId,
    deviceId,
    firmware,
    date,

    COUNT(*) AS n_hours_total,

    /* Heart rate */
    AVG(CASE WHEN n_heartrate_valid > {{MIN_VALID}} THEN heartrate_mean END) AS heartrate_mean_daily,
    MIN(CASE WHEN n_heartrate_valid > {{MIN_VALID}} THEN heartrate_min  END) AS heartrate_min_daily,
    MAX(CASE WHEN n_heartrate_valid > {{MIN_VALID}} THEN heartrate_max  END) AS heartrate_max_daily,
    SUM(CASE WHEN n_heartrate_valid > {{MIN_VALID}} THEN 1 ELSE 0 END)       AS n_hours_heartrate_used,

    /* Oxygens */
    AVG(CASE WHEN n_oxygens_valid > {{MIN_VALID}} THEN oxygens_mean END) AS oxygens_mean_daily,
    MIN(CASE WHEN n_oxygens_valid > {{MIN_VALID}} THEN oxygens_min  END) AS oxygens_min_daily,
    MAX(CASE WHEN n_oxygens_valid > {{MIN_VALID}} THEN oxygens_max  END) AS oxygens_max_daily,
    SUM(CASE WHEN n_oxygens_valid > {{MIN_VALID}} THEN 1 ELSE 0 END)     AS n_hours_oxygens_used,

    /* Breath rate */
    AVG(CASE WHEN n_breathrate_valid > {{MIN_VALID}} THEN breathrate_mean END) AS breathrate_mean_daily,
    MIN(CASE WHEN n_breathrate_valid > {{MIN_VALID}} THEN breathrate_min  END) AS breathrate_min_daily,
    MAX(CASE WHEN n_breathrate_valid > {{MIN_VALID}} THEN breathrate_max  END) AS breathrate_max_daily,
    SUM(CASE WHEN n_breathrate_valid > {{MIN_VALID}} THEN 1 ELSE 0 END)        AS n_hours_breathrate_used,

    /* Sleep rate */
    AVG(CASE WHEN n_sleeprate_valid > {{MIN_VALID}} THEN sleeprate_mean END) AS sleeprate_mean_daily,
    MIN(CASE WHEN n_sleeprate_valid > {{MIN_VALID}} THEN sleeprate_min  END) AS sleeprate_min_daily,
    MAX(CASE WHEN n_sleeprate_valid > {{MIN_VALID}} THEN sleeprate_max  END) AS sleeprate_max_daily,
    SUM(CASE WHEN n_sleeprate_valid > {{MIN_VALID}} THEN 1 ELSE 0 END)       AS n_hours_sleeprate_used,

    /* Diagnostics */
    SUM(n_measurements) AS n_measurements_daily

  FROM read_csv(
    '{{INFILE}}',
    delim='\t',
    header=true,
    compression='gzip',
    nullstr=['\\N','NULL','NA','NaN','Inf','-Inf',''],
    dateformat='%Y-%m-%d',
    types={
      'userId': 'DOUBLE',
      'deviceId': 'VARCHAR',
      'firmware': 'VARCHAR',
      'date': 'DATE',
      'hour': 'INTEGER',

      'heartrate_mean':  'DOUBLE', 'heartrate_min':  'DOUBLE', 'heartrate_max':  'DOUBLE',
      'oxygens_mean':    'DOUBLE', 'oxygens_min':    'DOUBLE', 'oxygens_max':    'DOUBLE',
      'breathrate_mean': 'DOUBLE', 'breathrate_min': 'DOUBLE', 'breathrate_max': 'DOUBLE',
      'sleeprate_mean':  'DOUBLE', 'sleeprate_min':  'DOUBLE', 'sleeprate_max':  'DOUBLE',

      'n_heartrate_valid':  'BIGINT',
      'n_oxygens_valid':    'BIGINT',
      'n_breathrate_valid': 'BIGINT',
      'n_sleeprate_valid':  'BIGINT',
      'n_measurements':     'BIGINT'
    }
  )

  GROUP BY userId, deviceId, firmware, date
)
TO '{{OUTFILE}}'
(DELIMITER '\t', HEADER true);