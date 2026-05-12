make_hourly_wide_table <- function(domain_filter = NULL,
                                   exclude_measurements = c("oxygens", "sleeprate"),
                                   min_n_obs_valid = 10,
                                   accepted_types = c("mean", "sum"),
                                   event_sep = "__",
                                   cores = 5,
                                   return_meta = FALSE) {
  
  if (!is.null(domain_filter)) {
    domain_filter <- match.arg(
      domain_filter,
      choices = c("environmental", "physiological")
    )
  }
  
  data <- read_trigger_tables(
    granularity = "hourly",
    cores = cores,
    min_obs_per_hour = min_n_obs_valid
  ) |>
    add_measurement_domain()
  
  data_filtered <- data |>
    dplyr::filter(source != "gps") |>
    dplyr::filter(n_obs_valid >= min_n_obs_valid) |>
    dplyr::filter(type %in% accepted_types) |>
    dplyr::filter(!measurement %in% exclude_measurements) |>
    dplyr::filter(!is.na(value)) |>
    dplyr::filter(!(userId == 61 & date == "2025-07-30" & hour == 0))
  
  if (!is.null(domain_filter)) {
    data_filtered <- data_filtered |>
      dplyr::filter(domain == domain_filter)
  }
  
  data_wide <- data_filtered |>
    dplyr::mutate(n_expected = dplyr::n_distinct(measurement)) |>
    dplyr::select(userId, date, hour, measurement, value, n_expected) |>
    tidyr::unite("event", userId, date, hour, sep = event_sep, remove = FALSE) |>
    dplyr::group_by(event) |>
    dplyr::filter(dplyr::n_distinct(measurement) == dplyr::first(n_expected)) |>
    dplyr::ungroup() |>
    dplyr::select(event, measurement, value) |>
    tidyr::pivot_wider(
      names_from = measurement,
      values_from = value
    ) |>
    tibble::column_to_rownames("event")
  
  if (!return_meta) {
    return(data_wide)
  }
  
  accounts <- active_accounts() |>
    dplyr::select(userId, country)
  
  meta <- tibble::tibble(event = rownames(data_wide)) |>
    tidyr::separate(
      event,
      into = c("userId", "date", "hour"),
      sep = event_sep,
      remove = FALSE
    ) |>
    dplyr::mutate(
      userId = forcats::as_factor(as.character(userId)),
      date = lubridate::as_date(date),
      hour = as.integer(hour)
    ) |>
    dplyr::left_join(accounts, by = "userId") |>
    tibble::column_to_rownames("event") 
  
  stopifnot(all(rownames(meta) == rownames(data_wide)))
  
  list(
    data = data_wide,
    meta = meta
  )
}


make_daily_wide_table <- function(domain_filter = NULL,
                                  include_measurements = NULL,
                                  exclude_measurements = c("oxygens", "sleeprate"),
                                  min_n_hour_obs_valid = 10,
                                  min_n_daily_obs_valid = 12,
                                  with_sleep = FALSE,
                                  accepted_types = c("mean", "sum"),
                                  event_sep = "__",
                                  cores = 5,
                                  return_meta = FALSE) {
  
  if (!is.null(domain_filter)) {
    domain_filter <- match.arg(
      domain_filter,
      choices = c("environmental", "physiological")
    )
  }
  
  data <- read_trigger_tables(
    granularity = "daily",
    cores = cores,
    min_obs_per_hour = min_n_hour_obs_valid
  ) |>
    add_measurement_domain()
  
  data_other <- data |>
    dplyr::filter(!source %in% c("gps", "sleep"))
  
  data_filtered <- data_other |>
    dplyr::filter(type %in% accepted_types) |>
    dplyr::filter(!is.na(value)) |>
    dplyr::filter(!(userId == 61 & date == as.Date("2025-07-30"))) |>
    dplyr::filter(n_hours_covered >= min_n_daily_obs_valid)
  
  if (!is.null(domain_filter)) {
    data_filtered <- data_filtered |>
      dplyr::filter(domain == domain_filter)
  }
  
  if (with_sleep) {
    data_sleep <- data |>
      dplyr::filter(source == "sleep")
    
    data_filtered <- data_filtered |>
      dplyr::bind_rows(data_sleep)
  }
  
  if (!is.null(include_measurements)) {
    data_filtered <- data_filtered |>
      dplyr::filter(measurement %in% include_measurements)
  } else {
    data_filtered <- data_filtered |>
      dplyr::filter(!measurement %in% exclude_measurements)
  }
  
  data_wide <- data_filtered |>
    dplyr::mutate(n_expected = dplyr::n_distinct(measurement)) |>
    dplyr::select(userId, date, measurement, value, n_expected) |>
    tidyr::unite("event", userId, date, sep = event_sep, remove = FALSE) |>
    dplyr::group_by(event) |>
    dplyr::filter(dplyr::n_distinct(measurement) == dplyr::first(n_expected)) |>
    dplyr::ungroup() |>
    dplyr::select(event, measurement, value) |>
    tidyr::pivot_wider(
      names_from = measurement,
      values_from = value
    ) |>
    tibble::column_to_rownames("event")
  
  if (!return_meta) {
    return(data_wide)
  }
  
  accounts <- active_accounts() |>
    dplyr::select(userId, country)
  
  meta <- tibble::tibble(event = rownames(data_wide)) |>
    tidyr::separate(
      event,
      into = c("userId", "date"),
      sep = event_sep,
      remove = FALSE
    ) |>
    dplyr::mutate(
      userId = forcats::as_factor(as.character(userId)),
      date = lubridate::as_date(date)
    ) |>
    dplyr::left_join(accounts, by = "userId") |>
    tibble::column_to_rownames("event") 
  
  stopifnot(all(rownames(meta) == rownames(data_wide)))
  
  list(
    data = data_wide,
    meta = meta
  )
}