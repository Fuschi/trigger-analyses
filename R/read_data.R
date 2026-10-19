# ---------------------------------------------------------------------------
# Internal CSV reader
# ---------------------------------------------------------------------------

# Read a local CSV.GZ dump with consistent column types.
# IDs and coverage profiles remain character; dates and timestamps use UTC.
# Column selection happens during reading to reduce memory use.

.read_trigger_csv <- function(table, data_dir = "data", columns = NULL) {
  folder <- sub("^.*_", "", table)
  path <- file.path(data_dir, folder, paste0(table, ".csv.gz"))
  if (!file.exists(path)) stop("Local dump is missing: ", path, call. = FALSE)
  
  header <- names(readr::read_csv(
    path, n_max = 0, name_repair = "check_unique", show_col_types = FALSE
  ))
  
  if (!is.null(columns)) {
    missing_columns <- setdiff(columns, header)
    if (length(missing_columns)) {
      stop("Unknown columns in ", table, ": ",
           paste(missing_columns, collapse = ", "), call. = FALSE)
    }
  }
  
  character_cols <- header[
    header %in% c("userId", "deviceId", "firmware", "email", "nationality") |
      grepl("profile$", header)
  ]
  datetime_cols <- grep("(_ts|_at|_at_max)$|^bucket_(5min|hour)$", header, value = TRUE)
  
  types <- readr::cols(.default = readr::col_guess())
  types$cols[character_cols] <- rep(list(readr::col_character()), length(character_cols))
  types$cols[datetime_cols] <- rep(list(readr::col_datetime()), length(datetime_cols))
  if ("date" %in% header) types$cols[["date"]] <- readr::col_date()
  
  read_columns <- if (is.null(columns)) header else columns
  data <- readr::read_csv(
    path, col_select = tidyselect::all_of(read_columns), col_types = types,
    locale = readr::locale(tz = "UTC"), na = c("", "NA", "NULL"),
    name_repair = "check_unique", show_col_types = FALSE, progress = FALSE
  )
  
  readr::stop_for_problems(data)
  data
}


# ---------------------------------------------------------------------------
# Accounts
# ---------------------------------------------------------------------------

# Read active_accounts by default, or the complete accounts table.
# This function does not filter participants or remove missing values.
#
# Examples:
#   active_accounts <- read_trigger_accounts()
#   accounts <- read_trigger_accounts("accounts")
#   nationality <- read_trigger_accounts(columns = c("userId", "nationality"))

read_trigger_accounts <- function(
    table = c("active_accounts", "accounts"), data_dir = "data", columns = NULL
) {
  table <- match.arg(table)
  .read_trigger_csv(table, data_dir = data_dir, columns = columns)
}


# ---------------------------------------------------------------------------
# Read tidy data
# ---------------------------------------------------------------------------

# Read selected minute-level sensor tables (all by default).
# Wide: one row per participant-minute, joined across sensors.
# Long: one row per measurement, with source, variable and value.
# Sensor measurements retain their original names and numeric types.

read_tidy <- function(
    tables = c("gps", "myair", "smartwatchhigh", "smartwatchlow"),
    format = c("wide", "long"),
    data_dir = "data"
) {
  format <- match.arg(format)
  allowed <- c("gps", "myair", "smartwatchhigh", "smartwatchlow")
  
  if (!length(tables) || anyNA(tables) || anyDuplicated(tables) ||
      !all(tables %in% allowed)) {
    stop("Invalid tables. Choose from: ", paste(allowed, collapse = ", "), call. = FALSE)
  }
  
  data <- purrr::map(tables, \(table) {
    .read_trigger_csv(paste0(table, "_tidy"), data_dir) |>
      dplyr::select(-tidyselect::any_of(c(
        "deviceId", "firmware", "event_ts", "created_at", "bucket_5min", "sleeprate")))
  })
  
  if (format == "wide") {
    return(purrr::reduce(data, dplyr::full_join, by = c("userId", "minute_ts"),
                         relationship = "one-to-one"))}
  
  purrr::map2_dfr(data, tables, \(x, table) {
    x |>
      tidyr::pivot_longer(
        cols = -tidyselect::all_of(c("userId", "minute_ts")),
        names_to = "variable", values_to = "value", values_drop_na = TRUE) |>
      dplyr::mutate(source = table, .before = variable)
  })
}

# ---------------------------------------------------------------------------
# Read five-minute data
# ---------------------------------------------------------------------------

# Read selected sources (all by default); exclude metadata and sleeprate.
# Wide: join sources by userId and bucket_5min.
# Long: source, variable, mean, min, max and n; drop rows with all statistics NA.
# only_mean = TRUE: remove "_mean" in wide; return variable/value without NA in long.
#
# Examples:
#   read_5min()
#   read_5min(only_mean = TRUE)
#   read_5min(format = "long")
#   read_5min(c("myair", "gps"), format = "long", only_mean = TRUE)

