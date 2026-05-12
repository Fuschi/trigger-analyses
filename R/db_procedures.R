#' Trigger readers and procedures
#'
#' Utility functions to read hourly aggregated tables and call
#' stored procedures, returning results as tibbles.
#'
#' @keywords internal
NULL


# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------

#' Execute a stored procedure and return a tibble
#'
#' @param con A DBI connection. If `NULL`, the default TriggerIO connection
#'   is opened internally.
#' @param procedure Name of the stored procedure.
#' @param params A character vector of SQL literals.
#'
#' @return A tibble.
#' @keywords internal
db_call_procedure <- function(con, procedure, params) {
  opened_here <- is.null(con)

  if (opened_here) {
    con <- connect_trigger_db()
  }

  res <- NULL
  on.exit({
    if (!is.null(res)) {
      try(DBI::dbClearResult(res), silent = TRUE)
    }
    if (opened_here) {
      try(DBI::dbDisconnect(con), silent = TRUE)
    }
  }, add = FALSE)

  sql <- paste0(
    "CALL ",
    procedure,
    "(",
    paste(params, collapse = ", "),
    ")"
  )
  
  res <- DBI::dbSendQuery(con, sql)
  
  tibble::as_tibble(DBI::dbFetch(res))
}


#' Read a full table and return a tibble
#'
#' @param con A DBI connection. If `NULL`, the default TriggerIO connection
#'   is opened internally.
#' @param table Name of the table.
#'
#' @return A tibble.
#' @keywords internal
db_read_table <- function(con, table) {
  if (is.null(con)) {
    con <- connect_trigger_db()
    on.exit(DBI::dbDisconnect(con), add = TRUE)
  }

  tibble::as_tibble(
    DBI::dbGetQuery(con, paste0("SELECT * FROM ", table))
  )
}


# ------------------------------------------------------------------
# Hourly aggregated tables
# ------------------------------------------------------------------

#' Get myair hourly data
#'
#' @param con A DBI connection. If `NULL`, the default TriggerIO connection
#'   is opened internally.
#'
#' @return A tibble.
#' @export
myair_hourly <- function(con = NULL) {
  db_read_table(con, "myair_hourly")
}


#' Get gps hourly data
#'
#' @param con A DBI connection. If `NULL`, the default TriggerIO connection
#'   is opened internally.
#'
#' @return A tibble.
#' @export
gps_hourly <- function(con = NULL) {
  db_read_table(con, "gps_hourly")
}


#' Get smartwatch high hourly data
#'
#' @param con A DBI connection. If `NULL`, the default TriggerIO connection
#'   is opened internally.
#'
#' @return A tibble.
#' @export
smartwatchhigh_hourly <- function(con = NULL) {
  db_read_table(con, "smartwatchhigh_hourly")
}


#' Get smartwatch low hourly data
#'
#' @param con A DBI connection. If `NULL`, the default TriggerIO connection
#'   is opened internally.
#'
#' @return A tibble.
#' @export
smartwatchlow_hourly <- function(con = NULL) {
  db_read_table(con, "smartwatchlow_hourly")
}


# ------------------------------------------------------------------
# Procedures without thresholds
# ------------------------------------------------------------------

#' Get active accounts
#'
#' @param con A DBI connection. If `NULL`, the default TriggerIO connection
#'   is opened internally.
#'
#' @return A tibble.
#' @export
active_accounts <- function(con = NULL) {
  db_call_procedure(con, "sp_active_accounts", character(0)) |>
    dplyr::mutate(userId = forcats::as_factor(as.character(userId)))
}


#' Get sleep tidy data
#'
#' Calls `sp_sleep_tidy` with all parameters set to NULL.
#'
#' @param con A DBI connection. If `NULL`, the default TriggerIO connection
#'   is opened internally.
#'
#' @return A tibble.
#' @export
sleep_tidy <- function(con = NULL) {
  params <- rep("NULL", 5)
  
  db_call_procedure(con, "sp_sleep_tidy", params)
}


# ------------------------------------------------------------------
# Daily procedures with min_valid_n
# ------------------------------------------------------------------

#' Get myair daily data
#'
#' Calls `sp_myair_daily` using `min_valid_n` as the default threshold
#' and NULL for all optional filters / metric-specific thresholds.
#'
#' @param con A DBI connection. If `NULL`, the default TriggerIO connection
#'   is opened internally.
#' @param min_valid_n Minimum valid observations required.
#'
#' @return A tibble.
#' @export
myair_daily <- function(min_valid_n, con = NULL) {
  stopifnot(
    length(min_valid_n) == 1,
    !is.na(min_valid_n),
    is.numeric(min_valid_n)
  )
  
  params <- c(
    as.character(min_valid_n),
    rep("NULL", 19)
  )
  
  db_call_procedure(con, "sp_myair_daily", params)
}


#' Get gps daily data
#'
#' Calls `sp_gps_daily` using `min_valid_n` as the default threshold
#' and NULL for all optional filters / metric-specific thresholds.
#'
#' @param con A DBI connection. If `NULL`, the default TriggerIO connection
#'   is opened internally.
#' @param min_valid_n Minimum valid observations required.
#'
#' @return A tibble.
#' @export
gps_daily <- function(min_valid_n, con = NULL) {
  stopifnot(
    length(min_valid_n) == 1,
    !is.na(min_valid_n),
    is.numeric(min_valid_n)
  )
  
  params <- c(
    as.character(min_valid_n),
    rep("NULL", 7)
  )
  
  db_call_procedure(con, "sp_gps_daily", params)
}


#' Get smartwatch high daily data
#'
#' Calls `sp_smartwatchhigh_daily` using `min_valid_n` as the default threshold
#' and NULL for all optional filters / metric-specific thresholds.
#'
#' @param con A DBI connection. If `NULL`, the default TriggerIO connection
#'   is opened internally.
#' @param min_valid_n Minimum valid observations required.
#'
#' @return A tibble.
#' @export
smartwatchhigh_daily <- function(min_valid_n, con = NULL) {
  stopifnot(
    length(min_valid_n) == 1,
    !is.na(min_valid_n),
    is.numeric(min_valid_n)
  )
  
  params <- c(
    as.character(min_valid_n),
    rep("NULL", 8)
  )
  
  db_call_procedure(con, "sp_smartwatchhigh_daily", params)
}


#' Get smartwatch low daily data
#'
#' Calls `sp_smartwatchlow_daily` using `min_valid_n` as the default threshold
#' and NULL for all optional filters / metric-specific thresholds.
#'
#' @param con A DBI connection. If `NULL`, the default TriggerIO connection
#'   is opened internally.
#' @param min_valid_n Minimum valid observations required.
#'
#' @return A tibble.
#' @export
smartwatchlow_daily <- function(min_valid_n, con = NULL) {
  stopifnot(
    length(min_valid_n) == 1,
    !is.na(min_valid_n),
    is.numeric(min_valid_n)
  )
  
  params <- c(
    as.character(min_valid_n),
    rep("NULL", 10)
  )
  
  db_call_procedure(con, "sp_smartwatchlow_daily", params)
}
