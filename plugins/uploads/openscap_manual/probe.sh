#!/bin/bash
# DRSM hook upload plugin: the manifest is plugin.conf, the work is in
# ../upload_probe.sh (shared by every upload hook)
# shellcheck source=plugins/uploads/upload_probe.sh
source "$(dirname "$0")/../upload_probe.sh"
upload_probe
