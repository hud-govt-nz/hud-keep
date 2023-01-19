# Keeper
# Framework for storing/retriving files from the blob
import re
import hashlib, magic
from pathlib import Path
from datetime import datetime
from azure.identity import DefaultAzureCredential
from azure.storage.blob import ContainerClient, ContentSettings


#===========#
#   Store   #
#===========#
# Stores a local file in the blob
def store(local_fn, blob_fn, container_url, forced = False):
    print(f"Storing '{local_fn}' as '{blob_fn}'...")
    blob = get_blob_client(blob_fn, container_url)
    local = Path(local_fn)
    l_md5, l_size, l_mtime = local_props(local_fn)
    if blob.exists() and not forced:
        # Need to do our own md5_hashing as the automatic blob hashing can't handle large files
        b_md5, b_size, b_mtime = blob_props(blob_fn, container_url)
        if b_md5 == l_md5:
            print(f"File with matching hash was already stored on {b_mtime}.")
        else:
            raise Exception(
                f"Local file '{local_fn}' ({l_size} bytes, last modified {l_mtime}) doesn't match "
                f"blob file '{blob_fn}' ({b_size} bytes, last modified {b_mtime})!\n"
                f"Use 'forced=True' to overwrite."
            )
    else:
        blob.upload_blob(
            local.open("rb"),
            overwrite = True,
            content_settings = ContentSettings(
                content_type = magic.from_file(local_fn, mime=True),
                content_md5 = l_md5
            )
        )
        return True

# Retrives a file from the blob and save it locally
def retrieve(local_fn, blob_fn, container_url, forced = False):
    print(f"Retrieving '{local_fn}' from '{blob_fn}'...")
    blob = get_blob_client(blob_fn, container_url)
    local = Path(local_fn)
    if local.exists() and not forced:
        l_md5, l_size, l_mtime = local_props(local_fn)
        b_md5, b_size, b_mtime = blob_props(blob_fn, container_url)
        if b_md5 == l_md5:
            print("Local file already exists and matches the blob hash.")
        else:
            raise Exception(
                f"Local file '{local_fn}' ({l_size} bytes, last modified {l_mtime}) doesn't match "
                f"blob file '{blob_fn}' ({b_size} bytes, last modified {b_mtime})!\n"
                f"Use 'forced=True' to overwrite."
            )
    else:
        blob_data = blob.download_blob()
        blob_data.readinto(local.open("wb"))
        return True

# List files stored on the blob
def list_stored(blobs_starts_with, container_url):
    container = get_container_client(container_url)
    blobs = container.list_blobs(blobs_starts_with)
    return list(blobs)


#===============#
#   Utilities   #
#===============#
def local_props(fn):
    p = Path(fn)
    with p.open("rb") as f:
        md5 = hashlib.md5()
        while True:
            data = f.read(2**20)
            if not data: break
            md5.update(data)
        md5_hash = md5.digest()
    size = p.stat().st_size
    mtime = datetime.fromtimestamp(p.stat().st_mtime)
    return md5_hash, size, mtime

def blob_props(blob_fn, container_url):
    blob = get_blob_client(blob_fn, container_url)
    props = blob.get_blob_properties()
    md5_hash = props["content_settings"]["content_md5"]
    size = props["size"]
    mtime = props["last_modified"]
    return md5_hash, size, mtime

def get_container_client(container_url):
    m = re.match("(https://[^/]+)/([^\?]+)\??(.*)", container_url)
    # URL with access token included
    if m[3]:
        raise Exception("Use of SAS keys not permitted! Use a plain URL and your AD id will be automatically used.")
        # return ContainerClient.from_container_url(container_url)
    # Use default credentials
    else:
        creds = DefaultAzureCredential(managed_identity_client_id = "c6c4300b-9ff3-4946-8f30-e0aa59bdeaf5")
        return ContainerClient(m[1], m[2], credential = creds)

def get_blob_client(blob_fn, container_url):
    container = get_container_client(container_url)
    return container.get_blob_client(blob_fn)
