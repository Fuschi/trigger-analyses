#' Read Trigger tables through a common interface
#'
#' Read one or more supported Trigger tables at the selected granularity.
#' If `tables` is not supplied, all tables available for that granularity
#' are read.
#'
#' @param con A DBI connection. If `NULL`, a connection is opened internally
#'   using the supplied connection parameters.
#' @param tables Character vector of source tables to read. If `NULL`,
#'   all tables for the selected granularity are used.
#' @param granularity Either `"hourly"` or `"daily"`.
#' @param min_obs_per_hour Minimum observations required for a respectable
#'   hourly aggregation when reading daily data. Defaults to `0`.
#' @param output Either `"list"` to return a named list of tibbles or
#'   `"long"` to return a single tibble in long format.
#' @param cores Number of CPU workers to use. If `cores = 1`, tables are read
#'   sequentially. If `cores > 1`, tables are read in parallel using one
#'   database connection per worker.
#' @param connection A named list of database connection parameters. Defaults
#'   to the TriggerIO local tunnel configuration.
#' @param verbose Logical. If `TRUE`, print short progress messages.
#'
#' @return A named list of tibbles or a single tibble.
#' @export
NULL


longer_hourly_table <- function(x, source) {
  records_col <- switch(
    source,
    gps = rlang::sym("gps_records_n"),
    myair = rlang::sym("myair_records_n"),
    smartwatchhigh = rlang::sym("smartwatchhigh_records_n"),
    smartwatchlow = rlang::sym("smartwatchlow_records_n")
  )

  x |>
    dplyr::rename(n_records_total = !!records_col) |>
    dplyr::mutate(source = source, .before = 1) |>
    tidyr::pivot_longer(
      cols = tidyselect::matches("(_sum|_min|_max|_mean|_valid_n|_hours_n)$"),
      names_to = c("measurement", "type"),
      names_pattern = "^([^_]+)_(.*)$",
      values_to = "value",
      values_transform = list(value = as.double)
    ) |>
    dplyr::group_by(source, userId, deviceId, firmware, date, hour, measurement) |>
    dplyr::mutate(n_obs_valid = value[type == "valid_n"], .after = "n_records_total") |>
    dplyr::filter(type != "valid_n") |>
    dplyr::ungroup()
}


longer_daily_table <- function(x, source) {
  x |>
    dplyr::rename(n_records_total = records_n) |>
    dplyr::mutate(source = source, .before = 1) |>
    tidyr::pivot_longer(
      cols = tidyselect::matches("(_sum|_min|_max|_mean|_valid_n|_hours_n)$"),
      names_to = c("measurement", "type"),
      names_pattern = "^([^_]+)_(.*)$",
      values_to = "value",
      values_transform = list(value = as.double)
    ) |>
    dplyr::group_by(source, userId, deviceId, firmware, date, measurement) |>
    dplyr::mutate(
      n_obs_valid = value[type == "valid_n"],
      n_hours_covered = value[type == "hours_n"],
      .after = "n_records_total"
    ) |>
    dplyr::filter(!type %in% c("valid_n", "hours_n")) |>
    dplyr::ungroup()
}


longer_daily_sleep <- function(x) {
  x |>
    dplyr::mutate(source = "sleep", .before = 1) |>
    tidyr::pivot_longer(
      cols = sleepduration:dplyr::last_col(),
      names_to = "measurement",
      values_to = "value",
      values_transform = list(value = as.double)
    ) |>
    dplyr::mutate(
      type = "daily",
      n_records_total = NA_real_,
      n_hours_covered = NA_real_,
      n_obs_valid = NA_real_,
      .after = "date"
    ) |>
    dplyr::relocate(type, .after = measurement)
}


read_one_trigger_table <- function(tbl,
                                   requested_readers,
                                   granularity,
                                   min_obs_per_hour,
                                   con) {
  reader <- requested_readers[[tbl]]

  if (granularity == "daily" && tbl != "sleep") {
    reader(con, min_valid_n = min_obs_per_hour)
  } else {
    reader(con)
  }
}


reshape_one_trigger_table <- function(x, tbl, granularity) {
  if (granularity == "hourly") {
    return(longer_hourly_table(x, source = tbl))
  }

  if (tbl == "sleep") {
    return(longer_daily_sleep(x))
  }

  longer_daily_table(x, source = tbl)
}


