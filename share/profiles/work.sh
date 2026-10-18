# shellcheck shell=bash
# description: security only, unattended, no firmware, skips yay and paru
# Settings read by the entry point after sourcing.
# shellcheck disable=SC2034
ARG_SECURITY=1
ARG_YES=1
ARG_NO_FIRMWARE=1
ARG_EXCEPT="${ARG_EXCEPT:+$ARG_EXCEPT,}yay,paru"
ARG_KEEP_CACHE=1
ARG_KEEP_TRASH=1
