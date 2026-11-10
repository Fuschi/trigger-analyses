# ---------------------------------------------------------------------------
# UTCI data
# ---------------------------------------------------------------------------

# Read hourly UTCI data for the four TRIGGER study cities.
# UTCI coordinates refer to the ERA5 grid points associated with each study city,
# not to participant GPS locations. Timestamps are interpreted as UTC.
# Convert original UTCI values from Kelvin to Celsius.
#
# Examples:
#   utci_hourly <- read_utci_hourly()
#   utci_bologna <- read_utci_hourly(cities = "Bologna")

read_utci_hourly <- function(data_dir = "data", cities = c("Augsburg", "Bologna", "Geneva", "Heraklion")) {
  paths <- file.path(data_dir, "shared", "utci", paste0("UTCI-", cities, ".csv"))
  missing <- paths[!file.exists(paths)]
  if (length(missing)) stop("Missing UTCI files: ", paste(missing, collapse = ", "), call. = FALSE)
  
  purrr::map2(paths, cities, \(path, city) {
    x <- readr::read_csv(path, col_types = readr::cols(valid_time = readr::col_datetime(), utci = readr::col_double(),
                                                       latitude = readr::col_double(), longitude = readr::col_double()), locale = readr::locale(tz = "UTC"),
                         show_col_types = FALSE, progress = FALSE)
    readr::stop_for_problems(x)
    dplyr::transmute(x, city = city, hour_ts = valid_time, utci = utci - 273.15,
                     utci_latitude = latitude, utci_longitude = longitude)
  }) |>
    dplyr::bind_rows() |>
    dplyr::arrange(city, hour_ts)
}

# Aggregate hourly UTCI to calendar days (UTC), separately for each study city.
# Site coordinates identify UTCI reference grid points, not participant GPS locations.
#
# Examples:
#   utci_daily <- read_utci_daily()
#   utci_bologna_daily <- read_utci_daily(cities = "Bologna")

read_utci_daily <- function(data_dir = "data", cities = c("Augsburg", "Bologna", "Geneva", "Heraklion")) {
  read_utci_hourly(data_dir = data_dir, cities = cities) |>
    dplyr::mutate(date = as.Date(hour_ts, tz = "UTC")) |>
    dplyr::group_by(city, date, utci_latitude, utci_longitude) |>
    dplyr::summarise(utci_min = min(utci), utci_mean = mean(utci), utci_median = median(utci),
                     utci_max = max(utci), .groups = "drop")
}