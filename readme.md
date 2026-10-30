# Sensors in Person Data Processing Scripts
John Franchak, 1/29/2026
- 02/10/2026: Updated installation process to use julia project.toml
- 02/20/2026: Included caregiver IMU files
- 08/03/2026: Supports processing for multiple day recordings
- 10/30/2026: Converted intermediate files (synced IMU, windows, motion features) to Parquet format (`.parquet`) while keeping final predictions as CSV; added multi-day caregiver IMU processing (days 2–5)

## Requirements
- Julia version 1.12.3
- Julia packages installed via `instantiate()` (instructions below)
- R version 4.5.0
- R packages (instructions below)
- Matlab 2024 or later to find sync points
- Internet access (to access REDCap data)
- Valid REDCap API token downloaded from the server
- Julia prediction models downloaded from the server (`group_model_TDCP_fast.jld2`, `group_model_restraint_GA_fast.jld2`, and `group_model_parent_fast.jld2`)

## Installation
- Install [Julia](https://julialang.org/downloads/manual-downloads/)
  - Type `julia` in the terminal and hit return to enter the Julia CLI
  - Type `]` and wait for the command prompt to change to `pkg]`
  - Type `activate .` and hit return
  - Type `instantiate` and hit return
  - Close the terminal and ignore any warnings
- Install [R](https://www.r-project.org/) and [RStudio](https://posit.co/download/rstudio-desktop/)
  - Open the R project folder in RStudio
  - Run the `install_r_packages.R` script to install any needed R packages
- Ensure that files that aren't part of the github packages (API key and models) are downloaded from the server
- **Updating an existing installation**: After pulling new changes, re-run `activate .` and `instantiate` in Julia (to install `Parquet2`) and re-run `install_r_packages.R` (or `install.packages("nanoparquet")`) in R.
    
## Usage
Before a file can be processed, you must:
- Use "find_sync_points.m" to find the motion sync points
- Enter the motion sync points in REDCap
- Place all 6 IMU files in the main working directory

If the file is ready (those steps are completed), you can process the infant position data by opening the terminal to the process_sip directory and type `./process_sip.sh [id] [session]` and hit enter. This will:
- Create an output directory for the file and session, such as "12_1"
- Pull the redcap data and write into a CSV file in the output directory (`session_info.csv` and `multiday_info*.csv`)
- Trim the IMU time series, synchronize them to each other, and save them as Parquet files (`*_synced*.parquet`)
- Create the 4s windows (`windows_4s*.parquet`) and infant motion features (`mot_features_infant_4s*.parquet`) for all available days
- Create the caregiver motion features (`mot_features_cg_4s*.parquet`) for all available days
- Save the final infant and caregiver position predictions as CSV files (`infant_position_predictions_4s*.csv` and `cg_position_predictions_4s*.csv`)

The process should take about 5-6 minutes. Afterwards, be sure to delete the raw IMU files and move the resulting output directory to the server.
