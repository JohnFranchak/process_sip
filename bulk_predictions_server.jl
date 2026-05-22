using CSV, DataFrames, Dates, DataFrameMacros, Chain, Statistics, TimeZones, StatsBase
using CategoricalArrays, DecisionTree, JLD2
using Pipe: @pipe

target_dir = "/Volumes/padlab/study_sensorsinperson/data_processed/imu"
subfolders = filter(isdir, joinpath.(target_dir, readdir(target_dir)))

# LOAD MODELS
model = load_object("group_model_TDCP.jld2")
model_rest = load_object("group_model_restraint_GA.jld2")
model_cg = load_object("group_model_parent.jld2")

function add_session_wear_labels!(df::DataFrame; acc_threshold::Float64=0.02, gyro_threshold::Float64=1.0)
    sensors = ["lh", "rh", "la", "ra"]
    df[!, :wear_status] = Vector{String}(undef, nrow(df))
    for r in 1:nrow(df)
        all_sensors_static = true
        for s in sensors
            # 1. Compute 3D Acceleration Standard Deviation
            sd_acc_x = df[r, "sd_$(s)accx"]
            sd_acc_y = df[r, "sd_$(s)accy"]
            sd_acc_z = df[r, "sd_$(s)accz"]
            acc_sd_3d = sqrt(sd_acc_x^2 + sd_acc_y^2 + sd_acc_z^2)
            # 2. Compute 3D Gyroscope Standard Deviation
            sd_gyr_x = df[r, "sd_$(s)gyrx"]
            sd_gyr_y = df[r, "sd_$(s)gyry"]
            sd_gyr_z = df[r, "sd_$(s)gyrz"]
            gyr_sd_3d = sqrt(sd_gyr_x^2 + sd_gyr_y^2 + sd_gyr_z^2)
            # 3. Determine if this specific sensor is flatline (static)
            is_acc_flat  = acc_sd_3d < acc_threshold
            is_gyro_flat = gyr_sd_3d < gyro_threshold
            is_static    = is_acc_flat && is_gyro_flat
            # If even one sensor has motion, then they are not all static
            if !is_static
                all_sensors_static = false
                break # We can stop checking other sensors for this row
            end
        end        
        df[r, :wear_status] = all_sensors_static ? "not_worn" : "worn"
    end
    df[!, :wear_status] = categorical(df[!, :wear_status])
    return df
end
function add_cg_session_wear_labels!(df::DataFrame; acc_threshold::Float64=0.01, gyro_threshold::Float64=1.0)
    sensors = ["lh", "lw"]
    
    # Pre-allocate the unified wear status column
    df[!, :cg_wear_status] = Vector{String}(undef, nrow(df))
    
    for r in 1:nrow(df)
        all_sensors_static = true
        
        for s in sensors
            # 1. Compute 3D Acceleration Standard Deviation
            sd_acc_x = df[r, "sd_$(s)accx"]
            sd_acc_y = df[r, "sd_$(s)accy"]
            sd_acc_z = df[r, "sd_$(s)accz"]
            acc_sd_3d = sqrt(sd_acc_x^2 + sd_acc_y^2 + sd_acc_z^2)
            
            # 2. Compute 3D Gyroscope Standard Deviation
            sd_gyr_x = df[r, "sd_$(s)gyrx"]
            sd_gyr_y = df[r, "sd_$(s)gyry"]
            sd_gyr_z = df[r, "sd_$(s)gyrz"]
            gyr_sd_3d = sqrt(sd_gyr_x^2 + sd_gyr_y^2 + sd_gyr_z^2)
            
            # 3. Determine if this specific sensor is flatline (static)
            is_acc_flat  = acc_sd_3d < acc_threshold
            is_gyro_flat = gyr_sd_3d < gyro_threshold
            is_static    = is_acc_flat && is_gyro_flat
            
            # If even one sensor has motion, then they are not all static
            if !is_static
                all_sensors_static = false
                break # We can stop checking other sensors for this row
            end
        end
        
        # We only predict "not_worn" if every single sensor is completely static
        df[r, :cg_wear_status] = all_sensors_static ? "not_worn" : "worn"
    end
    
    # Convert to CategoricalArray for machine learning compatibility
    df[!, :cg_wear_status] = categorical(df[!, :cg_wear_status])
    
    return df
