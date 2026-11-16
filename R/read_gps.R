
# ---------------------------------------------------------------------------
# GPS data reading and Copernicus grid assignment
# ---------------------------------------------------------------------------
#
# Read GPS observations at tidy, 5-minute, hourly and daily resolutions,
# and associate their coordinates with the Copernicus ERA5-HEAT grid.
#
# The geographic grid has a resolution of 0.25 x 0.25 degrees. Each GPS
# coordinate is assigned to the nearest grid point by rounding latitude
# and longitude independently to multiples of 0.25 degrees.
#
# Data quality:
#   - Retain valid geographic coordinates.
#   - Filter GPS accuracy between 1 and 200 m by default.
#   - Allow custom accuracy limits through accuracy_min and accuracy_max.
#   - Derive calendar dates from minute_ts using UTC.
#
# Temporal aggregation:
#   - tidy:   assign each GPS observation directly to a grid point.
#   - 5min:   assign a grid point when observations within the same
#             5-minute interval are geographically consistent.
#   - hourly: assign the most frequently observed grid point within
#             each participant-hour.
#   - daily:  apply the same procedure to each participant-day.
#
# For aggregated data, all observed grid points must lie within the
# specified number of neighbouring grid cells around the reference point.
# The default tolerance is 0 for 5min and 1 for hourly/daily data.
# Ties between the most frequently observed grid points are not assigned.
#
# Unassigned periods are retained with missing grid coordinates.
#
# Coverage indicators include the number of GPS observations, observations
# in the reference cell, distinct observed hours, occupied grid cells,
# and timestamps of the first and last observations.
#
# Grid assignment reflects the available GPS observations and does not
# imply continuous participant presence at the assigned location.
#
# Methodological background and exploratory analyses:
#   analyses/gps-exploration.qmd
#
# ---------------------------------------------------------------------------


# Read GPS observations and assign Copernicus grid coordinates.
read_gps_tidy <- function(accuracy_min = 1, accuracy_max = 200) {
  readr::read_csv("data/tidy/gps_tidy.csv.gz",
                  col_select = c(userId, minute_ts, latitude, longitude, accuracy),
                  locale = readr::locale(tz = "UTC"), show_col_types = FALSE) |>
    dplyr::filter(dplyr::between(accuracy, accuracy_min, accuracy_max),
                  dplyr::between(latitude, -90, 90),
                  dplyr::between(longitude, -180, 180)) |>
    dplyr::mutate(
      userId = as.character(userId),
      date = as.Date(minute_ts, tz = "UTC"),
      grid_latitude = round(latitude * 4) / 4,
      grid_longitude = round(longitude * 4) / 4)
}

# Aggregate GPS observations to a single grid point per period.
.aggregate_gps <- function(gps, period, neighbours = 1) {
  
  stopifnot(length(neighbours) == 1, is.finite(neighbours),
            neighbours >= 0, neighbours == as.integer(neighbours))
  
  cells <- gps |>
    dplyr::count(userId, dplyr::across(dplyr::all_of(period)),
                 grid_latitude, grid_longitude, name = "cell_n")
  
  reference <- cells |>
    dplyr::group_by(userId, dplyr::across(dplyr::all_of(period))) |>
    dplyr::arrange(dplyr::desc(cell_n), .by_group = TRUE) |>
    dplyr::summarise(
      grid_latitude = dplyr::first(grid_latitude),
      grid_longitude = dplyr::first(grid_longitude),
      grid_gps_n = dplyr::first(cell_n),
      cells_n = dplyr::n(),
      tied = sum(cell_n == max(cell_n)) > 1,
      max_offset = max(pmax(abs(grid_latitude - dplyr::first(grid_latitude)),
                            abs(grid_longitude - dplyr::first(grid_longitude)))) / 0.25,
      .groups = "drop")
  
  gps |>
    dplyr::group_by(userId, dplyr::across(dplyr::all_of(period))) |>
    dplyr::summarise(
      gps_n = dplyr::n(),
      hours_n = dplyr::n_distinct(lubridate::floor_date(minute_ts, "hour")),
      first_ts = min(minute_ts),
      last_ts = max(minute_ts),
      .groups = "drop") |>
    dplyr::left_join(reference, by = c("userId", period)) |>
    dplyr::mutate(
      assigned = !tied & max_offset <= neighbours,
      grid_latitude = dplyr::if_else(assigned, grid_latitude, NA_real_),
      grid_longitude = dplyr::if_else(assigned, grid_longitude, NA_real_)) |>
    dplyr::select(userId, dplyr::all_of(period), grid_latitude, grid_longitude,
                  gps_n, grid_gps_n, hours_n, cells_n,
                  first_ts, last_ts, max_offset, assigned)
}

# Read GPS at five-minute resolution.
read_gps_5min <- function(neighbours = 0, accuracy_min = 1, accuracy_max = 200) {
  read_gps_tidy(accuracy_min, accuracy_max) |>
    dplyr::mutate(bucket_5min = lubridate::floor_date(minute_ts, "5 minutes")) |>
    .aggregate_gps("bucket_5min", neighbours = neighbours)
}

# Read GPS at hourly resolution.
read_gps_hourly <- function(neighbours = 1, accuracy_min = 1, accuracy_max = 200) {
  read_gps_tidy(accuracy_min, accuracy_max) |>
    dplyr::mutate(hour_ts = lubridate::floor_date(minute_ts, "hour")) |>
    .aggregate_gps("hour_ts", neighbours = neighbours)
}

# Read GPS at daily resolution.
read_gps_daily <- function(neighbours = 1, accuracy_min = 1, accuracy_max = 200) {
  read_gps_tidy(accuracy_min, accuracy_max) |>
    .aggregate_gps("date", neighbours = neighbours)
}
