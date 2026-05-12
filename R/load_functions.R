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

load_trigger_functions <- function(path = "../../R") {
  
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
  
  files <- sort(files)
  
  # Avoid sourcing this loader file again
  files <- files[!basename(files) %in% c(
    "load_functions.R"
    #"prepare_hourly_wide_table.R"
  )]
  
  priority_files <- c(
    file.path(path, "constants.R"),
    file.path(path, "db_connection.R"),
    file.path(path, "db_procedures.R"),
    file.path(path, "read_trigger_tables.R"),
    file.path(path, "prepare_hourly_wide_table.R")
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
