# BlobStorage Function Inventory
**Session**: 2026-02-14 00:10 CST

- `blob_path(storage::BlobStorage, sha1::String)`: Builds the canonical blob file path under `{storage.root_dir}/blobs/<sha1>.jls`.
- `blob_path(project::Project, sha1::String)`: Convenience path helper that resolves blob location from `project.blobstorage`.
- `_hash_key(key)::String`: Computes the deterministic SHA1 hash used as the blob key fingerprint.
- `_serialize_bytes(value)::Vector{UInt8}`: Serializes a Julia value into raw bytes for persistence.
- `blob_ref(key)::BlobRef`: Creates a `BlobRef` from a key by hashing it through the blob key strategy.
- `exists(storage::BlobStorage, ref::BlobRef)`: Checks whether a blob file exists for a given blob reference.
- `exists(storage::BlobStorage, key)`: Checks blob existence by key via `blob_ref(key)`.
- `blob_write(storage::BlobStorage, key, value; overwrite::Bool=false)::BlobRef`: Persists a value to blob storage with collision and overwrite safeguards, then returns its `BlobRef`.
- `blob_read(storage::BlobStorage, ref::BlobRef)`: Loads and deserializes a stored value using a blob reference.
- `blob_read(storage::BlobStorage, key)`: Loads and deserializes a stored value by key via `blob_ref(key)`.
- `blob_write(simos::SimOs, key, value; overwrite::Bool=false)::BlobRef`: App-level wrapper that writes to `sim_project(simos).blobstorage`.
- `blob_read(simos::SimOs, ref::BlobRef)`: App-level wrapper that reads from `sim_project(simos).blobstorage` by reference.
- `blob_read(simos::SimOs, key)`: App-level wrapper that reads from `sim_project(simos).blobstorage` by key.
