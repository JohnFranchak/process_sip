using Pkg
# Activate the folder where this script lives
Pkg.activate(@__DIR__)

using CSV, DataFrames, Dates, DataFrameMacros, Chain, Statistics, TimeZones, StatsBase
using CategoricalArrays, DecisionTree, JLD2
using Pipe: @pipe

println("Running in environment: ", Base.active_project())

if length(ARGS) > 0
    println("Creating motion features for id " * ARGS[1] * " session " * ARGS[2])
    const id = ARGS[1]
    const session = ARGS[2]
else
    # For interactive testing
    const id = "13"
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
function imu_file(;side, loc, suffix)
    file = id * "_" * session * "/" * side * "_" * loc * suffix * "_synced.csv"
    println(file)
    short_code = side[1] * loc[1]
    temp = CSV.read(file, DataFrame; header=["time",short_code*"accx",short_code*"accy",short_code*"accz",short_code*"gyrx",short_code*"gyry",short_code*"gyrz"], skipto=2)
    @transform!(temp, :time = fix_tz(:time) + Hour(adjust_dst))
    #subset!(temp, :time => t -> t .>= start_time .&& t .<= end_time)
    assign(; s = short_code,v = temp)
end

const sides = ["left" "right" "left" "right"]
const locs = ["hip" "hip" "ankle" "ankle"]
##
for i in eachindex(sides)
    imu_file(; side=sides[i], loc=locs[i], suffix)
end


ds = @pipe outerjoin(la, ra, on = :time) |> 
    outerjoin(_, lh, on = :time) |>
    outerjoin(_, rh, on = :time) 

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

