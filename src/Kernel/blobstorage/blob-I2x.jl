# BlobStorage SimOs wrappers (I2x)
# Resolve BlobStorage from explicit SimOs and delegate to I0x APIs.

function blob_write(simos::SimOs, key, value; overwrite::Bool=false)::BlobRef
    storage = sim_project(simos).blobstorage
    blob_write(storage, key, value; overwrite=overwrite)
end

function blob_read(simos::SimOs, ref::BlobRef)
    storage = sim_project(simos).blobstorage
    blob_read(storage, ref)
end

function blob_read(simos::SimOs, key)
    storage = sim_project(simos).blobstorage
    blob_read(storage, key)
end