read_5min <- function(tables = c("gps", "myair", "smartwatchhigh", "smartwatchlow"),
                      format = c("wide", "long"), only_mean = TRUE, data_dir = "data") {
  format <- match.arg(format)
  allowed <- c("gps", "myair", "smartwatchhigh", "smartwatchlow")
  keys <- c("userId", "bucket_5min")
  
  if (!length(tables) || anyNA(tables) || anyDuplicated(tables) || !all(tables %in% allowed))
    stop("Invalid tables. Choose from: ", paste(allowed, collapse = ", "), call. = FALSE)
  stopifnot(is.logical(only_mean), length(only_mean) == 1L, !is.na(only_mean))
  
  data <- purrr::map(tables, \(table) {
    x <- .read_trigger_csv(paste0(table, "_5min"), data_dir) |>
      dplyr::select(-tidyselect::any_of(c("deviceId", "firmware", "source_created_at_max",
                                          "device_n", "firmware_n", "observed_minute_n")),
                    -tidyselect::matches("^sleeprate($|_)"))
    if (only_mean) return(x |>
                            dplyr::select(tidyselect::all_of(keys), tidyselect::ends_with("_mean")) |>
                            dplyr::rename_with(~ sub("_mean$", "", .x), tidyselect::ends_with("_mean")))
    dplyr::select(x, tidyselect::all_of(keys), tidyselect::matches("_(mean|min|max|n)$"))
  })
  
  if (format == "wide")
    return(purrr::reduce(data, dplyr::full_join, by = keys, relationship = "one-to-one"))
  
  purrr::map2_dfr(data, tables, \(x, table) {
    if (only_mean) return(x |>
                            tidyr::pivot_longer(-tidyselect::all_of(keys), names_to = "variable",
                                                values_to = "value", values_drop_na = TRUE) |>
                            dplyr::mutate(source = table, .before = variable))
    x |>
      tidyr::pivot_longer(-tidyselect::all_of(keys), names_to = c("variable", ".value"),
                          names_pattern = "^(.*)_(mean|min|max|n)$") |>
      dplyr::filter(dplyr::if_any(tidyselect::all_of(c("mean", "min", "max")), ~ !is.na(.x))) |>
      dplyr::mutate(source = table, .before = variable)
  })
}

# ---------------------------------------------------------------------------
# Read hourly data
# ---------------------------------------------------------------------------

# Read selected sources; retain statistics and valid five-minute bucket counts.
# min_5min: minimum valid buckets per variable-hour (1–12).
# Long: source, variable, value and n_5min; or mean/min/max and n_5min.
# Wide: join sources by userId/hour_ts; remove "_mean" when only_mean = TRUE.
# Exclude sleeprate, metadata and other coverage counts; drop missing measurements.
#
# Examples:
#   read_hourly()
#   read_hourly(format = "long", min_5min = 6)
#   read_hourly(c("myair", "gps"), only_mean = FALSE, min_5min = 12)

read_hourly <- function(tables = c("gps", "myair", "smartwatchhigh", "smartwatchlow"),
                        format = c("long", "wide"), only_mean = FALSE,
                        min_5min = 1, data_dir = "data") {
  format <- match.arg(format)
  allowed <- c("gps", "myair", "smartwatchhigh", "smartwatchlow")
  keys <- c("userId", "hour_ts")
  stats <- if (only_mean) "mean" else c("mean", "min", "max")
  
  if (!length(tables) || anyNA(tables) || anyDuplicated(tables) || !all(tables %in% allowed))
    stop("Invalid tables. Choose from: ", paste(allowed, collapse = ", "), call. = FALSE)
  stopifnot(is.logical(only_mean), length(only_mean) == 1L, !is.na(only_mean),
            length(min_5min) == 1L, !is.na(min_5min), min_5min %in% 1:12)
  
  data <- purrr::map(tables, \(table) {
    x <- .read_trigger_csv(paste0(table, "_hourly"), data_dir)
    variables <- names(x) |> stringr::str_subset("_mean$") |> stringr::str_remove("_mean$")
    variables <- variables[!stringr::str_detect(variables, "^sleeprate($|_)")]
    columns <- purrr::map(variables, ~ paste0(.x, "_", c(stats, "5min_n"))) |> purrr::list_c()
    
    x |>
      dplyr::select(tidyselect::all_of(c(keys, columns))) |>
      dplyr::rename_with(~ sub("_5min_n$", "_n_5min", .x), tidyselect::ends_with("_5min_n")) |>
      tidyr::pivot_longer(-tidyselect::all_of(keys), names_to = c("variable", ".value"),
                          names_pattern = "^(.*)_(mean|min|max|n_5min)$") |>
      dplyr::filter(n_5min >= min_5min,
                    dplyr::if_any(tidyselect::all_of(stats), ~ !is.na(.x))) |>
      dplyr::mutate(source = table, .before = variable)
  })
  
  if (format == "long") {
    x <- dplyr::bind_rows(data)
    if (only_mean) x <- dplyr::rename(x, value = mean)
    return(x)
  }
  
  purrr::map(data, \(x) {
    x <- x |>
      dplyr::select(-source) |>
      tidyr::pivot_wider(names_from = variable, values_from = tidyselect::all_of(c(stats, "n_5min")),
                         names_glue = "{variable}_{.value}") |>
      dplyr::rename_with(~ sub("_n_5min$", "_5min_n", .x), tidyselect::ends_with("_n_5min"))
    if (only_mean) x <- dplyr::rename_with(x, ~ sub("_mean$", "", .x), tidyselect::ends_with("_mean"))
    x
  }) |>
    purrr::reduce(dplyr::full_join, by = keys, relationship = "one-to-one")
}


