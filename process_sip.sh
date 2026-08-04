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
julia sync_imu.jl "$id" "$session" 1

# Run sync_imu for day 2 if corresponding files exist
if [ -f "${id}_${session}/left_ankle_synced_2.csv" ] && \
   [ -f "${id}_${session}/left_hip_synced_2.csv" ] && \
   [ -f "${id}_${session}/right_ankle_synced_2.csv" ] && \
   [ -f "${id}_${session}/right_hip_synced_2.csv" ]; then
    echo "Files for day 2 found. Running sync_imu.jl for day 2..."
    julia sync_imu.jl "$id" "$session" 2
fi

# Run sync_imu for day 3 if corresponding files exist
if [ -f "${id}_${session}/left_ankle_synced_3.csv" ] && \
   [ -f "${id}_${session}/left_hip_synced_3.csv" ] && \
   [ -f "${id}_${session}/right_ankle_synced_3.csv" ] && \
   [ -f "${id}_${session}/right_hip_synced_3.csv" ]; then
    echo "Files for day 3 found. Running sync_imu.jl for day 3..."
    julia sync_imu.jl "$id" "$session" 3
fi

check_file "${id}_${session}/caregiver_hip_synced.csv"
check_file "${id}_${session}/caregiver_wrist_synced.csv"
julia sync_parent_imu.jl "$id" "$session"

check_file "${id}_${session}/cg_position_predictions_4s.csv"
check_file "${id}_${session}/infant_position_predictions_4s.csv"
Rscript position_timeline.R "$id" "$session"