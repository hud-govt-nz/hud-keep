# HUD keeper framework
**CAUTION: This repo is public. Do not include sensitive data or key materials.**
**SERIOUSLY: Be careful with this one. There are a lot of authentication protocols, do not include keys in them.**

Framework and tools for managing the process of storing and retriving files from the cloud, and doing hash checks on each of those processes.

## Installation
You'll need `devtools::install_github` to install the package:
```R
library(devtools)
install_github("hud-govt-nz/hud-keep")
```


## Usage
```R
library(hud.keep)
CONTAINER_URL <- "https://sysintel.blob.core.windows.net/sandbox"

list_stored("RE", CONTAINER_URL)
store("README.md", "README-blob.md", CONTAINER_URL) # Store
store("R/keeper.R", "README-blob.md", CONTAINER_URL) # Overwrite - won't work, because the hashes don't match
store("R/keeper.R", "README-blob.md", CONTAINER_URL, forced = TRUE) # Overwrite - will work, because of the forced flag
retrieve("README-blob.md", "test-local.R", CONTAINER_URL)
```


## Maintaining this package
If you make changes to this package, you'll need to rerun document from the root directory to update all the R generated files.
```R
library(roxygen2)
roxygenise()
```

I had real problems installing `roxygen2`, because there's a problem with the upstream library `cli`. It's been fixed, but it's not in the CRAN version as of 29-08-2022. You might need the Github version:
```R
library(devtools)
install_github("r-lib/cli")
install_github("r-lib/roxygen2")
library(cli)
library(roxygen2)
roxygenise()
```
