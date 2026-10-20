# Remove intervals containing archived future participant-minute observations.
# Supports tidy, five-minute, hourly and daily data, in wide or long format.
# Aggregated intervals are removed entirely; statistics are not recalculated.
# Exclusions apply to every source and variable for the matching participant.
# Archived dates are not reassessed against today's date.
#
# Examples:
#   trigger_tidy <- drop_future(trigger_tidy)
#   trigger_daily <- drop_future(trigger_daily)
#   trigger_hourly <- drop_future(trigger_hourly, path = "../data/future_observations.csv.gz")

drop_future <- function(data, path = "data/future_observations.csv.gz") {
  keys <- intersect(c("minute_ts", "bucket_5min", "hour_ts", "date"), names(data))
  if (!"userId" %in% names(data) || length(keys) != 1L)
    stop("Expected userId and one of: minute_ts, bucket_5min, hour_ts, date.", call. = FALSE)
  key <- keys[[1]]
  
  excluded <- readr::read_csv(
    path, col_select = tidyselect::all_of(c("userId", "minute_ts")),
    col_types = readr::cols(userId = readr::col_character(), minute_ts = readr::col_datetime()),
    locale = readr::locale(tz = "UTC"), show_col_types = FALSE, progress = FALSE
  )
  readr::stop_for_problems(excluded)
  
  excluded <- excluded |>
    dplyr::transmute(userId, time = switch(
      key,
      minute_ts = minute_ts,
      bucket_5min = lubridate::floor_date(minute_ts, "5 minutes"),
      hour_ts = lubridate::floor_date(minute_ts, "hour"),
      date = as.Date(minute_ts, tz = "UTC")
    )) |>
    dplyr::rename(!!key := time) |>
    dplyr::distinct()
  
  dplyr::anti_join(data, excluded, by = c("userId", key))
}