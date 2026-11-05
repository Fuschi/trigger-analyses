# ---------------------------------------------------------------------------
# Participant metadata
# ---------------------------------------------------------------------------

# Combine participant demographics supplied by the three study sites with
# active_accounts. Keep all active accounts and use NA for missing metadata.
# Ages are numeric for Geneva/Augsburg and categorical for Bologna.
# Match by the eight-character study participant code (e.g. DE000123),
# never by a potentially masked suffix. Abort on ambiguous codes.
#
# Files (local, not intended for public Git tracking):
#   data/shared/participants/genre age participants.xlsx
#   data/shared/participants/prelim_data_longcl_augsburg.xlsx
#   data/shared/participants/tab_ID_GEN_AGE.xlsx
#
# Example:
#   source("R/read_data.R")
#   source("R/read_participant_metadata.R")
#   participants <- read_participant_metadata()

read_participant_metadata <- function(data_dir = "data", participant_dir = file.path(data_dir, "shared", "participants")) {
  if (!exists("read_trigger_accounts", mode = "function"))
    stop("Source R/read_data.R before reading participant metadata.", call. = FALSE)

  participant_code <- function(x) stringr::str_extract(stringr::str_to_upper(stringr::str_trim(as.character(x))), "^[A-Z]{2}[0-9]{6}")

  geneva <- readxl::read_excel(file.path(participant_dir, "genre age participants.xlsx"), sheet = "Feuil1") |>
    dplyr::transmute(participant_code = participant_code(`User ID App`), gender = stringr::str_to_upper(as.character(Genre)),
                     age = as.numeric(Age), age_group = NA_character_, metadata_source = "Geneva")

  augsburg <- readxl::read_excel(file.path(participant_dir, "prelim_data_longcl_augsburg.xlsx"), sheet = "Tabelle1") |>
    dplyr::transmute(participant_code = participant_code(id), gender = stringr::str_to_upper(as.character(`sex/gender`)),
                     age = as.numeric(`age at inclusion`), age_group = NA_character_, metadata_source = "Augsburg")

  bologna <- readxl::read_excel(file.path(participant_dir, "tab_ID_GEN_AGE.xlsx"), sheet = "Bologna") |>
    dplyr::transmute(participant_code = participant_code(ID), gender = dplyr::case_when(gender == 1 ~ "M", gender == 2 ~ "F"),
                     age = NA_real_, age_group = dplyr::if_else(age_cat %in% 1:7,
                       paste0(age_cat * 10, "-", age_cat * 10 + 9), NA_character_), metadata_source = "Bologna")

  metadata <- dplyr::bind_rows(geneva, augsburg, bologna) |>
    dplyr::mutate(age_group = dplyr::if_else(!is.na(age), paste0(floor(age / 10) * 10, "-", floor(age / 10) * 10 + 9), age_group))

  if (anyNA(metadata$participant_code) || anyDuplicated(metadata$participant_code))
    stop("Missing or duplicated participant codes in the metadata files.", call. = FALSE)
  if (any(!is.na(metadata$gender) & !metadata$gender %in% c("M", "F")))
    stop("Unrecognized gender code in the metadata files.", call. = FALSE)

  accounts <- read_trigger_accounts(data_dir = data_dir)
  if (!"email" %in% names(accounts)) stop("active_accounts must contain an email column.", call. = FALSE)
  accounts <- dplyr::mutate(accounts, participant_code = participant_code(email))
  if (anyDuplicated(stats::na.omit(accounts$participant_code)))
    stop("Ambiguous participant codes in active_accounts.", call. = FALSE)
  collisions <- intersect(setdiff(names(metadata), "participant_code"), names(accounts))
  if (length(collisions)) stop("Columns already exist in active_accounts: ", paste(collisions, collapse = ", "), call. = FALSE)

  accounts |>
    dplyr::left_join(metadata, by = "participant_code", relationship = "one-to-one") |>
    dplyr::select(-participant_code)
}
