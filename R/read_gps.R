
# ---------------------------------------------------------------------------
# GPS data reading and Copernicus grid assignment
# ---------------------------------------------------------------------------
#
# Read GPS observations at tidy, 5-minute, hourly and daily resolutions
# and associate their coordinates with the Copernicus ERA5-HEAT grid.
#
# Grid assignment:
#   - The grid spacing is 0.25 x 0.25 degrees.
#   - GPS coordinates are rounded to the nearest grid point.
#   - Tidy observations are assigned individually.
#   - Aggregated periods use the most frequently observed grid point.
#   - All observed points must fall within the specified neighbourhood.
#   - Ties between the most frequent grid points remain unassigned.
#
# Neighbourhood tolerance:
#   - neighbours = 0: reference grid point only.
#   - neighbours = 1: reference point and its eight adjacent points.
#   - neighbours = 2: up to two grid steps in each direction.
#
# Data quality:
#   - Valid geographic coordinates are required.
#   - GPS accuracy is restricted to 1–200 m by default.
#   - Accuracy limits can be modified through function arguments.
#   - Participant IDs are stored as character.
#   - Calendar dates are derived from minute_ts in UTC.
#
# Coverage indicators:
#   - gps_n: total GPS observations in the period.
#   - grid_gps_n: observations at the reference grid point.
#   - hours_n: distinct hours containing GPS observations.
#   - cells_n: distinct grid points observed.
#   - first_ts / last_ts: first and last GPS observations.
#   - max_offset: maximum distance from the reference in grid steps.
#   - assigned: whether the geographic assignment is valid.
#
# Unassigned periods are retained with missing grid coordinates.
# Assignments do not imply continuous presence at a location.
#
# Exploratory analysis: analyses/gps-exploration.qmd
# ---------------------------------------------------------------------------


# Read GPS observations and assign grid coordinates.
read_gps_tidy <- function(accuracy_min = 1, accuracy_max = 200) {
  stopifnot(length(accuracy_min) == 1, length(accuracy_max) == 1,
            is.finite(accuracy_min), is.finite(accuracy_max),
            accuracy_min <= accuracy_max)
  
  readr::read_csv("data/tidy/gps_tidy.csv.gz",
                  col_select = c(userId, minute_ts, latitude, longitude, accuracy),
                  locale = readr::locale(tz = "UTC"), show_col_types = FALSE) |>
    dplyr::filter(!is.na(userId), !is.na(minute_ts),
                  dplyr::between(accuracy, accuracy_min, accuracy_max),
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
    dplyr::arrange(dplyr::desc(cell_n), grid_latitude, grid_longitude, .by_group = TRUE) |>
    dplyr::mutate(
      ref_lat = dplyr::first(grid_latitude),
      ref_lon = dplyr::first(grid_longitude),
      cell_offset = pmax(abs(grid_latitude - ref_lat),
                         abs(grid_longitude - ref_lon)) / 0.25) |>
    dplyr::summarise(
      ref_lat = dplyr::first(ref_lat),
      ref_lon = dplyr::first(ref_lon),
      grid_gps_n = dplyr::first(cell_n),
      cells_n = dplyr::n(),
      tied = sum(cell_n == max(cell_n)) > 1,
      max_offset = max(cell_offset),
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
      grid_latitude = dplyr::if_else(assigned, ref_lat, NA_real_),
      grid_longitude = dplyr::if_else(assigned, ref_lon, NA_real_)) |>
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