# ---------------------------------------------------------------------------
# Read daily data
# ---------------------------------------------------------------------------

# Read selected sources; retain statistics and per-variable daily profiles.
# min_hours: minimum qualifying hours per day (1–24).
# min_5min: minimum valid five-minute buckets per qualifying hour (1–12).
# Filter each variable using its profile: a JSON array of 24 hourly bucket counts.
# Preserve the original profile; exclude all other coverage counts and metadata.
# Sleeprate and sleep data are excluded.
#
# Long: source, variable, value and profile; or mean/min/max and profile.
# Wide: join sources by userId/date; retain <variable>_5min_profile.
# only_mean = TRUE removes "_mean" from wide measurement names.
# Missing measurements are removed before combining sources.
# Filtering does not recalculate daily statistics.
#
# Examples:
#   read_daily()
#   read_daily(min_hours = 16, min_5min = 6)
#   read_daily(format = "long", min_hours = 16, min_5min = 9)
#   read_daily(c("myair", "gps"), only_mean = FALSE, min_hours = 12, min_5min = 6)

read_daily <- function(tables = c("gps", "myair", "smartwatchhigh", "smartwatchlow"),
                       format = c("long", "wide"), only_mean = FALSE,
                       min_hours = 1, min_5min = 1, data_dir = "data") {
  format <- match.arg(format)
  allowed <- c("gps", "myair", "smartwatchhigh", "smartwatchlow")
  keys <- c("userId", "date")
  
  if (!length(tables) || anyNA(tables) || anyDuplicated(tables) || !all(tables %in% allowed))
    stop("Invalid tables. Choose from: ", paste(allowed, collapse = ", "), call. = FALSE)
  stopifnot(is.logical(only_mean), length(only_mean) == 1L, !is.na(only_mean),
            length(min_hours) == 1L, !is.na(min_hours), min_hours %in% 1:24,
            length(min_5min) == 1L, !is.na(min_5min), min_5min %in% 1:12)
  
  stats <- if (only_mean) "mean" else c("mean", "min", "max")
  data <- purrr::map(tables, \(table) {
    x <- .read_trigger_csv(paste0(table, "_daily"), data_dir)
    variables <- names(x) |> stringr::str_subset("_mean$") |> stringr::str_remove("_mean$")
    variables <- variables[!stringr::str_detect(variables, "^sleeprate($|_)")]
    columns <- purrr::map(variables, ~ paste0(.x, "_", c(stats, "5min_profile"))) |> purrr::list_c()
    
    x <- x |>
      dplyr::select(tidyselect::all_of(c(keys, columns))) |>
      dplyr::rename_with(~ sub("_5min_profile$", "_profile", .x),
                         tidyselect::ends_with("_5min_profile")) |>
      tidyr::pivot_longer(-tidyselect::all_of(keys), names_to = c("variable", ".value"),
                          names_pattern = "^(.*)_(mean|min|max|profile)$")
    
    # Parse each distinct profile once; missing profiles fail the filter.
    valid_profiles <- x |>
      dplyr::distinct(profile) |>
      dplyr::filter(purrr::map_lgl(profile, \(p)
                                   !is.na(p) && sum(jsonlite::fromJSON(p) >= min_5min) >= min_hours))
    
    x |>
      dplyr::semi_join(valid_profiles, by = "profile") |>
      dplyr::filter(dplyr::if_any(tidyselect::all_of(stats), ~ !is.na(.x))) |>
      dplyr::mutate(source = table, .before = variable)
  })
  
  if (format == "long") {
    x <- dplyr::bind_rows(data)
    if (only_mean) x <- dplyr::rename(x, value = mean)
    return(x)
  }
  
  purrr::map(data, \(x) {
    x <- x |>
      dplyr::select(-source) |>
      tidyr::pivot_wider(names_from = variable, values_from = tidyselect::all_of(c(stats, "profile")),
                         names_glue = "{variable}_{.value}") |>
      dplyr::rename_with(~ sub("_profile$", "_5min_profile", .x),
                         tidyselect::ends_with("_profile"))
    if (only_mean) x <- dplyr::rename_with(x, ~ sub("_mean$", "", .x), tidyselect::ends_with("_mean"))
    x
  }) |>
    purrr::reduce(dplyr::full_join, by = keys, relationship = "one-to-one")
}
