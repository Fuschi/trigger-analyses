-- smartwatchlow hourly -> daily (no weighted means)
-- Rule: include hourly mean/min/max only if n_valid > {{MIN_VALID}}

COPY (
  SELECT
    userId,
    deviceId,
    firmware,
    date,

    /* Total hours available */
    COUNT(*) AS n_hours_total,

    /* ===========================
       ACTIVITY (incremental)
    =========================== */
    SUM(steps_sum) AS steps_daily,
    SUM(cal_sum)   AS cal_daily,

    /* ===========================
       BLOOD PRESSURE HIGH
    =========================== */
    AVG(CASE WHEN n_bphigh_valid > {{MIN_VALID}} THEN bphigh_mean END) AS bphigh_mean_daily,
    MIN(CASE WHEN n_bphigh_valid > {{MIN_VALID}} THEN bphigh_min  END) AS bphigh_min_daily,
    MAX(CASE WHEN n_bphigh_valid > {{MIN_VALID}} THEN bphigh_max  END) AS bphigh_max_daily,
    SUM(CASE WHEN n_bphigh_valid > {{MIN_VALID}} THEN 1 ELSE 0 END)    AS n_hours_bphigh_used,

    /* ===========================
       BLOOD PRESSURE LOW
    =========================== */
    AVG(CASE WHEN n_bplow_valid > {{MIN_VALID}} THEN bplow_mean END) AS bplow_mean_daily,
    MIN(CASE WHEN n_bplow_valid > {{MIN_VALID}} THEN bplow_min  END) AS bplow_min_daily,
    MAX(CASE WHEN n_bplow_valid > {{MIN_VALID}} THEN bplow_max  END) AS bplow_max_daily,
    SUM(CASE WHEN n_bplow_valid > {{MIN_VALID}} THEN 1 ELSE 0 END)   AS n_hours_bplow_used,

    /* ===========================
       BODY TEMPERATURE
    =========================== */
    AVG(CASE WHEN n_bodytemp_valid > {{MIN_VALID}} THEN bodytemp_mean END) AS bodytemp_mean_daily,
    MIN(CASE WHEN n_bodytemp_valid > {{MIN_VALID}} THEN bodytemp_min  END) AS bodytemp_min_daily,
    MAX(CASE WHEN n_bodytemp_valid > {{MIN_VALID}} THEN bodytemp_max  END) AS bodytemp_max_daily,
    SUM(CASE WHEN n_bodytemp_valid > {{MIN_VALID}} THEN 1 ELSE 0 END)      AS n_hours_bodytemp_used,

    /* ===========================
       SKIN TEMPERATURE
    =========================== */
    AVG(CASE WHEN n_skintemp_valid > {{MIN_VALID}} THEN skintemp_mean END) AS skintemp_mean_daily,
    MIN(CASE WHEN n_skintemp_valid > {{MIN_VALID}} THEN skintemp_min  END) AS skintemp_min_daily,
    MAX(CASE WHEN n_skintemp_valid > {{MIN_VALID}} THEN skintemp_max  END) AS skintemp_max_daily,
    SUM(CASE WHEN n_skintemp_valid > {{MIN_VALID}} THEN 1 ELSE 0 END)      AS n_hours_skintemp_used,

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
      -- keys
      'userId': 'DOUBLE',
      'deviceId': 'VARCHAR',
      'firmware': 'VARCHAR',
      'date': 'DATE',
      'hour': 'INTEGER',

      -- activity
      'steps_sum': 'BIGINT',
      'cal_sum':   'BIGINT',

      -- blood pressure / temperature stats
      'bphigh_mean':  'DOUBLE', 'bphigh_min':  'DOUBLE', 'bphigh_max':  'DOUBLE',
      'bplow_mean':   'DOUBLE', 'bplow_min':   'DOUBLE', 'bplow_max':   'DOUBLE',
      'bodytemp_mean':'DOUBLE', 'bodytemp_min':'DOUBLE', 'bodytemp_max':'DOUBLE',
      'skintemp_mean':'DOUBLE', 'skintemp_min':'DOUBLE', 'skintemp_max':'DOUBLE',

      -- counters
      'n_bphigh_valid':   'BIGINT',
      'n_bplow_valid':    'BIGINT',
      'n_bodytemp_valid': 'BIGINT',
      'n_skintemp_valid': 'BIGINT',
      'n_measurements':   'BIGINT'
    }
  )

  GROUP BY userId, deviceId, firmware, date
)
TO '{{OUTFILE}}'
(DELIMITER '\t', HEADER true);
