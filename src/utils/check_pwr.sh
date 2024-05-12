#!/bin/bash

PWR=""
if [[ $(grep -c "utils/privileges" $(dirname "$(readlink -f "$0")")/utils/.cache) -gt 0 ]]; then
    PWR="sudo"
fi

echo "$PWR"