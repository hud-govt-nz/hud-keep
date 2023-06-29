# HUD keeper framework
**CAUTION: This repo is public. Do not include sensitive data or key materials.**
**SERIOUSLY: Be careful with this one. There are a lot of authentication protocols, do not include keys in them.**

Framework and tools for managing the process of storing and retriving files from the cloud, and doing hash checks on each of those processes. Python version of the tools are also included in this library.

## Installation
Install directly from Github. The `-e` will keep the file editable.

```
pip install -e git+https://github.com/hud-govt-nz/hud-keep.git@main#egg=hudkeep
```
OR:
```
pipenv install -e git+https://github.com/hud-govt-nz/hud-keep.git@main#egg=hudkeep
```

## Usage
```python
import hudkeep
CONTAINER_URL = "https://dlprojectsdataprod.blob.core.windows.net/sandbox"

list_stored("RE", CONTAINER_URL)
store("README.md", "README-blob.md", CONTAINER_URL) # Store
store("hudkeep/__init__.py", "README-blob.md", CONTAINER_URL) # Overwrite - won't work, because the hashes don't match
store("hudkeep/__init__.py", "README-blob.md", CONTAINER_URL, forced = TRUE) # Overwrite - will work, because of the forced flag
retrieve("README-blob.md", "test-local.R", CONTAINER_URL)
```
