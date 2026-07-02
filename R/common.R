#' Setup
#'
#' Does all the things required to set up AzureAuth.
#' @name setup
#' @export
setup <- function() {
    # Use "device_code" on the cloud because we can't hook up to a browser
    if (grepl("azure", Sys.info()["release"])) {
        auth_type <- "device_code"
        dir.create("~/.local/share/AzureR", showWarnings = FALSE) # Non-interactive session can't ask to create a folder, so just do it
    } else {
        auth_type <- NULL
        dir.create("~/../AppData/Local/AzureR") # Non-interactive session can't ask to create a folder, so just do it
    }
    AzureAuth::get_azure_token(
        resource = "https://storage.azure.com",
        tenant = "9e9b3020-3d38-48a6-9064-373bc7b156dc", # "hud.govt.nz" tenancy
        app = "c6c4300b-9ff3-4946-8f30-e0aa59bdeaf5", # "Blob Reporting App - System Intelligence" app
        auth_type = auth_type)
}
