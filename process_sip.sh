#!/bin/bash

# Check if both arguments are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 <id> <session>"
    exit 1
fi

id=$1
session=$2

# Run Rscript pull_redcap
Rscript pull_redcap.R "$id" "$session"

# Run synx_axivity
Rscript sync_axivity.R "$id" "$session"

# Run Julia script sync_imu
julia sync_imu.jl "$id" "$session"