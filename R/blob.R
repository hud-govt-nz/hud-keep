#' Store
#'
#' Stores a local file in the blob.
#' @name store
#' @param local_fn Local filename
#' @param blob_fn Blob filename (including path)
#' @param container_url Azure container URL (e.g. "https://dlprojectsdataprod.blob.core.windows.net/bot-outputs")
#' @param update Update the blob version if the local version is newer
#' @param forced Overwrite blob version no matter what
#' @export
store <- function(local_fn, blob_fn, container_url, update = TRUE, forced = FALSE, quiet = FALSE) {
    if (!quiet) message("Storing ", local_fn, " as ", blob_fn, "...")
    cont <- get_container(container_url)
    if (!forced & AzureStor::blob_exists(cont, blob_fn)) {
        l_props <- local_props(local_fn)
        b_props <- blob_props(blob_fn, cont)
        if (l_props$md5_hash == b_props$md5_hash) {
            return(local_fn)
        } else if (l_props$mtime < b_props$mtime) {
            stop(
                "Local file is older (last modified ", l_props$mtime, ") ",
                "than blob file (", b_props$mtime, "). ",
                "\nUse 'forced=TRUE' to overwrite.")
        } else if (!update) {
            stop(
                "Blob file already exists (last modified", b_props$mtime, ") ",
                "and you've set update=FALSE.")
        }
    }
    AzureStor::upload_blob(cont, local_fn, blob_fn, put_md5 = TRUE)
    return(local_fn)
}

#' Store data
#'
#' Stores a dataframe or tibble in the blob.
#' @name store_data
#' @param x Dataframe or tibble
#' @param blob_fn Blob filename (including path)
#' @param container_url Azure container URL (e.g. "https://dlprojectsdataprod.blob.core.windows.net/bot-outputs")
#' @param file_format Format for saving the file
#' @param update Update the blob version if the local version is newer
#' @param forced Overwrite blob version no matter what
#' @export
store_data <- function(x, blob_fn, container_url, f = saveRDS, update = TRUE, forced = FALSE) {
    message("Storing data as ", blob_fn, "...")
    local_fn <- tempfile()
    f(x, local_fn) # Save file using the provided function
    store(local_fn, blob_fn, container_url, update, forced, quiet = TRUE)
}

#' Store folder
#'
#' Recursively store everything inside a folder in the blob.
#' @name store_folder
#' @param local_path Local folder (e.g. "outputs/20250101")
#' @param blob_path Blob path where the contents of the local folder will be uploaded to (e.g. "project_name/outputs/20250101")
#' @param container_url Azure container URL (e.g. "https://dlprojectsdataprod.blob.core.windows.net/bot-outputs")
#' @param update Update the blob version if the local version is newer
#' @param forced Overwrite blob version no matter what
#' @export
store_folder <- function(local_path, blob_path, container_url, update = TRUE, forced = FALSE) {
    message("Uploading folder '", local_path, "' to '", blob_path, "'...")
    blob_list <-
        list_stored(blob_path, container_url) %>%
        transmute(
            file_name = str_replace(name, paste0(blob_path, "/"), ""),
            md5_hash = `Content-MD5`,
            size = size,
            mtime = `Last-Modified`)

    local_list <-
        list_local(local_path) %>%
        left_join(
            blob_list,
            by = "file_name",
            relationship = "one-to-one",
            suffix = c(".local", ".blob")) %>%
        mutate(status = case_when(
            is.na(mtime.blob) ~ "new",
            md5_hash.local == md5_hash.blob ~ "unchanged",
            mtime.local > mtime.blob ~ "updated",
            TRUE ~ "error"))

    if (!forced & any(local_list$status == "error")) {
        print(local_list %>% filter(status == "error"))
        stop(
            "Some local files are older than blob files! ",
            "\nUse 'forced=TRUE' to overwrite.")
    } else if (!update & any(local_list$status  == "updated")) {
        print(local_list %>% filter(status == "updated"))
        stop(
            "Some local files have been updated, ",
            "but you've set update=FALSE.")
    }

    target_list <- local_list %>% filter(status != "unchanged")
    AzureStor::multiupload_blob(
        get_container(container_url),
        file.path(local_path, target_list$file_name),
        file.path(blob_path, target_list$file_name),
        put_md5 = TRUE)
}

#' Retrive
#'
#' Retrives a file from the blob and save it locally.
#' @name retrieve
#' @param blob_fn Blob filename (including path)
#' @param local_fn Local filename
#' @param container_url Azure container URL (e.g. "https://dlprojectsdataprod.blob.core.windows.net/bot-outputs")
#' @param update Update the local version if the blob version is newer
#' @param forced Overwrite local version no matter what
#' @export
retrieve <- function(blob_fn, local_fn, container_url, update = TRUE, forced = FALSE) {
    message("Retrieving ", local_fn, " from ", blob_fn, "...")
    cont <- get_container(container_url)
    if (!forced & file.exists(local_fn)) {
        l_props <- local_props(local_fn)
        b_props <- blob_props(blob_fn, cont)
        if (!is.null(b_props$md5_hash) & b_props$md5_hash == l_props$md5_hash) {
            return(local_fn)
        } else if (b_props$mtime < l_props$mtime) {
            stop(
                "Blob file is older (last modified ", b_props$mtime, ") ",
                "than local file (", l_props$mtime, "). ",
                "\nUse 'forced=TRUE' to overwrite.")
        } else if (!update) {
            stop(
                "Local file already exists (last modified", l_props$mtime, ") ",
                "and you've set update=FALSE.")
        }
    }
    AzureStor::download_blob(cont, blob_fn, local_fn, overwrite = TRUE)
    return(local_fn)
}