# Define all of the summary functions
# sensor sum 
function calc_sensor_mean(data, label)
    temp = @combine(@groupby(data, :time_sec0), begin
        :laacc = mean({{r"laacc"}})
        :raacc = mean({{r"raacc"}})
        :lhacc = mean({{r"lhacc"}})
        :rhacc = mean({{r"rhacc"}})
        :lagyr = mean({{r"lagyr"}})
        :ragyr = mean({{r"ragyr"}})
        :lhgyr = mean({{r"lhgyr"}})
        :rhgyr = mean({{r"rhgyr"}})
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
    :laaccx_cor_laaccy = cor(:laaccx, :laaccy)
    :laaccy_cor_laaccz = cor(:laaccy, :laaccz)
    :laaccx_cor_laaccz = cor(:laaccx, :laaccz)
    :lhaccx_cor_lhaccy = cor(:lhaccx, :lhaccy)
    :lhaccy_cor_lhaccz = cor(:lhaccy, :lhaccz)
    :lhaccx_cor_lhaccz = cor(:lhaccx, :lhaccz)
    :raaccx_cor_raaccy = cor(:raaccx, :raaccy)
    :raaccy_cor_raaccz = cor(:raaccy, :raaccz)
    :raaccx_cor_raaccz = cor(:raaccx, :raaccz)
    :rhaccx_cor_rhaccy = cor(:rhaccx, :rhaccy)
    :rhaccy_cor_rhaccz = cor(:rhaccy, :rhaccz)
    :rhaccx_cor_rhaccz = cor(:rhaccx, :rhaccz)
    :lagyrx_cor_lagyry = cor(:lagyrx, :lagyry)
    :lagyry_cor_lagyrz = cor(:lagyry, :lagyrz)
    :lagyrx_cor_lagyrz = cor(:lagyrx, :lagyrz)
    :lhgyrx_cor_lhgyry = cor(:lhgyrx, :lhgyry)
    :lhgyry_cor_lhgyrz = cor(:lhgyry, :lhgyrz)
    :lhgyrx_cor_lhgyrz = cor(:lhgyrx, :lhgyrz)
    :ragyrx_cor_ragyry = cor(:ragyrx, :ragyry)
    :ragyry_cor_ragyrz = cor(:ragyry, :ragyrz)
    :ragyrx_cor_ragyrz = cor(:ragyrx, :ragyrz)
    :rhgyrx_cor_rhgyry = cor(:rhgyrx, :rhgyry)
    :rhgyry_cor_rhgyrz = cor(:rhgyry, :rhgyrz)
    :rhgyrx_cor_rhgyrz = cor(:rhgyrx, :rhgyrz)
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
    :laaccx_cor_raaccx = cor(:laaccx, :raaccx)
    :laaccx_cor_lhaccx = cor(:laaccx, :lhaccx)
    :laaccx_cor_rhaccx = cor(:laaccx, :rhaccx)
    :raaccx_cor_lhaccx = cor(:raaccx, :lhaccx)
    :raaccx_cor_rhaccx = cor(:raaccx, :rhaccx)
    :lhaccx_cor_rhaccx = cor(:lhaccx, :rhaccx)
    :laaccy_cor_raaccy = cor(:laaccy, :raaccy)
    :laaccy_cor_lhaccy = cor(:laaccy, :lhaccy)
    :laaccy_cor_rhaccy = cor(:laaccy, :rhaccy)
    :raaccy_cor_lhaccy = cor(:raaccy, :lhaccy)
    :raaccy_cor_rhaccy = cor(:raaccy, :rhaccy)
    :lhaccy_cor_rhaccy = cor(:lhaccy, :rhaccy)
    :laaccz_cor_raaccz = cor(:laaccz, :raaccz)
    :laaccz_cor_lhaccz = cor(:laaccz, :lhaccz)
    :laaccz_cor_rhaccz = cor(:laaccz, :rhaccz)
    :raaccz_cor_lhaccz = cor(:raaccz, :lhaccz)
    :raaccz_cor_rhaccz = cor(:raaccz, :rhaccz)
    :lhaccz_cor_rhaccz = cor(:lhaccz, :rhaccz)
    :lagyrx_cor_ragyrx = cor(:lagyrx, :ragyrx)
    :lagyrx_cor_lhgyrx = cor(:lagyrx, :lhgyrx)
    :lagyrx_cor_rhgyrx = cor(:lagyrx, :rhgyrx)
    :ragyrx_cor_lhgyrx = cor(:ragyrx, :lhgyrx)
    :ragyrx_cor_rhgyrx = cor(:ragyrx, :rhgyrx)
    :lhgyrx_cor_rhgyrx = cor(:lhgyrx, :rhgyrx)
    :lagyry_cor_ragyry = cor(:lagyry, :ragyry)
    :lagyry_cor_lhgyry = cor(:lagyry, :lhgyry)
    :lagyry_cor_rhgyry = cor(:lagyry, :rhgyry)
    :ragyry_cor_lhgyry = cor(:ragyry, :lhgyry)
    :ragyry_cor_rhgyry = cor(:ragyry, :rhgyry)
    :lhgyry_cor_rhgyry = cor(:lhgyry, :rhgyry)
    :lagyrz_cor_ragyrz = cor(:lagyrz, :ragyrz)
    :lagyrz_cor_lhgyrz = cor(:lagyrz, :lhgyrz)
    :lagyrz_cor_rhgyrz = cor(:lagyrz, :rhgyrz)
    :ragyrz_cor_lhgyrz = cor(:ragyrz, :lhgyrz)
    :ragyrz_cor_rhgyrz = cor(:ragyrz, :rhgyrz)
    :lhgyrz_cor_rhgyrz = cor(:lhgyrz, :rhgyrz)
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
    :laaccx_diff_laaccy = mean(:laaccx - :laaccy)
    :laaccy_diff_laaccz = mean(:laaccy - :laaccz)
    :laaccx_diff_laaccz = mean(:laaccx - :laaccz)
    :lhaccx_diff_lhaccy = mean(:lhaccx - :lhaccy)
    :lhaccy_diff_lhaccz = mean(:lhaccy - :lhaccz)
    :lhaccx_diff_lhaccz = mean(:lhaccx - :lhaccz)
    :raaccx_diff_raaccy = mean(:raaccx - :raaccy)
    :raaccy_diff_raaccz = mean(:raaccy - :raaccz)
    :raaccx_diff_raaccz = mean(:raaccx - :raaccz)
    :rhaccx_diff_rhaccy = mean(:rhaccx - :rhaccy)
    :rhaccy_diff_rhaccz = mean(:rhaccy - :rhaccz)
    :rhaccx_diff_rhaccz = mean(:rhaccx - :rhaccz)
    :lagyrx_diff_lagyry = mean(:lagyrx - :lagyry)
    :lagyry_diff_lagyrz = mean(:lagyry - :lagyrz)
    :lagyrx_diff_lagyrz = mean(:lagyrx - :lagyrz)
    :lhgyrx_diff_lhgyry = mean(:lhgyrx - :lhgyry)
    :lhgyry_diff_lhgyrz = mean(:lhgyry - :lhgyrz)
    :lhgyrx_diff_lhgyrz = mean(:lhgyrx - :lhgyrz)
    :ragyrx_diff_ragyry = mean(:ragyrx - :ragyry)
    :ragyry_diff_ragyrz = mean(:ragyry - :ragyrz)
    :ragyrx_diff_ragyrz = mean(:ragyrx - :ragyrz)
    :rhgyrx_diff_rhgyry = mean(:rhgyrx - :rhgyry)
    :rhgyry_diff_rhgyrz = mean(:rhgyry - :rhgyrz)
    :rhgyrx_diff_rhgyrz = mean(:rhgyrx - :rhgyrz)
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
    :laaccx_diff_raaccx = mean(:laaccx - :raaccx)
    :laaccx_diff_lhaccx = mean(:laaccx - :lhaccx)
    :laaccx_diff_rhaccx = mean(:laaccx - :rhaccx)
    :raaccx_diff_lhaccx = mean(:raaccx - :lhaccx)
    :raaccx_diff_rhaccx = mean(:raaccx - :rhaccx)
    :lhaccx_diff_rhaccx = mean(:lhaccx - :rhaccx)
    :laaccy_diff_raaccy = mean(:laaccy - :raaccy)
    :laaccy_diff_lhaccy = mean(:laaccy - :lhaccy)
    :laaccy_diff_rhaccy = mean(:laaccy - :rhaccy)
    :raaccy_diff_lhaccy = mean(:raaccy - :lhaccy)
    :raaccy_diff_rhaccy = mean(:raaccy - :rhaccy)
    :lhaccy_diff_rhaccy = mean(:lhaccy - :rhaccy)
    :laaccz_diff_raaccz = mean(:laaccz - :raaccz)
    :laaccz_diff_lhaccz = mean(:laaccz - :lhaccz)
    :laaccz_diff_rhaccz = mean(:laaccz - :rhaccz)
    :raaccz_diff_lhaccz = mean(:raaccz - :lhaccz)
    :raaccz_diff_rhaccz = mean(:raaccz - :rhaccz)
    :lhaccz_diff_rhaccz = mean(:lhaccz - :rhaccz)
    :lagyrx_diff_ragyrx = mean(:lagyrx - :ragyrx)
    :lagyrx_diff_lhgyrx = mean(:lagyrx - :lhgyrx)
    :lagyrx_diff_rhgyrx = mean(:lagyrx - :rhgyrx)
    :ragyrx_diff_lhgyrx = mean(:ragyrx - :lhgyrx)
    :ragyrx_diff_rhgyrx = mean(:ragyrx - :rhgyrx)
    :lhgyrx_diff_rhgyrx = mean(:lhgyrx - :rhgyrx)
    :lagyry_diff_ragyry = mean(:lagyry - :ragyry)
    :lagyry_diff_lhgyry = mean(:lagyry - :lhgyry)
    :lagyry_diff_rhgyry = mean(:lagyry - :rhgyry)
    :ragyry_diff_lhgyry = mean(:ragyry - :lhgyry)
    :ragyry_diff_rhgyry = mean(:ragyry - :rhgyry)
    :lhgyry_diff_rhgyry = mean(:lhgyry - :rhgyry)
    :lagyrz_diff_ragyrz = mean(:lagyrz - :ragyrz)
    :lagyrz_diff_lhgyrz = mean(:lagyrz - :lhgyrz)
    :lagyrz_diff_rhgyrz = mean(:lagyrz - :rhgyrz)
    :ragyrz_diff_lhgyrz = mean(:ragyrz - :lhgyrz)
    :ragyrz_diff_rhgyrz = mean(:ragyrz - :rhgyrz)
    :lhgyrz_diff_rhgyrz = mean(:lhgyrz - :rhgyrz)
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


#Get sliding windows
ds = dropmissing(ds)
temp_time = ds.time
time_sec = datetime2unix.(temp_time) .- datetime2unix.(temp_time[1])
const time_sec0 = Int64.(round.(time_sec./4))
const time_sec1 = Int64.(round.((time_sec.+1)./4))
const time_sec2 = Int64.(round.((time_sec.+2)./4))
const time_sec3 = Int64.(round.((time_sec.+3)./4))

windows = DataFrame(temp_time = temp_time, time_sec = time_sec, time_sec0 =  time_sec0,  time_sec1 = time_sec1,  time_sec2 = time_sec2,  time_sec3 = time_sec3)
##
# Read nap and exclude times
file = id * "_" * session * "/session_info.csv"
anno = CSV.read(file, DataFrame; missingstring = "NA")

@chain anno begin
    @transform! :time_nap_1_start = Date(windows.temp_time[1]) + :time_nap_1_start
    @transform! :time_nap_1_end = Date(windows.temp_time[1]) + :time_nap_1_end
    @transform! :time_nap_2_start = Date(windows.temp_time[1]) + :time_nap_2_start
    @transform! :time_nap_2_end = Date(windows.temp_time[1]) + :time_nap_2_end
    @transform! :time_nap_3_start = Date(windows.temp_time[1]) + :time_nap_3_start
    @transform! :time_nap_3_end = Date(windows.temp_time[1]) + :time_nap_3_end
    @transform! :time_nap_4_start = Date(windows.temp_time[1]) + :time_nap_4_start
    @transform! :time_nap_4_end = Date(windows.temp_time[1]) + :time_nap_4_end
    @transform! :time_nap_5_start = Date(windows.temp_time[1]) + :time_nap_5_start
    @transform! :time_nap_5_end = Date(windows.temp_time[1]) + :time_nap_5_end
    @transform! :time_nap_6_start = Date(windows.temp_time[1]) + :time_nap_6_start
    @transform! :time_nap_6_end = Date(windows.temp_time[1]) + :time_nap_6_end
    @transform! :time_off_1_start = Date(windows.temp_time[1]) + :time_off_1_start
    @transform! :time_off_1_end = Date(windows.temp_time[1]) + :time_off_1_end
    @transform! :time_off_2_start = Date(windows.temp_time[1]) + :time_off_2_start
    @transform! :time_off_2_end = Date(windows.temp_time[1]) + :time_off_2_end
    @transform! :time_off_3_start = Date(windows.temp_time[1]) + :time_off_3_start
    @transform! :time_off_3_end = Date(windows.temp_time[1]) + :time_off_3_end
    @transform! :time_off_4_start = Date(windows.temp_time[1]) + :time_off_4_start
    @transform! :time_off_4_end = Date(windows.temp_time[1]) + :time_off_4_end
    @transform! :time_off_5_start = Date(windows.temp_time[1]) + :time_off_5_start
    @transform! :time_off_5_end = Date(windows.temp_time[1]) + :time_off_5_end
    @transform! :time_off_6_start = Date(windows.temp_time[1]) + :time_off_6_start
    @transform! :time_off_6_end = Date(windows.temp_time[1]) + :time_off_6_end
    @transform! :time_off_7_start = Date(windows.temp_time[1]) + :time_off_7_start
    @transform! :time_off_7_end = Date(windows.temp_time[1]) + :time_off_7_end
    @transform! :time_off_8_start = Date(windows.temp_time[1]) + :time_off_8_start
    @transform! :time_off_8_end = Date(windows.temp_time[1]) + :time_off_8_end
    @transform! :time_off_9_start = Date(windows.temp_time[1]) + :time_off_9_start
    @transform! :time_off_9_end = Date(windows.temp_time[1]) + :time_off_9_end
    @transform! :time_off_10_start = Date(windows.temp_time[1]) + :time_off_10_start
    @transform! :time_off_10_end = Date(windows.temp_time[1]) + :time_off_10_end
    @transform! :time_leg_on = Date(windows.temp_time[1]) + :time_leg_on
    @transform! :time_leg_off = Date(windows.temp_time[1]) + :time_leg_off
end

windows[!, :time_leg_on] .= anno.time_leg_on[1]
windows[!, :time_leg_off] .= anno.time_leg_off[1]

nap_starts = dropmissing(stack(select(select(anno, r"nap"),r"start"),1:6))
nap_ends = dropmissing(stack(select(select(anno, r"nap"),r"end"),1:6))
windows[!, :nap_period] .= 0
if  nrow(nap_starts) > 0
     for i in axes(nap_starts,1)
         @transform!(windows, @subset(:temp_time >= nap_starts.value[i] && :temp_time <= nap_ends.value[i]), :nap_period = 1)
     end
end

exclude_starts = dropmissing(stack(select(select(select(anno, r"off"),r"start"),r"time"),1:10))
exclude_ends = dropmissing(stack(select(select(select(anno, r"off"),r"end"),r"time"),1:10))
windows[!, :exclude_period] .= 0
if  nrow(exclude_starts) > 0
     for i in axes(exclude_starts,1)
         @transform!(windows, @subset(:temp_time >= exclude_starts.value[i] && :temp_time <= exclude_ends.value[i]), :exclude_period = 1)
     end
end

##
CSV.write(id * "_" * session *"/" * "windows_4s.csv", windows)

ds.time_sec0 = time_sec0
slide0 = slide_calc(ds)
ds.time_sec0 = time_sec1
slide1 = slide_calc(ds)
ds.time_sec0 = time_sec2
slide2 = slide_calc(ds)
ds.time_sec0 = time_sec3
slide3 = slide_calc(ds)

slide = vcat(slide0, slide1, slide2, slide3)
#slide = vcat(slide1, slide3)
sort!(slide, :time_start)
@subset!(slide, :time_sec0 > 1)
select!(slide, Not(:time_sec0))
CSV.write(id * "_" * session *"/" * "mot_features_infant_4s.csv", slide)

@select!(windows, :temp_time)

ds_out = select(slide, :time_start)
leftjoin!(ds_out, windows, on = :time_start => :temp_time)

# PREDICT FROM MODEL
model = load_object("group_model_TDCP.jld2")
features = Matrix(dropmissing(slide[:,Not(["time_start"])]))
ds_out.pos = DecisionTree.predict(model, features)

# WRITE CSV
CSV.write(id * "_" * session * "/" * "infant_position_predictions_4s.csv", ds_out)

println("Wrote windows, motion features, and infant predictions for id " * id * " session " * session)
println("Run took ", Dates.canonicalize(Dates.CompoundPeriod(now()-run_start)))

