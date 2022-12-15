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
CONTAINER_URL <- "https://dlprojectsdataprod.blob.core.windows.net/sandbox"

list_stored("", CONTAINER_URL)
store("examples/test.R", "test.R", CONTAINER_URL) # Store
store("examples/manual-methods.R", "test.R", CONTAINER_URL) # Overwrite - won't work, because the hashes don't match
store("examples/manual-methods.R", "test.R", CONTAINER_URL, forced = TRUE) # Overwrite - will work, because of the forced flag
retrieve("test.R", "local-test.R", CONTAINER_URL) # Download - is local-test.R the same as examples/test.R or examples/manual-methods.R?

# Read an existing file from the blob...
retrieve("test.csv", "test-local.csv", CONTAINER_URL)
x <- read_csv("test-local.csv")
file.remove("test-local.csv") # For larger files, you might want to keep the local version to avoid having to download every time

# Or use the convenience function, which does all the above
x <- read_blob("test.csv", CONTAINER_URL)

```

## Where should I put things?
There are multiple containers you can put things in:
* `projects`: **This is what you should probably use.** For data that is created as part of an analysis.
* `bot-outputs`: For data that is created from an automated process.
* `secure`: For special datasets that you don't want mixed up with other datasets. Talk to Keith if you need this.
* `sandbox`: For messing about. This will be wiped clean periodically.

To use any of these containers, use `https://dlprojectsdataprod.blob.core.windows.net/sandbox` etc as the URL.

You should also add a subfolder for the filename, in the form of: `[PROJECT]/[PROJECT]_[YYYYMMDD].[EXTENSION]`. We double-bag the project name so that when it is downloaded, you don't get a random `20220915.csv` file in your download folder. You can also add additional folder layers if you want.

Putting it all together:
```R
library(tidyverse)
library(readxl)
library(hud.keep)
container_url <- "https://dlprojectsdataprod.blob.core.windows.net/projects"

src_local_fn <- "data/source/hlfs_20221101.xls"
src_blob_fn <- "regional-workforce/hlfs_20221101.xls"

# # Download file - leave this code to show how the file was originally retrieved
# download.file("http://stats.govt.nz/blahblah.xls", src_local_fn)
# store(src_local_fn, src_blob_fn, container_url)

# Option 1: Read the file directly, read_blob can handle CSV and Excel (you'll need to name the sheet)
hlfs <- read_blob(src_blob_fn, CONTAINER_URL, sheet = "Sheet1")

# Option 2: Save the file locally, then read
# You might want this for larger file that you don't want to repeatedly download, or if the reading is not straightforward
retrieve(src_blob_fn, src_local_fn, container_url)
hlfs <- read_excel(src_local_fn, sheet = "Sheet1")

# Do analysis
report <-
    hlfs %>%
    mutate(blah = "blah")

# Save output to the blob as well
res_local_fn <- "data/outputs/regional-workforce-trends_20221101.csv"
res_blob_fn <- "regional-workforce/regional-workforce-trends_20221101.csv"
write_csv(report, res_local_fn)
store(res_local_fn, res_blob_fn, container_url)

# See whether new file is there
list_stored("regional-", container_url)
```

You might want to [https://docs.github.com/en/get-started/getting-started-with-git/ignoring-files?platform=windows](ignore the data files) so these are not stored with your code.

The important thing though is that you include the blob file names so that the next person running the code can `retrieve` the exact file you used, and all of these files exist on the blob if we want to go back and reproduce the analysis.


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
