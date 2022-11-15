library(devtools)
install_github("hud-govt-nz/hud-keep")
# install_local("./", force = TRUE)
library(hud.keep)
CONTAINER_URL <- "https://dlreportingdataprod.blob.core.windows.net/sandbox"

list_stored("RE", CONTAINER_URL)
store("README.md", "README-blob.md", CONTAINER_URL) # Store
store("R/keeper.R", "README-blob.md", CONTAINER_URL) # Overwrite - won't work, because the hashes don't match
store("R/keeper.R", "README-blob.md", CONTAINER_URL, forced = TRUE) # Overwrite - will work, because of the forced flag
retrieve("README-blob.md", "test-local.R", CONTAINER_URL)
