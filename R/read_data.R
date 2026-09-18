# Remove all objects except the three retained datasets, including hidden objects.
clean_environment <- function(envir = .GlobalEnv) {
  keep <- c("trigger_5min", "trigger_hourly", "trigger_daily", "triggerR")
  rm(list = setdiff(ls(envir = envir, all.names = TRUE), keep), envir = envir)
  invisible(gc())
}

# Read a local table by name, optionally selecting original columns.
# IDs and profiles stay character; dates and timestamps are parsed in UTC.
# Filter measurement dates strictly between start_date and end_date in UTC.
# Account tables have no measurement date and are not filtered.
read_trigger_table <- function(table, data_dir = "data", columns = NULL,
  start_date = as.Date("2025-03-01"), end_date = as.Date(Sys.time(), tz = "UTC")) {
  start_date <- as.Date(start_date)
  end_date <- as.Date(end_date)
  stopifnot(length(start_date) == 1, length(end_date) == 1,
            !is.na(start_date), !is.na(end_date), start_date < end_date)
  folder <- if (table %in% c("accounts", "active_accounts")) "accounts" else sub(".*_", "", table)
  path <- file.path(data_dir, folder, paste0(table, ".csv.gz"))
  if (!file.exists(path)) stop("Local dump is missing: ", path, call. = FALSE)

  header <- names(readr::read_csv(path, n_max = 0, show_col_types = FALSE, name_repair = "check_unique"))
  types <- setNames(rep("?", length(header)), header)
  types[header %in% c("userId", "deviceId", "firmware", "nationality", "email") | grepl("profile$", header)] <- "c"
  types[grepl("(_ts|_at|_at_max)$|^bucket_(5min|hour)$", header)] <- "T"
  types[header == "date"] <- "D"
  if (is.null(columns)) columns <- header
  time_column <- intersect(c("date", "hour_ts", "minute_ts", "bucket_5min", "event_ts"), header)[1]
  if (table %in% c("accounts", "active_accounts")) time_column <- NA_character_
  read_columns <- unique(c(columns, time_column[!is.na(time_column)]))

  data <- suppressWarnings(readr::read_csv(
    path, col_select = tidyselect::all_of(read_columns), col_types = paste(types, collapse = ""),
    locale = readr::locale(tz = "UTC"), na = c("", "NA", "NULL"),
    name_repair = "check_unique", show_col_types = FALSE, progress = FALSE
  ))
  if (nrow(readr::problems(data)) > 0) stop("Parsing failed for ", table, call. = FALSE)
  if (!is.na(time_column)) {
    date <- as.Date(data[[time_column]], tz = "UTC")
    data <- data[!is.na(date) & date > start_date & date < end_date, ]
  }
  dplyr::select(data, tidyselect::all_of(columns))
}

read_trigger_active_accounts <- function(data_dir = "data", columns = c("userId", "nationality")) {
  read_trigger_table("active_accounts", data_dir, columns)
}

# Read all five-minute sources with one row per variable and statistics in columns.
# drop_na removes rows without measurements and with zero or missing n.
# Technical metadata and sleeprate are skipped; duplicates are retained.
read_trigger_5min <- function(data_dir = "data", drop_na = FALSE,
  start_date = as.Date("2025-03-01"), end_date = as.Date(Sys.time(), tz = "UTC")) {
  sources <- c("myair", "gps", "smartwatchhigh", "smartwatchlow")
  tables <- lapply(sources, function(source) {
    table <- paste0(source, "_5min")
    path <- file.path(data_dir, "5min", paste0(table, ".csv.gz"))
    columns <- names(readr::read_csv(path, n_max = 0, show_col_types = FALSE, name_repair = "check_unique"))
    columns <- setdiff(columns, c("source_created_at_max", "deviceId", "firmware", "device_n", "firmware_n", "observed_minute_n"))
    columns <- columns[!startsWith(columns, "sleeprate")]
    data <- read_trigger_table(table, data_dir, columns, start_date, end_date)
    data <- tidyr::pivot_longer(
      data, cols = -tidyselect::any_of(c("userId", "bucket_5min")),
      names_to = c("variable", ".value"), names_pattern = "^([^_]+)_(.+)$", values_drop_na = FALSE
    )
    if (drop_na) {
      data <- dplyr::filter(data, !(is.na(mean) & is.na(min) & is.na(max) & (is.na(n) | n == 0)))
    }
    dplyr::mutate(data, origin = source, .before = 1)
  })
  dplyr::bind_rows(tables)
}

# Read one five-minute statistic per variable, without its column suffix.
# Keep missing values and reject duplicate participant-time keys.
read_trigger_5min_wide <- function(data_dir = "data", statistic = "mean",
  start_date = as.Date("2025-03-01"), end_date = as.Date(Sys.time(), tz = "UTC")) {
  statistic <- match.arg(statistic, c("mean", "min", "max"))
  suffix <- paste0("_", statistic)
  sources <- c("myair", "gps", "smartwatchhigh", "smartwatchlow")
  keys <- c("userId", "bucket_5min")
  tables <- lapply(sources, function(source) {
    table <- paste0(source, "_5min")
    path <- file.path(data_dir, "5min", paste0(table, ".csv.gz"))
    columns <- names(readr::read_csv(path, n_max = 0, show_col_types = FALSE, name_repair = "check_unique"))
    columns <- c(keys, columns[endsWith(columns, suffix) & !startsWith(columns, "sleeprate")])
    data <- read_trigger_table(table, data_dir, columns, start_date, end_date)
    if (anyDuplicated(data[keys])) stop("Duplicate keys in ", table, call. = FALSE)
    dplyr::rename_with(data, ~ sub(paste0(suffix, "$"), "", .x), -tidyselect::all_of(keys))
  })
  purrr::reduce(tables, ~ dplyr::full_join(.x, .y, by = keys, relationship = "one-to-one"))
}