end
##
for folder in subfolders
    
    print("Predicting position and restraint for " * basename(folder) * "\n")
    feature_file = folder *"/" * "mot_features_infant_4s.csv"
    window_file = folder *"/" * "windows_4s.csv"
    anno_file = folder * "/session_info.csv"

    slide = CSV.read(feature_file, DataFrame)
    windows = CSV.read(window_file, DataFrame)  
    anno = CSV.read(anno_file, DataFrame; missingstring = "NA")

    add_session_wear_labels!(slide)
    @select!(windows, :temp_time, :exclude_period, :nap_period)

    ds_out = select(slide, :time_start, :wear_status)
    leftjoin!(ds_out, windows, on = :time_start => :temp_time)

    # PREDICT FROM MODELS
    features = Matrix(dropmissing(slide[:,Not(["time_start", "wear_status"])]))
    ds_out.pos = DecisionTree.predict(model, features)
    ds_out.restraint = DecisionTree.predict(model_rest, features)

    # WRITE CSV
    CSV.write(folder * "/" * "infant_position_predictions_4s.csv", ds_out)
end
    
print("Finished writing infant predictions ")

## 

#for folder in subfolders
    
    print("Predicting CG position for " * basename(folder) * "\n")
    feature_file = folder *"/" * "mot_features_cg_4s.csv"
    window_file = folder *"/" * "windows_4s.csv"
    anno_file = folder * "/session_info.csv"

    slide = CSV.read(feature_file, DataFrame)
    windows = CSV.read(window_file, DataFrame)
    anno = CSV.read(anno_file, DataFrame; missingstring = "NA")

    @chain anno begin
        @transform! :cg_off_1_start = Date(windows.temp_time[1]) .+ :cg_off_1_start
        @transform! :cg_off_1_end = Date(windows.temp_time[1]) .+ :cg_off_1_end
        @transform! :cg_off_2_start = Date(windows.temp_time[1]) .+ :cg_off_2_start
        @transform! :cg_off_2_end = Date(windows.temp_time[1]) .+ :cg_off_2_end
        @transform! :cg_off_3_start = Date(windows.temp_time[1]) .+ :cg_off_3_start
        @transform! :cg_off_3_end = Date(windows.temp_time[1]) .+ :cg_off_3_end
        @transform! :cg_off_4_start = Date(windows.temp_time[1]) .+ :cg_off_4_start
        @transform! :cg_off_4_end = Date(windows.temp_time[1]) .+ :cg_off_4_end
        @transform! :cg_off_5_start = Date(windows.temp_time[1]) .+ :cg_off_5_start
        @transform! :cg_off_5_end = Date(windows.temp_time[1]) .+ :cg_off_5_end
    end

    exclude_starts = dropmissing(stack(select(select(select(anno, r"off"),r"start"),r"cg"),1:5))
    exclude_ends = dropmissing(stack(select(select(select(anno, r"off"),r"end"),r"cg"),1:5))

    add_cg_session_wear_labels!(slide)

    ds_out = select(slide, :time_start, :cg_wear_status)
    ds_out[!, :cg_exclude_period] .= 0
    if  nrow(exclude_starts) > 0
        for i in axes(exclude_starts,1)
            @transform!(ds_out, @subset(:time_start >= exclude_starts.value[i] && :time_start <= exclude_ends.value[i]), :cg_exclude_period = 1)
        end
    end

    features = Matrix(dropmissing(slide[:,Not(["time_start", "cg_wear_status"])]))
    ds_out.pos = DecisionTree.predict(model_cg, features)

    # WRITE CSV
    CSV.write(folder * "/" * "cg_position_predictions_4s.csv", ds_out)
end