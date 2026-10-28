# Transform wide-format sensor means for exploratory analysis.
#
# Choices:
# - Apply log1p to PM/PC, light and steps to compress right-skewed tails.
# - Replace nine PM/PC measurements with two standardized PCA components.
#   Two components explained 94.2% of variance in the five-minute analysis.
# - Remove calories because of their strong correlation with steps.
# - Keep other measurements, identifiers and timestamps unchanged.
# - Do not center by participant or standardize non-PCA variables.
#
# PCA uses complete, finite PM/PC rows; incomplete rows retain NA scores.
# PC1 is oriented towards increasing particle levels when fitting a new PCA.
# Supply an existing PCA to reuse its centering, scaling and loadings.
#
# Input: original, untransformed means with names such as "pm25" and "step".
# Not intended for long data or tables containing min/max summaries.
# Output: list(data = transformed table, pca = fitted/reused model).
#
# Examples:
#   result <- transform_means(trigger_5min_wide)
#   transformed <- result$data
#   new_result <- transform_means(new_data, pca = result$pca)

transform_means <- function(data, pca = NULL) {
  particles <- c(
    "pm1", "pm25", "pm10",
    "pc03", "pc05", "pc1", "pc25", "pc5", "pc10"
  )
  log_variables <- c(particles, "light", "step")
  score_names <- c("particle_PC1", "particle_PC2")
  
  missing_columns <- setdiff(log_variables, names(data))
  if (length(missing_columns)) {
    stop("Missing columns: ", paste(missing_columns, collapse = ", "),
         call. = FALSE)
  }
  
  if (any(grepl("_(min|max|mean)$", names(data)))) {
    stop("Use means-only wide data with unsuffixed measurement names.",
         call. = FALSE)
  }
  
  if (any(score_names %in% names(data))) {
    stop("PCA scores already present. Supply original data.", call. = FALSE)
  }
  
  if (!all(purrr::map_lgl(data[log_variables], is.numeric))) {
    stop("Variables selected for transformation must be numeric.",
         call. = FALSE)
  }
  
  if (any(purrr::map_lgl(
    data[log_variables], \(x) any(x < 0, na.rm = TRUE)
  ))) {
    stop("Negative values found in variables selected for log1p.",
         call. = FALSE)
  }
  
  # Preserve missingness and treat non-finite measurements as unavailable.
  transformed <- data |>
    dplyr::mutate(dplyr::across(
      tidyselect::all_of(log_variables),
      ~ log1p(replace(.x, !is.finite(.x), NA_real_))
    ))
  
  x <- transformed |>
    dplyr::select(tidyselect::all_of(particles)) |>
    as.matrix()
  
  complete <- stats::complete.cases(x)
  
  if (is.null(pca)) {
    if (sum(complete) < 3L) {
      stop("At least three complete PM/PC rows are required.",
           call. = FALSE)
    }
    
    if (any(apply(x[complete, , drop = FALSE], 2, stats::sd) == 0)) {
      stop("PCA cannot standardize constant PM/PC variables.",
           call. = FALSE)
    }
    
    pca <- stats::prcomp(
      x[complete, , drop = FALSE],
      center = TRUE, scale. = TRUE, retx = FALSE
    )
    
    if (sum(pca$rotation[, 1]) < 0) {
      pca$rotation[, 1] <- -pca$rotation[, 1]
    }
  } else {
    if (!inherits(pca, "prcomp") ||
        !setequal(rownames(pca$rotation), particles) ||
        ncol(pca$rotation) < 2L) {
      stop("Supply a prcomp model fitted on the nine log1p PM/PC variables.",
           call. = FALSE)
    }
  }
  
  scores <- matrix(
    NA_real_, nrow = nrow(data), ncol = 2,
    dimnames = list(NULL, score_names)
  )
  
  if (any(complete)) {
    scores[complete, ] <- stats::predict(
      pca, newdata = x[complete, , drop = FALSE]
    )[, 1:2, drop = FALSE]
  }
  
  transformed <- transformed |>
    dplyr::select(-tidyselect::any_of(c(particles, "cal"))) |>
    dplyr::bind_cols(tibble::as_tibble(scores))
  
  list(data = transformed, pca = pca)
}