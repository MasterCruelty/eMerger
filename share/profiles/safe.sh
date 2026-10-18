# shellcheck shell=bash
# description: least change: security only, no firmware, skips flatpak and snap
# Settings read by the entry point after sourcing.
# shellcheck disable=SC2034
ARG_SECURITY=1
ARG_YES=1
ARG_KEEP_CACHE=1
ARG_KEEP_TRASH=1
ARG_NO_FIRMWARE=1
ARG_EXCEPT="${ARG_EXCEPT:+$ARG_EXCEPT,}flatpak,snap"
