## projPath vd projRoot
Definition
- projPath — input path: any path the caller provides as a starting point (can be a subfolder, a
workspace subdirectory, or the root itself)
- projRoot — resolved root: the actual project root directory, always containing .simuleos/

Key distinction
- projPath preserves caller intent — "where I am"
- projRoot preserves system truth — "where the project lives"
- projPath may equal projRoot, but never the reverse guarantee