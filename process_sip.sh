#!/bin/bash

# Check if both arguments are provided
if [ $# -lt 2 ]; then
    echo "Requires id and session arguments: $0 <id> <session>"
    exit 1
fi

id=$1
session=$2

check_file() {
    if [ ! -f "$1" ]; then
        echo "Error: File '$1' not found; aborting."
        exit 1
    fi
}

# Run Rscript pull_redcap
Rscript pull_redcap.R "$id" "$session"

# Check if the expected output file from pull_redcap exists
FILE="${id}_${session}/session_info.csv"
check_file "$FILE"

# Run synx_axivity
Rscript sync_axivity.R "$id" "$session"

check_file "${id}_${session}/left_ankle_synced.csv"
check_file "${id}_${session}/left_hip_synced.csv"
check_file "${id}_${session}/right_ankle_synced.csv"
check_file "${id}_${session}/right_hip_synced.csv"

# Run Julia script sync_imu
julia sync_imu.jl "$id" "$session"