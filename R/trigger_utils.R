#' Connect to the triggerIO MariaDB database through SSH tunnel
#'
#' This function establishes a connection from RStudio (running on your local
#' computer) to the MariaDB database hosted on the remote server `bio4`.
#'
#' ## SSH configuration required
#'
#' Your `~/.ssh/config` must contain entries for both the bastion host and the
#' final server `bio4`, including the automatic port forwarding used by RStudio
#' to access the database:
#'
#' \preformatted{
#' Host bastion-bio
#'     HostName 137.204.51.130
#'     User alessandro.fuschi2
#'
#' Host bio4
#'     HostName 137.204.51.134
#'     User alessandro.fuschi2
#'     ProxyJump bastion-bio
#'     ServerAliveInterval 240
#'     LocalForward 3336 127.0.0.1:3306
#' }
#'
#' With this configuration, running the command:
#' \preformatted{
#' ssh bio4
#' }
#' will automatically:
#' \itemize{
#'   \item connect through the bastion host,
#'   \item open a local port `3336` on *your* computer,
#'   \item forward that port to MariaDB running on `bio4:3306`.
#' }
#'
#' ## Requirements before calling this function
#'
#' \itemize{
#'   \item You have an active SSH connection created with `ssh bio4`.
#'   \item The SSH session must remain open while RStudio is running,
#'         because it provides the database tunnel.
#'   \item MariaDB is reachable at `127.0.0.1:3336` from your local machine.
#' }
#'
#' ## Connection parameters
#'
#' These are directly set inside the function (no hidden envs):
#' \itemize{
#'   \item host = "127.0.0.1"
#'   \item port = 3336
#'   \item db   = "triggerIO"
#'   \item user = "triggerIO"
#'   \item pwd  = "triggerIO"
#' }
#'
#' The function loads the required packages internally and returns an active
#' \code{DBIConnection} object.
#'
#' @return A \code{DBIConnection} object pointing to the remote triggerIO
#'         MariaDB instance.
#'
#' @examples
#' \dontrun{
#'   # Start SSH tunnel in a terminal:
#'   #   ssh bio4
#'
#'   con <- connect_trigger_db()
#'   DBI::dbListTables(con)
#' }
#'
#' @export
connect_trigger_db <- function() {
  
  # Load required packages without attaching them
  if (!requireNamespace("DBI", quietly = TRUE))
    stop("Package 'DBI' is not installed.")
  if (!requireNamespace("RMariaDB", quietly = TRUE))
    stop("Package 'RMariaDB' is not installed.")
  
  DBI::dbConnect(
    RMariaDB::MariaDB(),
    host     = "127.0.0.1",
    port     = 3336L,
    user     = "triggerIO",
    password = "triggerIO",
    dbname   = "triggerIO"
  )
}

