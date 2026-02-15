-- gps hourly -> daily (no weighted means)
-- Rule: include hourly mean/min/max only if n_accuracy_valid > {{MIN_VALID}}

COPY (
  SELECT
    userId,
    deviceId,
    firmware,
    date,

    COUNT(*) AS n_hours_total,

    AVG(CASE WHEN n_accuracy_valid > {{MIN_VALID}} THEN latitude_mean  END) AS latitude_mean_daily,
    MIN(CASE WHEN n_accuracy_valid > {{MIN_VALID}} THEN latitude_min   END) AS latitude_min_daily,
    MAX(CASE WHEN n_accuracy_valid > {{MIN_VALID}} THEN latitude_max   END) AS latitude_max_daily,

    AVG(CASE WHEN n_accuracy_valid > {{MIN_VALID}} THEN longitude_mean END) AS longitude_mean_daily,
    MIN(CASE WHEN n_accuracy_valid > {{MIN_VALID}} THEN longitude_min  END) AS longitude_min_daily,
    MAX(CASE WHEN n_accuracy_valid > {{MIN_VALID}} THEN longitude_max  END) AS longitude_max_daily,

    AVG(CASE WHEN n_accuracy_valid > {{MIN_VALID}} THEN accuracy_mean END) AS accuracy_mean_daily,
    MIN(CASE WHEN n_accuracy_valid > {{MIN_VALID}} THEN accuracy_min  END) AS accuracy_min_daily,
    MAX(CASE WHEN n_accuracy_valid > {{MIN_VALID}} THEN accuracy_max  END) AS accuracy_max_daily,

    SUM(CASE WHEN n_accuracy_valid > {{MIN_VALID}} THEN 1 ELSE 0 END) AS n_hours_accuracy_used,

    SUM(n_measurements)     AS n_measurements_daily,
    SUM(n_accuracy_valid)   AS n_accuracy_valid_daily

  FROM read_csv(
    '{{INFILE}}',
    delim='\t',
    header=true,
    compression='gzip',
    nullstr=['\\N','NULL','NA','NaN','Inf','-Inf'],
    dateformat='%Y-%m-%d',
    types={
      'userId': 'DOUBLE',
      'hour': 'INTEGER',
      'n_measurements': 'BIGINT',
      'n_accuracy_valid': 'BIGINT',

      'latitude_mean': 'DOUBLE',
      'latitude_min':  'DOUBLE',
      'latitude_max':  'DOUBLE',

      'longitude_mean': 'DOUBLE',
      'longitude_min':  'DOUBLE',
      'longitude_max':  'DOUBLE',

      'accuracy_mean': 'DOUBLE',
      'accuracy_min':  'DOUBLE',
      'accuracy_max':  'DOUBLE'
    }
  )

  GROUP BY userId, deviceId, firmware, date
)
TO '{{OUTFILE}}'
(DELIMITER '\t', HEADER true);