# ---------------------------------------------------------
# load_trigger_functions
#
# Load all R files contained in the "R" directory of the
# project and place the defined objects (typically functions)
# inside a dedicated environment.
#
# This avoids polluting the global environment and allows
# accessing all functions through a single object.
#
# Returns an environment containing all loaded functions.
# ---------------------------------------------------------

load_trigger_functions <- function(path = here::here("R")) {
  
  # Create a new environment where functions will be loaded.
  # The parent is baseenv() so base R functions (mean, list, etc.)
  # are still available inside the environment.
  env <- new.env(parent = baseenv())
  
  # Find all R scripts inside the specified directory
  files <- list.files(
    path = path,
    pattern = "\\.[Rr]$",
    full.names = TRUE
  )
  
  # Sort files to ensure deterministic loading order and load
  # lower-level database helpers before higher-level readers.
  files <- sort(files)

  priority_files <- c(
    file.path(path, "db_connection.R"),
    file.path(path, "db_procedures.R"),
    file.path(path, "read_trigger_tables.R")
  )

  priority_files <- priority_files[priority_files %in% files]
  files <- c(priority_files, setdiff(files, priority_files))
  
  # Source each file into the environment
  for (file in files) {
    source(file, local = env)
  }
  
  # Return the environment containing all loaded functions
  env
}
