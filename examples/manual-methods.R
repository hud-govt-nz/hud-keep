# Direct tests of the library, for development purposes
library(AzureStor)
library(AzureRMR)
resource <- "https://dlprojectsdataprod.blob.core.windows.net"

# METHOD 1: Use the "Blob Reporting App - System Intelligence" app key
token <- get_azure_token("https://storage.azure.com",
                         tenant = "9e9b3020-3d38-48a6-9064-373bc7b156dc", # hud.govt.nz tenancy
                         app = "c6c4300b-9ff3-4946-8f30-e0aa59bdeaf5") # "Blob Reporting App - System Intelligence" app
endp_key <- storage_endpoint(resource, token = token)
container <- "test-reportingapp"

# # METHOD 2: Use the "Offline access" key
# token <- get_azure_token("https://storage.azure.com",
#                          tenant = "9e9b3020-3d38-48a6-9064-373bc7b156dc", # hud.govt.nz tenancy
#                          app = "04b07795-8ddb-461a-bbee-02f9e1bf7b46") # Offline access key
# endp_key <- storage_endpoint(resource, token = token)
# container <- "test-offlinekey"
#
# # METHOD 3: Use SAS token
# sas <- "[[ REMOVED - ADD SAS token here to test ]]"
# endp_key <- storage_endpoint(resource, sas = sas)
# container <- "test-sas"

# Test whether delete works
cont <- storage_container(endp_key, container)
create_blob_container(cont)
upload_blob(cont, "README.md", "README.md", put_md5 = TRUE)
upload_blob(cont, "README.md", "README-copy.md", put_md5 = TRUE)
delete_blob(cont, "README.md")
list_blobs(cont)
delete_blob_container(cont)