#' Read blob data file
#'
#' Read a CSV/Excel file from the blob
#' @name read_blob_data
#' @param blob_fn Blob filename (including path)
#' @param container_url Azure container URL (e.g. "https://dlprojectsdataprod.blob.core.windows.net/bot-outputs")
#' @param f Custom function (leave empty to auto-select based on file extension)
#' @param ... Additional parameters for custom function
#' @export
read_blob_data <- function(blob_fn, container_url, f = NA, ...) {
    extension <- tolower(stringr::str_extract(blob_fn, "\\.\\w+$"))
    if (!is.na(f)) {
        f <- f
    } else if (extension == ".rds") {
        f <- readr::read_rds
    } else if (extension == ".csv") {
        f <- readr::read_csv
    } else if (extension == ".tsv") {
        f <- readr::read_tsv
    } else if (extension == ".xls" || extension == ".xlsx") {
        f <- readxl::read_excel
    } else {
        stop("I don't know how to read '", extension, "' files!")
    }

    local_fn <- tempfile()
    retrieve(blob_fn, local_fn, container_url)
    blob_df <- f(local_fn, ...)
    file.remove(local_fn)
    return(blob_df)
}

#' [DEPRECATED] Read blob file using custom function
#'
#' Use read_blob_data() instead
#' @name read_blob_using
#' @param blob_fn Blob filename (including path)
#' @param container_url Azure container URL (e.g. "https://dlprojectsdataprod.blob.core.windows.net/bot-outputs")
#' @param f Custom function
#' @param ... Additional parameters for custom function
#' @export
read_blob_using <- read_blob_data

#' List stored
#'
#' List all the files stored in the blob.
#' @name list_stored
#' @param blob_starts_with Path or prefix to look for
#' @param container_url Azure container URL (e.g. "https://dlprojectsdataprod.blob.core.windows.net/bot-outputs")
#' @export
list_stored <- function(blob_starts_with, container_url) {
    cont <- get_container(container_url)
    AzureStor::list_blobs(cont, prefix = blob_starts_with, info = "all") %>%
        dplyr::as_tibble()
}

#' List local
#'
#' List all the files stored within a local folder, with hashes.
#' @name list_local
#' @param trg_path Path
#' @param full.names Whether to include source path in the file names
#' @export
list_local <- function(trg_path, full.names = FALSE) {
    full_names <- list.files(trg_path, recursive = TRUE, full.names = TRUE)
    display_names <- list.files(trg_path, recursive = TRUE, full.names = full.names)
    file_props <- purrr::map(full_names, ~ dplyr::as_tibble(local_props(.)))
    dplyr::as_tibble(cbind(
        list(file_name = display_names),
        do.call(rbind, file_props)))
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
#' @param dir Base path to search in (e.g. "hmu-bot")
#' @param container_url Azure container URL (e.g. "https://dlprojectsdataprod.blob.core.windows.net/bot-outputs")
#' @export
find_latest <- function(blob_pattern, dir, container_url) {
    cont <- get_container(container_url)
    file_list <- AzureStor::list_blobs(cont, dir, info = "name") # Using a prefix_filter will speed things up
    matches <- file_list[grepl(blob_pattern, file_list)]
    if (length(matches) == 0) stop("No matches for '", blob_pattern, "' in '", container_url, "/", dir, "'!")
    latest <- tail(sort(matches), 1)
    return(latest)
}

#===============#
#   Utilities   #
#===============#
hex2base64 <- function(hex_str) {
    hex <- sapply(seq(1, nchar(hex_str), by = 2),
                  function(x) substr(hex_str, x, x + 1))
    raw <- as.raw(strtoi(hex, 16L))
    out <- base64enc::base64encode(raw)
    return(out)
}

local_props <- function (fn) {
    if (file.exists(fn) == FALSE) {
        stop(paste0(fn, " not found!"))
    }
    props <- file.info(fn)
    prop_list <- list(
        md5_hash = hex2base64(tools::md5sum(fn)),
        size = props["size"][[1]],
        mtime = lubridate::as_datetime(props["mtime"][[1]]))
    return(prop_list)
}

blob_props <- function(blob_fn, cont) {
    props <- AzureStor::get_storage_properties(cont, blob_fn)
    prop_list <- list(
        md5_hash = props["content-md5"][[1]],
        size = props["content-length"][[1]],
        mtime = lubridate::dmy_hms(props["last-modified"][[1]]))
    return(prop_list)
}

#' Get container
#'
#' Performs authentication and obtains blob container object.
#' @name get_container
#' @param container_url Azure container URL (e.g. "https://dlprojectsdataprod.blob.core.windows.net/bot-outputs")
#' @export
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
    cont <- AzureStor::storage_container(endp_key, container)
    return(cont)
}
