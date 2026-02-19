using Pkg
# Activate the folder where this script lives
Pkg.activate(@__DIR__)

using CSV, DataFrames, Dates, DataFrameMacros, Chain, Statistics, TimeZones, StatsBase
using CategoricalArrays, DecisionTree, JLD2
using Pipe: @pipe

println("Running in environment: ", Base.active_project())

if length(ARGS) > 0
    println("Creating caregiver motion features for id " * ARGS[1] * " session " * ARGS[2])
    const id = ARGS[1]
    const session = ARGS[2]
else
    # For interactive testing
    const id = "12"
    const session = "1"
end

const run_start = now()

const suffix = ""

function assign(;s::AbstractString, v::Any)
	s = Symbol(s)
	@eval (($s) = ($v))
end

function fix_tz(date_epoch)
    dt = unix2datetime.(date_epoch)
    zdt = ZonedDateTime.(dt, tz"UTC")
    ldt = astimezone.(zdt, tz"America/Los_Angeles")
    DateTime.(ldt)
end

adjust_dst = 0
function imu_file(;loc)
    file = id * "_" * session * "/" * "caregiver_" * loc * "_synced.csv"
    println(file)
    short_code = "l"*loc[1]
    temp = CSV.read(file, DataFrame; header=["time",short_code*"accx",short_code*"accy",short_code*"accz",short_code*"gyrx",short_code*"gyry",short_code*"gyrz"], skipto=2)
    @transform!(temp, :time = fix_tz(:time) + Hour(adjust_dst))
    assign(; s = short_code,v = temp)
end


imu_file(; loc = "wrist")
imu_file(; loc = "hip")

dropmissing!(lw, :time)
dropmissing!(lh, :time)
##
ds = outerjoin(lh, lw, on = :time)

sort!(ds, :time)
temp_time = ds.time
ds = ds[!, Not(:time)]
ffill(v) = v[accumulate(max, [i*!ismissing(v[i]) for i in eachindex(v)], init=1)]
mapcols!(ffill, ds)
ds.time = temp_time

#Resample to 50 Hz
time_sec = datetime2unix.(temp_time) .- datetime2unix.(temp_time[1])
ds.time_sample = Int64.(round.(time_sec./.02))
ds = @combine(@groupby(ds, :time_sample), "{}" = first({All()}, 1))
select!(ds, Not(:time_sample))


##
# Define all of the summary functions
# sensor sum 
function calc_sensor_mean(data, label)
    temp = @combine(@groupby(data, :time_sec0), begin
        :lwacc = mean({{r"lwacc"}})
        :lhacc = mean({{r"lhacc"}})
        :lwgyr = mean({{r"lwgyr"}})
        :lhgyr = mean({{r"lhgyr"}})
    end)
    temp = @combine(@groupby(temp, :time_sec0), "{}_$label" = first({Not(:time_sec0)}, 1))
end
# axis sum 
function calc_axis_mean(data, label)
    temp = @combine(@groupby(data, :time_sec0), begin
        :accx = mean({{r"accx"}})
        :accy = mean({{r"accy"}})
        :accz = mean({{r"accz"}})
        :gyrx = mean({{r"gyrx"}})
        :gyry = mean({{r"gyry"}})
        :gyrz = mean({{r"gyrz"}})
    end)
    temp = @combine(@groupby(temp, :time_sec0), "{}_$label" = first({Not(:time_sec0)}, 1))
end
# Within-sensor between axis correlations
function calc_within_corr(data; abs_suffix = false)
    temp = @combine(@groupby(data, :time_sec0), begin
    :lwaccx_cor_lwaccy = cor(:lwaccx, :lwaccy)
    :lwaccy_cor_lwaccz = cor(:lwaccy, :lwaccz)
    :lwaccx_cor_lwaccz = cor(:lwaccx, :lwaccz)
    :lhaccx_cor_lhaccy = cor(:lhaccx, :lhaccy)
    :lhaccy_cor_lhaccz = cor(:lhaccy, :lhaccz)
    :lhaccx_cor_lhaccz = cor(:lhaccx, :lhaccz)
    :lwgyrx_cor_lwgyry = cor(:lwgyrx, :lwgyry)
    :lwgyry_cor_lwgyrz = cor(:lwgyry, :lwgyrz)
    :lwgyrx_cor_lwgyrz = cor(:lwgyrx, :lwgyrz)
    :lhgyrx_cor_lhgyry = cor(:lhgyrx, :lhgyry)
    :lhgyry_cor_lhgyrz = cor(:lhgyry, :lhgyrz)
    :lhgyrx_cor_lhgyrz = cor(:lhgyrx, :lhgyrz)
    end)
    if abs_suffix == true
        add_abs(s) = s*"_abs"
        rename!(add_abs, temp)
        remove_suffix(s) = s[1:end-4]
        rename!(temp, names(temp)[1] => remove_suffix(names(temp)[1]))
    end
    temp
