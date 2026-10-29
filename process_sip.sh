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
julia --threads=auto sync_imu.jl "$id" "$session" 1

# Run sync_imu for day 2 if corresponding files exist
if [ -f "${id}_${session}/left_ankle_synced_2.csv" ] && \
   [ -f "${id}_${session}/left_hip_synced_2.csv" ] && \
   [ -f "${id}_${session}/right_ankle_synced_2.csv" ] && \
   [ -f "${id}_${session}/right_hip_synced_2.csv" ]; then
    echo "Files for day 2 found. Running sync_imu.jl for day 2..."
    julia --threads=auto sync_imu.jl "$id" "$session" 2
fi

# Run sync_imu for day 3 if corresponding files exist
if [ -f "${id}_${session}/left_ankle_synced_3.csv" ] && \
   [ -f "${id}_${session}/left_hip_synced_3.csv" ] && \
   [ -f "${id}_${session}/right_ankle_synced_3.csv" ] && \
   [ -f "${id}_${session}/right_hip_synced_3.csv" ]; then
    echo "Files for day 3 found. Running sync_imu.jl for day 3..."
    julia --threads=auto sync_imu.jl "$id" "$session" 3
fi

# Run sync_imu for day 4 if corresponding files exist
if [ -f "${id}_${session}/left_ankle_synced_4.csv" ] && \
   [ -f "${id}_${session}/left_hip_synced_4.csv" ] && \
   [ -f "${id}_${session}/right_ankle_synced_4.csv" ] && \
   [ -f "${id}_${session}/right_hip_synced_4.csv" ]; then
    echo "Files for day 4 found. Running sync_imu.jl for day 4..."
    julia --threads=auto sync_imu.jl "$id" "$session" 4
fi

# Run sync_imu for day 5 if corresponding files exist
if [ -f "${id}_${session}/left_ankle_synced_5.csv" ] && \
   [ -f "${id}_${session}/left_hip_synced_5.csv" ] && \
   [ -f "${id}_${session}/right_ankle_synced_5.csv" ] && \
   [ -f "${id}_${session}/right_hip_synced_5.csv" ]; then
    echo "Files for day 5 found. Running sync_imu.jl for day 5..."
    julia --threads=auto sync_imu.jl "$id" "$session" 5
fi


check_file "${id}_${session}/caregiver_hip_synced.csv"
check_file "${id}_${session}/caregiver_wrist_synced.csv"
julia --threads=auto sync_parent_imu.jl "$id" "$session" 1

# Run sync_parent_imu for day 2 if corresponding files exist
if [ -f "${id}_${session}/caregiver_hip_synced_2.csv" ] && \
   [ -f "${id}_${session}/caregiver_wrist_synced_2.csv" ]; then
    echo "Caregiver files for day 2 found. Running sync_parent_imu.jl for day 2..."
    julia --threads=auto sync_parent_imu.jl "$id" "$session" 2
fi

# Run sync_parent_imu for day 3 if corresponding files exist
if [ -f "${id}_${session}/caregiver_hip_synced_3.csv" ] && \
   [ -f "${id}_${session}/caregiver_wrist_synced_3.csv" ]; then
    echo "Caregiver files for day 3 found. Running sync_parent_imu.jl for day 3..."
    julia --threads=auto sync_parent_imu.jl "$id" "$session" 3
fi

# Run sync_parent_imu for day 4 if corresponding files exist
if [ -f "${id}_${session}/caregiver_hip_synced_4.csv" ] && \
   [ -f "${id}_${session}/caregiver_wrist_synced_4.csv" ]; then
    echo "Caregiver files for day 4 found. Running sync_parent_imu.jl for day 4..."
    julia --threads=auto sync_parent_imu.jl "$id" "$session" 4
fi

# Run sync_parent_imu for day 5 if corresponding files exist
if [ -f "${id}_${session}/caregiver_hip_synced_5.csv" ] && \
   [ -f "${id}_${session}/caregiver_wrist_synced_5.csv" ]; then
    echo "Caregiver files for day 5 found. Running sync_parent_imu.jl for day 5..."
    julia --threads=auto sync_parent_imu.jl "$id" "$session" 5
fi

