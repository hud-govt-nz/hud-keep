#' Store
#'
#' Stores a local file in the blob.
#' @name store
#' @param local_fn Local filename
#' @param blob_fn Blob filename (including path)
#' @param container_url Azure container URL (e.g. "https://dlprojectsdataprod.blob.core.windows.net/bot-outputs")
#' @param forced Overwrite blob version
#' @export
store <- function(local_fn, blob_fn, container_url, forced = FALSE) {
    message("Storing ", local_fn, " as ", blob_fn, " ...")
    cont <- get_container(container_url)
    if (AzureStor::blob_exists(cont, blob_fn) & !forced) {
        l_props <- local_props(local_fn)
        b_props <- blob_props(blob_fn, cont)
        if (b_props$md5_hash == l_props$md5_hash) {
            message("File is already stored and the blob hash matches the local file.")
        }
        else {
            stop("Local file (", l_props$size, " bytes, ",
                 "last modified ", l_props$mtime, ") doesn't match ",
                 "blob file (", b_props$size, " bytes, ",
                 "last modified ", b_props$mtime, ")! ",
                 "\nUse 'forced=TRUE' to overwrite."
            )
        }
    }
    else {
        AzureStor::upload_blob(cont, local_fn, blob_fn, put_md5 = TRUE)
        return(local_fn)
    }
}

#' Retrive
#'
#' Retrives a file from the blob and save it locally.
#' @name retrieve
#' @param blob_fn Blob filename (including path)
#' @param local_fn Local filename
#' @param container_url Azure container URL (e.g. "https://dlprojectsdataprod.blob.core.windows.net/bot-outputs")
#' @param forced Overwrite local version
#' @export
retrieve <- function(blob_fn, local_fn, container_url, forced = FALSE) {
    message("Retrieving ", local_fn, " from ", blob_fn, " ...")
    cont <- get_container(container_url)
    if (file.exists(local_fn) & !forced) {
        l_props <- local_props(local_fn)
        b_props <- blob_props(blob_fn, cont)
        if (is.null(b_props$md5_hash)) {
            message("Blob does not have a hash, no check possible.")
            AzureStor::download_blob(cont, blob_fn, local_fn, overwrite = TRUE)
        }
        else if (b_props$md5_hash == l_props$md5_hash) {
            message("Local file already exists and matches the blob hash.")
        }
        else {
            stop("Local file (", l_props$size, " bytes, ",
                 "last modified ", l_props$mtime, ") doesn't match ",
                 "blob file (", b_props$size, " bytes, ",
                 "last modified ", b_props$mtime, ")! ",
                 "\nUse 'forced=TRUE' to overwrite."
            )
        }
    }
    else {
        AzureStor::download_blob(cont, blob_fn, local_fn, overwrite = TRUE)
        return(local_fn)
    }
}

#' Read blob file using custom function
#'
#' Read a file from the blob using custom function
#' @name read_blob_using
#' @param blob_fn Blob filename (including path)
#' @param container_url Azure container URL (e.g. "https://dlprojectsdataprod.blob.core.windows.net/bot-outputs")
#' @param f Custom function
#' @export
read_blob_using <- function(blob_fn, container_url, f, ...) {
    local_fn <- paste0("temp_", stringr::str_replace_all(blob_fn, "/", "_"))
    retrieve(blob_fn, local_fn, container_url)
    out <- f(local_fn, ...)
    file.remove(local_fn)
    out
}

#' Read blob data file
#'
#' Read a CSV/Excel file from the blob
#' @name read_blob
#' @param blob_fn Blob filename (including path)
#' @param container_url Azure container URL (e.g. "https://dlprojectsdataprod.blob.core.windows.net/bot-outputs")
#' @export
read_blob_data <- function(blob_fn, container_url, ...) {
    extension <- stringr::str_extract(blob_fn, "\\.\\w+$") %>% tolower()
    if (extension == ".csv") {
        f <- read.csv
    }
    else if (extension == ".xls" || extension == ".xlsx") {
        f <- readxl::read_excel
    }
    else if (extension == ".rds") {
        f <- read_rds
    }
    else {
        stop("I don't know how to read '", extension, "' files!")
    }
    read_blob_using(blob_fn, container_url, f, ...)
}

#' DEPRECATED - Read blob data file
#'
#' DEPRECATED - Read a CSV/Excel file from the blob
#' @name read_blob
#' @param blob_fn Blob filename (including path)
#' @param container_url Azure container URL (e.g. "https://dlprojectsdataprod.blob.core.windows.net/bot-outputs")
#' @param sheet Sheet name for Excel
#' @export
read_blob <- function(blob_fn, container_url, sheet = NULL, ...) {
    warning("DEPRECATED - use read_blob_data() instead.")
    extension <- stringr::str_extract(blob_fn, "\\.\\w+$") %>% tolower()
    if (extension == ".csv") {
        read_blob_using(blob_fn, container_url, read.csv, ...)
    }
    else if (extension == ".xls" || extension == ".xlsx") {
        read_blob_using(blob_fn, container_url, readxl::read_excel, sheet = sheet, ...)
    }
    else if (extension == ".rds") {
        read_blob_using(blob_fn, container_url, read_rds, ...)
    }
    else {
        stop("I don't know how to read '", extension, "' files!")
    }
}