end
# Between-sensor correlations within axes
function calc_between_corr(data; abs_suffix = false)
    temp = @combine(@groupby(data, :time_sec0), begin
    :lwaccx_cor_lhaccx = cor(:lwaccx, :lhaccx)
    :lwaccy_cor_lhaccy = cor(:lwaccy, :lhaccy)
    :lwaccz_cor_lhaccz = cor(:lwaccz, :lhaccz)
    :lwgyrx_cor_lhgyrx = cor(:lwgyrx, :lhgyrx)
    :lwgyry_cor_lhgyry = cor(:lwgyry, :lhgyry)
    :lwgyrz_cor_lhgyrz = cor(:lwgyrz, :lhgyrz)
    end)
    if abs_suffix == true
        add_abs(s) = s*"_abs"
        rename!(add_abs, temp)
        remove_suffix(s) = s[1:end-4]
        rename!(temp, names(temp)[1] => remove_suffix(names(temp)[1]))
    end
    temp
end
# Within-sensor between axis differences
function calc_within_diff(data; abs_suffix = false)
    temp = @combine(@groupby(data, :time_sec0), begin
    :lwaccx_diff_lwaccy = mean(:lwaccx - :lwaccy)
    :lwaccy_diff_lwaccz = mean(:lwaccy - :lwaccz)
    :lwaccx_diff_lwaccz = mean(:lwaccx - :lwaccz)
    :lhaccx_diff_lhaccy = mean(:lhaccx - :lhaccy)
    :lhaccy_diff_lhaccz = mean(:lhaccy - :lhaccz)
    :lhaccx_diff_lhaccz = mean(:lhaccx - :lhaccz)
    :lwgyrx_diff_lwgyry = mean(:lwgyrx - :lwgyry)
    :lwgyry_diff_lwgyrz = mean(:lwgyry - :lwgyrz)
    :lwgyrx_diff_lwgyrz = mean(:lwgyrx - :lwgyrz)
    :lhgyrx_diff_lhgyry = mean(:lhgyrx - :lhgyry)
    :lhgyry_diff_lhgyrz = mean(:lhgyry - :lhgyrz)
    :lhgyrx_diff_lhgyrz = mean(:lhgyrx - :lhgyrz)
    end)
    if abs_suffix == true
        add_abs(s) = s*"_abs"
        rename!(add_abs, temp)
        remove_suffix(s) = s[1:end-4]
        rename!(temp, names(temp)[1] => remove_suffix(names(temp)[1]))
    end
    temp
end
# Between-sensor correlations within axes
function calc_between_diff(data; abs_suffix = false)
    temp = @combine(@groupby(data, :time_sec0), begin
    :lwaccx_diff_lhaccx = mean(:lwaccx - :lhaccx)
    :lwgyrx_diff_lhgyrx = mean(:lwgyrx - :lhgyrx)
    :lwaccy_diff_lhaccy = mean(:lwaccy - :lhaccy)
    :lwgyry_diff_lhgyry = mean(:lwgyry - :lhgyry)
    :lwaccz_diff_lhaccz = mean(:lwaccz - :lhaccz)
    :lwgyrz_diff_lhgyrz = mean(:lwgyrz - :lhgyrz)
    end)
    if abs_suffix == true
        add_abs(s) = s*"_abs"
        rename!(add_abs, temp)
        remove_suffix(s) = s[1:end-4]
        rename!(temp, names(temp)[1] => remove_suffix(names(temp)[1]))
    end
    temp
end

