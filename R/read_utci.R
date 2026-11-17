# ---------------------------------------------------------------------------
# UTCI data reading and aggregation
# ---------------------------------------------------------------------------
# Read all hourly UTCI CSV files from data/shared/utci, including original
# city-named files and new grid-point files. Coordinates identify Copernicus
# grid points; timestamps are UTC and UTCI is converted from Kelvin to Celsius.
# Duplicate grid point/hour records are removed, preferring coordinate-named
# files when both sources contain the same observation.
# ---------------------------------------------------------------------------

# Read hourly UTCI for all downloaded Copernicus grid points.
read_utci_hourly <- function(data_dir = "data") {
  dir <- file.path(data_dir, "shared", "utci")
  paths <- list.files(dir, pattern = "^UTCI-.*\\.csv$", full.names = TRUE)
  if (!length(paths)) stop("No UTCI CSV files found in: ", dir, call. = FALSE)
  
  # Coordinate-named files have priority over legacy city-named files.
  paths <- paths[order(grepl("^UTCI-[A-Za-z]", basename(paths)))]
  
  purrr::map(paths, \(path) {
    x <- readr::read_csv(path,
                         col_types = readr::cols(valid_time = readr::col_datetime(), utci = readr::col_double(),
                                                 latitude = readr::col_double(), longitude = readr::col_double()),
                         locale = readr::locale(tz = "UTC"), show_col_types = FALSE, progress = FALSE)
    readr::stop_for_problems(x)
    dplyr::transmute(x, grid_latitude = latitude, grid_longitude = longitude,
                     hour_ts = valid_time, utci = utci - 273.15)
  }) |>
    dplyr::bind_rows() |>
    dplyr::distinct(grid_latitude, grid_longitude, hour_ts, .keep_all = TRUE) |>
    dplyr::arrange(grid_latitude, grid_longitude, hour_ts)
}

# Aggregate UTCI by Copernicus grid point and UTC calendar day.
read_utci_daily <- function(data_dir = "data") {
  read_utci_hourly(data_dir) |>
    dplyr::mutate(date = as.Date(hour_ts, tz = "UTC")) |>
    dplyr::group_by(grid_latitude, grid_longitude, date) |>
    dplyr::summarise(
      utci_hours_n = sum(!is.na(utci)),
      utci_min = if (all(is.na(utci))) NA_real_ else min(utci, na.rm = TRUE),
      utci_mean = if (all(is.na(utci))) NA_real_ else mean(utci, na.rm = TRUE),
      utci_median = if (all(is.na(utci))) NA_real_ else median(utci, na.rm = TRUE),
      utci_max = if (all(is.na(utci))) NA_real_ else max(utci, na.rm = TRUE),
      .groups = "drop")
}
