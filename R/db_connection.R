#' Start an SSH tunnel to the MariaDB Trigger server (bio4)
#'
#' This function opens an SSH tunnel from the local machine to the
#' **MariaDB Trigger** server running on `bio4`, allowing RStudio to
#' access the remote database securely via a local TCP port.
#'
#' The tunnel forwards the local port `3336` to the remote
#' MariaDB service on `127.0.0.1:3306` inside `bio4`.  
#' Once the tunnel is active, the database can be reached from R using:
#'
#' \preformatted{
#' host = "127.0.0.1"
#' port = 3336
#' }
#'
#' This method relies on the SSH configuration in `~/.ssh/config`, where
#' the host `bio4` must already define the ProxyJump and authentication
#' details required for the connection.
#'
#' The tunnel is launched in the background (`ssh -N -f`) using the
#' `processx` package and remains active until manually terminated.
#'
#' @return A \code{processx::process} object representing the SSH tunnel.
#'         You can stop the tunnel with:
#'         \code{tunnel$kill()}.
#'
#' @examples
#' \dontrun{
#'   # Start SSH tunnel
#'   tunnel <- start_ssh_tunnel()
#'
#'   # Connect to MariaDB using your custom helper function
#'   con <- connect_trigger_db()
#'
#'   # Close tunnel when done
#'   tunnel$kill()
#' }
#'
#' @seealso \code{\link{connect_trigger_db}} for the database connection helper.
#'
#' @export
start_ssh_tunnel <- function() {
  if (!requireNamespace("processx", quietly = TRUE))
    stop("Install 'processx' first.")
  
  tunnel <- processx::process$new(
    "ssh",
    c(
      "-N",                   # no remote command
      "-f",                   # run in background
      "-L", "3336:127.0.0.1:3306",   # local port : remote MariaDB
      "bio4"                  # uses ~/.ssh/config automatically
    ),
    supervise = TRUE
  )
  
  message("SSH tunnel started on localhost:3336")
  return(tunnel)
}

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
#' The function loads the required packages internally and returns an active
#' \code{DBIConnection} object.
#'
#' @param host Database host. Defaults to `"127.0.0.1"`.
#' @param port Database port. Defaults to `3336`.
#' @param user Database user. Defaults to `"triggerIO"`.
#' @param password Database password. Defaults to `"triggerIO"`.
#' @param dbname Database name. Defaults to `"triggerIO"`.
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
connect_trigger_db <- function(host = "127.0.0.1",
                               port = 3336L,
                               user = "triggerIO",
                               password = "triggerIO",
                               dbname = "triggerIO") {
  
  # Load required packages without attaching them
  if (!requireNamespace("DBI", quietly = TRUE))
    stop("Package 'DBI' is not installed.")
  if (!requireNamespace("RMariaDB", quietly = TRUE))
    stop("Package 'RMariaDB' is not installed.")
  
  DBI::dbConnect(
    RMariaDB::MariaDB(),
    host     = host,
    port     = port,
    user     = user,
    password = password,
    dbname   = dbname
  )
}


#' Run a SQL query directly on the triggerIO database
#'
#' This helper opens a connection using the default TriggerIO parameters,
#' runs the supplied query, returns the result as a tibble, and closes the
#' connection automatically.
#'
#' @param query A single SQL query string.
#' @param host Database host. Defaults to `"127.0.0.1"`.
#' @param port Database port. Defaults to `3336`.
#' @param user Database user. Defaults to `"triggerIO"`.
#' @param password Database password. Defaults to `"triggerIO"`.
#' @param dbname Database name. Defaults to `"triggerIO"`.
#'
#' @return A tibble.
#' @export
query_trigger_db <- function(query,
                             host = "127.0.0.1",
                             port = 3336L,
                             user = "triggerIO",
                             password = "triggerIO",
                             dbname = "triggerIO") {
  stopifnot(is.character(query), length(query) == 1, !is.na(query))

  con <- connect_trigger_db(
    host = host,
    port = port,
    user = user,
    password = password,
    dbname = dbname
  )
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  tibble::as_tibble(DBI::dbGetQuery(con, query))
}
