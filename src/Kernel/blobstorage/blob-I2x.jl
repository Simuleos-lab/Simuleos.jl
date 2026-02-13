# BlobStorage SimOs wrappers (I2x)
# Resolve blob root from explicit SimOs and delegate to I0x APIs.

function blob_write(simos::SimOs, key, value; overwrite::Bool=false)::BlobRef
    root_dir = project(simos).simuleos_dir
    blob_write(root_dir, key, value; overwrite=overwrite)
end

function blob_read(simos::SimOs, ref::BlobRef)
    root_dir = project(simos).simuleos_dir
    blob_read(root_dir, ref)
end

function blob_read(simos::SimOs, key)
    root_dir = project(simos).simuleos_dir
    blob_read(root_dir, key)
end