# Read all hourly sources except sleeprate, retaining separate variable statistics.
# Keep per-variable coverage; skip shared observed_* counts.
read_trigger_hourly <- function(data_dir = "data",
  start_date = as.Date("2025-03-01"), end_date = as.Date(Sys.time(), tz = "UTC")) {
  sources <- c("myair", "gps", "smartwatchhigh", "smartwatchlow")
  tables <- lapply(sources, function(source) {
    table <- paste0(source, "_hourly")
    path <- file.path(data_dir, "hourly", paste0(table, ".csv.gz"))
    columns <- names(readr::read_csv(path, n_max = 0, show_col_types = FALSE, name_repair = "check_unique"))
    columns <- setdiff(columns, c("source_created_at_max", "deviceId", "firmware",
                                 "mixed_device_5min_n", "mixed_firmware_5min_n",
                                 "observed_5min_n", "observed_minute_n"))
    columns <- columns[!startsWith(columns, "sleeprate")]
    data <- read_trigger_table(table, data_dir, columns, start_date, end_date)
    data <- tidyr::pivot_longer(
      data, cols = -tidyselect::any_of(c("userId", "hour_ts")),
      names_to = c("variable", ".value"), names_pattern = "^([^_]+)_(.+)$", values_drop_na = FALSE
    )
    dplyr::mutate(data, origin = source, .before = 1)
  })
  dplyr::bind_rows(tables)
}

# Read daily measurements into value, with statistic mean, min, max or sleep.
# Keep only per-variable coverage profiles; skip shared coverage and sleeprate.
read_trigger_daily <- function(data_dir = "data",
  start_date = as.Date("2025-03-01"), end_date = as.Date(Sys.time(), tz = "UTC")) {
  sources <- c("myair", "gps", "smartwatchhigh", "smartwatchlow")
  coverage <- c("hours_n", "five_min_n", "minute_n", "complete_hours_n", "five_min_profile")
  tables <- lapply(sources, function(source) {
    table <- paste0(source, "_daily")
    path <- file.path(data_dir, "daily", paste0(table, ".csv.gz"))
    columns <- names(readr::read_csv(path, n_max = 0, show_col_types = FALSE, name_repair = "check_unique"))
    columns <- setdiff(columns, c(coverage, "source_created_at_max", "deviceId", "firmware",
                                 "ambiguous_device_hour_n", "ambiguous_firmware_hour_n",
                                 "mixed_device_5min_n", "mixed_firmware_5min_n"))
    columns <- columns[!startsWith(columns, "sleeprate")]
    columns <- columns[!grepl("_(hours_n|5min_n|minute_n)$", columns)]
    data <- read_trigger_table(table, data_dir, columns, start_date, end_date)
    data <- tidyr::pivot_longer(
      data, cols = -tidyselect::any_of(c("userId", "date")),
      names_to = c("variable", ".value"), names_pattern = "^([^_]+)_(.+)$", values_drop_na = FALSE
    )
    data <- tidyr::pivot_longer(
      data, cols = tidyselect::all_of(c("mean", "min", "max")),
      names_to = "statistic", values_to = "value", values_drop_na = FALSE
    )
    dplyr::mutate(data, origin = source, .before = 1)
  })
  path <- file.path(data_dir, "tidy", "sleep_tidy.csv.gz")
  columns <- names(readr::read_csv(path, n_max = 0, show_col_types = FALSE, name_repair = "check_unique"))
  columns <- setdiff(columns, c("created_at", "deviceId", "firmware"))
  sleep <- read_trigger_table("sleep_tidy", data_dir, columns, start_date, end_date)
  sleep <- tidyr::pivot_longer(sleep, cols = -tidyselect::all_of(c("userId", "date")),
                              names_to = "variable", values_to = "value", values_drop_na = FALSE)
  sleep <- dplyr::mutate(sleep, statistic = "sleep", .before = "value")
  dplyr::bind_rows(tables, dplyr::mutate(sleep, origin = "sleep", .before = 1))
}

# Filter daily statistics by hourly bucket coverage; keep sleep unchanged.
# Missing profiles fail the filter. Existing daily values are not recalculated.
filter_trigger_daily <- function(data, min_buckets_per_hour, min_hours) {
  stopifnot(length(min_buckets_per_hour) == 1, length(min_hours) == 1,
            min_buckets_per_hour %in% 1:12, min_hours %in% 1:24)
  profiles <- unique(data$`5min_profile`[data$statistic != "sleep"])
  valid <- vapply(profiles, function(profile) {
    if (is.na(profile)) return(FALSE)
    counts <- jsonlite::fromJSON(profile)
    if (length(counts) != 24 || anyNA(counts) || !all(counts %in% 0:12)) {
      stop("Invalid daily coverage profile.", call. = FALSE)
    }
    sum(counts >= min_buckets_per_hour) >= min_hours
  }, logical(1))
  dplyr::filter(data, statistic == "sleep" | `5min_profile` %in% profiles[valid])
}
