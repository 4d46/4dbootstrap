# Ideas & future enhancements

## onepassword.sh
- Replace hardcoded `arch=amd64` in the apt source entry with `$(dpkg --print-architecture)` to support arm64 machines, matching the pattern used in docker.sh

## kubernetes.sh
- If `K8S_VERSION` is changed and rerun, `ensure_apt_source` won't update the existing `.list` file because it only acts when the file is absent. Needs a mechanism to detect version mismatch and update the source.

## godot.sh
- Binary download hardcoded to `x86_64`. Add architecture detection to support arm64, matching the pattern used in other modules.
