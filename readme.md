# Sensors in Person Data Processing Scripts
John Franchak, 1/29/2026

## Usage
Before a file can be processed, you must:
- Use "find_sync_points.m" to find the motion sync points
- Enter the motion sync points in REDCap
- Place all 4 IMU files in the main working directory

If the file is ready (those steps are completed), you can process the infant position data by opening the terminal to the process_sip directory and type `./process_sip.sh [id] [session]` and hit enter. This will:
- Create an output directory for the file and session, such as "12_1"
- Pull the redcap data and write into a CSV file in the output directory
- Trim the IMU time series and synchronize them to each other
- Create the motion features
- Create the windows
- Make the predictions
- Graph the predictions

The process should take about 5-6 minutes. Afterwards, be sure to delete the raw IMU files and move the resulting output directory.

## Requirements
- Julia version 1.12.3
- Julia packages installed via script
- R version 4.5.0
- R packages installed via script
- Matlab 2025 or later to find sync points
- Internet access (to access REDCap data)
- Valid REDCap API token

## Installation
- Install [Julia](https://julialang.org/downloads/manual-downloads/)
- Install [R](https://www.r-project.org/) and [RStudio](https://posit.co/download/rstudio-desktop/)
- Open the terminal and navigate to the process_sip directory
    - Type `julia install/packages.jl` to install the julia packages
    - Type `Rscript install/packages.R` to install the R packages