function slide_calc(ds_temp)
    times = @combine(@groupby(ds_temp, :time_sec0), "time_start" = first(:time, 1))
    simple_stats = @combine(@groupby(ds_temp, :time_sec0), begin
        "mean_{}" = mean({r"acc|gyr"})
        "median_{}" = median({r"acc|gyr"})
        "sd_{}" = std({r"acc|gyr"}) 
        "skew_{}" = skewness({r"acc|gyr"})
        "kurtosis_{}" = kurtosis({r"acc|gyr"})
        "per25_{}" = percentile({r"acc|gyr"}, 25)
        "per75_{}" = percentile({r"acc|gyr"}, 75)
    end
    )
    # Run everything on signed signals
    sensor_mean = calc_sensor_mean(ds_temp, "mean")
    axis_mean = calc_axis_mean(ds_temp, "mean")
    within_corr = calc_within_corr(ds_temp)
    between_corr = calc_between_corr(ds_temp)
    within_diff = calc_within_diff(ds_temp)
    between_diff = calc_between_diff(ds_temp)
    # Run everything on unsigned signals
    
    ds_temp_mag = @transform(ds_temp, "{}" = abs({Not(:time)}))
    axis_mag = calc_axis_mean(ds_temp_mag, "mag")
    sensor_mag = calc_sensor_mean(ds_temp_mag, "mag")
    within_corr_abs = calc_within_corr(ds_temp_mag; abs_suffix = true)
    between_corr_abs = calc_between_corr(ds_temp_mag; abs_suffix = true)
    within_diff_abs = calc_within_diff(ds_temp_mag; abs_suffix = true)
    between_diff_abs = calc_between_diff(ds_temp_mag; abs_suffix = true)
    # TRY HCAT INSTEAD OF JOIN?
    slide = @pipe outerjoin(times, simple_stats, on = :time_sec0) |> 
        outerjoin(_, sensor_mean, on = :time_sec0) |>
        outerjoin(_, sensor_mag, on = :time_sec0) |>
        outerjoin(_, axis_mean, on = :time_sec0) |>
        outerjoin(_, axis_mag, on = :time_sec0) |>
        outerjoin(_, within_corr, on = :time_sec0) |>
        outerjoin(_, within_corr_abs, on = :time_sec0) |>
        outerjoin(_, between_corr, on = :time_sec0) |>
        outerjoin(_, between_corr_abs, on = :time_sec0) |>
        outerjoin(_, within_diff, on = :time_sec0) |>
        outerjoin(_, between_diff, on = :time_sec0) |>
        outerjoin(_, within_diff_abs, on = :time_sec0) |>
        outerjoin(_, between_diff_abs, on = :time_sec0) 
    slide
end

windows = CSV.read(id * "_" * session * "/" * "windows_4s.csv", DataFrame)

temp_time = ds.time

ds.time_sec_rounded = round.(datetime2unix.(temp_time) .- datetime2unix.(windows.temp_time[1]), digits = 2)
ds = filter(row -> row.time_sec_rounded >= 0, ds)
select!(ds, Not(:time_sec_rounded))

##

time_sec0 = windows.time_sec0[1:nrow(ds)]
time_sec1 = windows.time_sec1[1:nrow(ds)]
time_sec2 = windows.time_sec2[1:nrow(ds)]
time_sec3 = windows.time_sec3[1:nrow(ds)]

##
dropmissing!(ds)
ds.time_sec0 = time_sec0
slide0 = slide_calc(ds)
ds.time_sec0 = time_sec1
slide1 = slide_calc(ds)
ds.time_sec0 = time_sec2
slide2 = slide_calc(ds)
ds.time_sec0 = time_sec3
slide3 = slide_calc(ds)

slide = vcat(slide0, slide1, slide2, slide3)
sort!(slide, :time_start)
@subset!(slide, :time_sec0 > 1)
select!(slide, Not(:time_sec0))
CSV.write(id * "_" * session *"/" * "mot_features_cg_4s.csv", slide)

@select!(windows, :temp_time)

ds_out = select(slide, :time_start)
leftjoin!(ds_out, windows, on = :time_start => :temp_time)

# PREDICT FROM MODEL
model = load_object("group_model_parent.jld2")
features = Matrix(dropmissing(slide[:,Not(["time_start"])]))
ds_out.pos = DecisionTree.predict(model, features)

# WRITE CSV
CSV.write(id * "_" * session * "/" * "cg_position_predictions_4s.csv", ds_out)

println("Wrote motion features and parent predictions for id " * id * " session " * session)
println("Run took ", Dates.canonicalize(Dates.CompoundPeriod(now()-run_start)))

