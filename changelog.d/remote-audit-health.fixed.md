Remote Harn release-audit offload now checks builder resource pressure before
starting the expensive remote audit, falling back locally when active Cargo/Rust
work, low memory, or exhausted swap would make the offload unreliable. Failed
remote audits also stream the failure header plus final tail instead of only the
last lines, making fallback causes diagnosable.
