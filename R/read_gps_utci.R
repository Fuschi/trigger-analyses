# ---------------------------------------------------------------------------
# GPS–UTCI integration and coverage summary
# ---------------------------------------------------------------------------
# Join aggregated GPS positions to UTCI series at the same Copernicus grid
# point and UTC hour or day. Keep all GPS periods, including unassigned ones.
# Geographic city labels (if available) come from read_gps.R, not UTCI data.
# ---------------------------------------------------------------------------

# Associate GPS periods with UTCI at hourly or daily resolution.
read_gps_utci <- function(resolution = c("hourly", "daily"), neighbours = 1,
                          accuracy_min = 1, accuracy_max = 200, data_dir = "data") {
  resolution <- match.arg(resolution)
  
  if (resolution == "hourly") {
    gps <- read_gps_hourly(neighbours = neighbours, accuracy_min = accuracy_min, accuracy_max = accuracy_max)
    utci <- read_utci_hourly(data_dir = data_dir)
    gps |>
      dplyr::left_join(utci, by = c("grid_latitude", "grid_longitude", "hour_ts")) |>
      dplyr::mutate(utci_available = assigned & !is.na(utci))
  } else {
    gps <- read_gps_daily(neighbours = neighbours, accuracy_min = accuracy_min, accuracy_max = accuracy_max)
    utci <- read_utci_daily(data_dir = data_dir)
    gps |>
      dplyr::left_join(utci, by = c("grid_latitude", "grid_longitude", "date")) |>
      dplyr::mutate(utci_available = assigned & !is.na(utci_mean))
  }
}

# Summarise GPS assignment and UTCI availability by participant.
summarise_gps_utci <- function(x) {
  x |>
    dplyr::group_by(userId) |>
    dplyr::summarise(
      periods_n = dplyr::n(),
      gps_assigned_n = sum(assigned, na.rm = TRUE),
      utci_available_n = sum(utci_available, na.rm = TRUE),
      gps_assigned_pct = 100 * gps_assigned_n / periods_n,
      utci_available_pct = 100 * utci_available_n / periods_n,
      .groups = "drop") |>
    dplyr::arrange(dplyr::desc(utci_available_n))
}