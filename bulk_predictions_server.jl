using CategoricalArrays, DecisionTree
using CSV, DataFrames, DataFrameMacros, JLD2

target_dir = "/Volumes/padlab/study_sensorsinperson/data_processed/imu"
subfolders = filter(isdir, joinpath.(target_dir, readdir(target_dir)))

# LOAD MODELS
model = load_object("group_model_TDCP.jld2")
model_rest = load_object("group_model_restraint_GA.jld2")



##
for folder in subfolders
    
    print("Predicting position and restraint for " * basename(folder) * "\n")
    feature_file = folder *"/" * "mot_features_infant_4s.csv"
    window_file = folder *"/" * "windows_4s.csv"

    slide = CSV.read(feature_file, DataFrame)
    windows = CSV.read(window_file, DataFrame)

    @select!(windows, :temp_time, :exclude_period, :nap_period)

    ds_out = select(slide, :time_start)
    leftjoin!(ds_out, windows, on = :time_start => :temp_time)

    # PREDICT FROM MODELS
    features = Matrix(dropmissing(slide[:,Not(["time_start"])]))
    ds_out.pos = DecisionTree.predict(model, features)
    ds_out.restraint = DecisionTree.predict(model_rest, features)


    # WRITE CSV
    CSV.write(folder * "/" * "infant_position_predictions_4s.csv", ds_out)
end
    
print("Finished writing predictions ")