#' List stored
#'
#' List all the files stored in the blob.
#' @name list_stored
#' @param blob_starts_with Path or prefix to look for
#' @param container_url Azure container URL (e.g. "https://dlprojectsdataprod.blob.core.windows.net/bot-outputs")
#' @export
list_stored <- function(blob_starts_with, container_url) {
    cont <- get_container(container_url)
    AzureStor::list_blobs(cont, prefix = blob_starts_with)
}

#' Find latest
#'
#' Finds the latest version of a file stored on the blob. The last file,
#' sorted by full blob name, is considered the latest.
#'
#' e.g.:
#'
#'   "hmu-bot/hmu-bot-20230115/Construction/ea-icp-grab.csv"
#'   "hmu-bot/hmu-bot-20230117/Construction/ea-icp-grab.csv"
#'   "hmu-bot/hmu-bot-20230120/Construction/ea-icp-grab.csv" <- Latest
#'
#' @name find_latest
#' @param blob_pattern Pattern to match for (e.g. "ea-icp-grab.csv")
#' @param container_url Azure container URL (e.g. "https://dlprojectsdataprod.blob.core.windows.net/bot-outputs")
#' @param prefix_filter Prefix to filter result (e.g. "hmu-bot/hmu-bot-")
#' @export
find_latest <- function(blob_pattern, container_url, prefix_filter = NULL) {
    cont <- get_container(container_url)
    files <- AzureStor::list_blobs(cont, prefix = prefix_filter, info = "name") # Using a prefix_filter will speed things up
    matches <- files[grepl(blob_pattern, files)]
    if (length(matches) == 0) stop("No matches for '", blob_pattern, "' in '", container_url, "/", prefix_filter, "'!")
    latest <- tail(sort(matches), 1)
    latest
}


#' Connect to a HUD database
#'
#' Handles all the Active Directory authentication and connects to database.
#' @name db_connect
#' @param database
#' @param server
#' @param driver
#' @export
db_connect <- function(database,
                       server = "property.database.windows.net",
                       driver = "{ODBC Driver 18 for SQL Server}") {

    # Use "device_code" on the cloud because we can't hook up to a browser
    if (grepl("azure", Sys.info()["release"])) {
        auth_type <- "device_code"
    } else {
        auth_type <- NULL
    }

    token <-
        AzureAuth::get_azure_token(
            resource = "https://database.windows.net",
            tenant = "9e9b3020-3d38-48a6-9064-373bc7b156dc", # "hud.govt.nz" tenancy
            app = "04b07795-8ddb-461a-bbee-02f9e1bf7b46", # "Offline Access" app
            auth_type = auth_type)

    message("Connecting to '", database, "' on '", server ,"'...")
    DBI::dbConnect(
        odbc::odbc(),
        Database = database,
        Server = server,
        Driver = driver,
        attributes = list("azure_token" = token$credentials$access_token))
}


#===============#
#   Utilities   #
#===============#
hex2base64 <- function(hex_str) {
    hex <- sapply(seq(1, nchar(hex_str), by = 2),
                  function(x) substr(hex_str, x, x + 1))
    raw <- as.raw(strtoi(hex, 16L))
    base64enc::base64encode(raw)
}

local_props <- function (fn) {
    if (file.exists(fn) == FALSE) {
        stop(paste0(fn, " not found!"))
    }
    props <- file.info(fn)
    list(md5_hash = hex2base64(tools::md5sum(fn)),
         size = props["size"][[1]],
         mtime = lubridate::as_datetime(props["mtime"][[1]]))
}

blob_props <- function(blob_fn, cont) {
    props <- AzureStor::get_storage_properties(cont, blob_fn)
    list(md5_hash = props["content-md5"][[1]],
         size = props["content-length"][[1]],
         mtime = lubridate::dmy_hms(props["last-modified"][[1]]))
}

get_container <- function(container_url) {
    matches <- stringr::str_match_all(container_url, "(https://.*)/([^\\?]+)\\??(.+)?")[[1]]
    resource <- matches[2]
    container <- matches[3]
    sas <- matches[4]
    # URL with access token included
    if (is.na(sas) == FALSE) {
        stop("Use of SAS keys not permitted! Use a plain URL and your AD id will be automatically used.")
        # endp_key <- AzureStor::storage_endpoint(resource, sas = sas)
    }

    # Use "device_code" on the cloud because we can't hook up to a browser
    if (grepl("azure", Sys.info()["release"])) {
        auth_type <- "device_code"
    } else {
        auth_type <- NULL
    }

    token <-
        AzureAuth::get_azure_token(
            resource = "https://storage.azure.com",
            tenant = "9e9b3020-3d38-48a6-9064-373bc7b156dc", # "hud.govt.nz" tenancy
            app = "c6c4300b-9ff3-4946-8f30-e0aa59bdeaf5", # "Blob Reporting App - System Intelligence" app
            auth_type = auth_type)

    endp_key <- AzureStor::storage_endpoint(resource, token = token)
    AzureStor::storage_container(endp_key, container)
}
