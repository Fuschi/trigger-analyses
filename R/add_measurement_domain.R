add_measurement_domain <- function(data) {
  data |>
    dplyr::mutate(
      domain = dplyr::case_when(
        measurement %in% ENVIRONMENTAL_VARIABLES ~ "environmental",
        measurement %in% PHYSIOLOGICAL_VARIABLES ~ "physiological",
        TRUE ~ NA_character_
      )
    )
}