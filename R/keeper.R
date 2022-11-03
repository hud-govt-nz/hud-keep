# Keeper
# Framework for storing/retriving files from the blob, and loading these files into the database.
library(AzureStor)
library(AzureRMR)
library(tools)
library(stringr)
library(lubridate)
library(readr)
library(base64enc)

#' Store
#'
#' Stores a local file in the blob.
#' @name store
#' @param local_fn Local filename
#' @param blob_fn Blob filename (including path)
#' @param container_url Azure container URL (e.g. "https://sysintel.blob.core.windows.net/bot-outputs")
#' @param forced Overwrite blob version
#' @export
store <- function(local_fn, blob_fn, container_url, forced = FALSE) {
    message("Storing ", local_fn, " as ", blob_fn, " ...")
    cont <- get_container(container_url)
    if (blob_exists(cont, blob_fn) & !forced) {
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
        upload_blob(cont, local_fn, blob_fn, put_md5 = TRUE)
    }
}

#' Retrive
#'
#' Retrives a file from the blob and save it locally.
#' @name retrieve
#' @param blob_fn Blob filename (including path)
#' @param local_fn Local filename
#' @param container_url Azure container URL (e.g. "https://sysintel.blob.core.windows.net/bot-outputs")
#' @param forced Overwrite local version
#' @export
retrieve <- function(blob_fn, local_fn, container_url, forced = FALSE) {
    message("Retrieving ", local_fn, " from ", blob_fn, " ...")
    cont <- get_container(container_url)
    if (file.exists(local_fn) & !forced) {
        l_props <- local_props(local_fn)
        b_props <- blob_props(blob_fn, cont)
        if (b_props$md5_hash == l_props$md5_hash) {
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
        download_blob(cont, blob_fn, local_fn, overwrite = TRUE)
    }
}

#' List stored
#'
#' List all the files stored in the blob.
#' @name list_stored
#' @param blob_starts_with Path or prefix to look for
#' @param container_url Azure container URL (e.g. "https://sysintel.blob.core.windows.net/bot-outputs")
#' @export
list_stored <- function(blob_starts_with, container_url) {
    cont <- get_container(container_url)
    list_blobs(cont, prefix = blob_starts_with)
}


#===============#
#   Utilities   #
#===============#
hex2base64 <- function(hex_str) {
    hex <- sapply(seq(1, nchar(hex_str), by = 2),
                  function(x) substr(hex_str, x, x + 1))
    raw <- as.raw(strtoi(hex, 16L))
    base64encode(raw)
}

local_props <- function (fn) {
    if (file.exists(fn) == FALSE) {
        stop(paste0(fn, " not found!"))
    }
    props <- file.info(fn)
    list(md5_hash = hex2base64(md5sum(fn)),
         size = props["size"][[1]],
         mtime = as_datetime(props["mtime"][[1]]))
}

blob_props <- function(blob_fn, cont) {
    props <- get_storage_properties(cont, blob_fn)
    list(md5_hash = props["content-md5"][[1]],
         size = props["content-length"][[1]],
         mtime = parse_datetime(props["last-modified"][[1]], "%a, %d %b %Y %T %Z"))
}

get_container <- function(container_url) {
    matches <- str_match_all(container_url, "(https://.*)/([^\\?]+)\\??(.+)?")[[1]]
    resource <- matches[2]
    container <- matches[3]
    sas <- matches[4]
    # URL with access token included
    if (is.na(sas) == FALSE) {
        stop("Use of SAS keys not permitted! Use a plain URL and your AD id will be automatically used.")
        # endp_key <- storage_endpoint(resource, sas = sas)
    }
    # Use default credentials
    else {
        token <- get_azure_token("https://storage.azure.com",
                                 tenant = "9e9b3020-3d38-48a6-9064-373bc7b156dc", # "hud.govt.nz" tenancy
                                 app = "c6c4300b-9ff3-4946-8f30-e0aa59bdeaf5") # "Blob Reporting App - System Intelligence" app
        endp_key <- storage_endpoint(resource, token = token)
    }
    storage_container(endp_key, container)
}