read_trigger_tables <- function(con = NULL,
                                tables = NULL,
                                granularity = c("hourly", "daily"),
                                min_obs_per_hour = 0,
                                output = c("long", "list"),
                                cores = 1,
                                connection = list(
                                  host = "127.0.0.1",
                                  port = 3336L,
                                  user = "triggerIO",
                                  password = "triggerIO",
                                  dbname = "triggerIO"
                                ),
                                verbose = FALSE) {
  if (!is.null(con) && !inherits(con, "DBIConnection")) {
    stop("`con` must be NULL or a valid DBI connection.")
  }

  granularity <- match.arg(granularity)
  output <- match.arg(output)

  available_tables <- switch(
    granularity,
    hourly = c("gps", "myair", "smartwatchhigh", "smartwatchlow"),
    daily = c("gps", "myair", "sleep", "smartwatchhigh", "smartwatchlow")
  )

  if (is.null(tables)) {
    tables <- available_tables
  }

  if (!is.character(tables) || !length(tables)) {
    stop("`tables` must be NULL or a non-empty character vector.")
  }

  unsupported <- setdiff(tables, available_tables)

  if (length(unsupported)) {
    stop(
      "Unsupported table(s) for `", granularity, "` granularity: ",
      paste(unsupported, collapse = ", "),
      ". Available tables are: ",
      paste(available_tables, collapse = ", "),
      "."
    )
  }

  if (granularity == "daily") {
    if (length(min_obs_per_hour) != 1 || is.na(min_obs_per_hour) || !is.numeric(min_obs_per_hour)) {
      stop("`min_obs_per_hour` must be a single numeric value when `granularity = 'daily'`.")
    }
  }

  if (length(cores) != 1 || is.na(cores) || !is.numeric(cores) || cores < 1) {
    stop("`cores` must be a single numeric value greater than or equal to 1.")
  }

  cores <- as.integer(cores)

  connection_defaults <- list(
    host = "127.0.0.1",
    port = 3336L,
    user = "triggerIO",
    password = "triggerIO",
    dbname = "triggerIO"
  )
  connection <- utils::modifyList(connection_defaults, connection)

  reader_funs <- switch(
    granularity,
    hourly = list(
      gps = gps_hourly,
      myair = myair_hourly,
      smartwatchhigh = smartwatchhigh_hourly,
      smartwatchlow = smartwatchlow_hourly
    ),
    daily = list(
      gps = gps_daily,
      myair = myair_daily,
      sleep = sleep_tidy,
      smartwatchhigh = smartwatchhigh_daily,
      smartwatchlow = smartwatchlow_daily
    )
  )

  requested_readers <- reader_funs[tables]

  if (verbose) {
    message(
      "Reading ", length(tables), " table(s) at `", granularity,
      "` granularity with `cores = ", cores, "`."
    )
  }

  if (cores > 1) {
    old_plan <- future::plan()
    on.exit(future::plan(old_plan), add = TRUE)
    future::plan(future::multisession, workers = min(length(tables), cores))

    out <- furrr::future_map(
      tables,
      \(tbl) {
        if (verbose) message("Opening internal connection for `", tbl, "`")
        con_worker <- do.call(connect_trigger_db, connection)
        on.exit(DBI::dbDisconnect(con_worker), add = TRUE)

        x <- read_one_trigger_table(
          tbl = tbl,
          requested_readers = requested_readers,
          granularity = granularity,
          min_obs_per_hour = min_obs_per_hour,
          con = con_worker
        )

        if (output == "long") {
          reshape_one_trigger_table(x, tbl = tbl, granularity = granularity)
        } else {
          x
        }
      },
      .options = furrr::furrr_options(seed = TRUE)
    )

    names(out) <- tables
  } else {
    out <- vector("list", length(tables))
    names(out) <- tables

    if (is.null(con)) {
      if (verbose) message("Opening shared internal connection")
      con <- do.call(connect_trigger_db, connection)
      on.exit(DBI::dbDisconnect(con), add = TRUE)
    }

    for (tbl in tables) {
      if (verbose) message("Reading `", tbl, "`")
      out[[tbl]] <- read_one_trigger_table(
        tbl = tbl,
        requested_readers = requested_readers,
        granularity = granularity,
        min_obs_per_hour = min_obs_per_hour,
        con = con
      )
    }
  }

  if (output == "list") {
    if (verbose) message("Returning list output")
    return(out)
  }

  if (cores > 1) {
    if (verbose) message("Binding parallel long-format results")
    return(dplyr::bind_rows(out))
  }

  if (verbose) message("Reshaping tables to long format")
  purrr::imap_dfr(out, \(x, idx) reshape_one_trigger_table(x, tbl = idx, granularity = granularity))
}
