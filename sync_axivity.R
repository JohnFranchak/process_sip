args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  print("No id or session supplied; using test parameters instead")
  id <- 13
  session <-  2
} else {
  id <- args[1]
  session <- args[2]
}

library(tidyverse)

# FIGURE OUT SYNC TIMES
sync_time <- read_csv(str_glue("{id}_{session}/session_info.csv"), 
                      col_types = cols(.default = "c"))
col_names <- c("time", "acc_x","acc_y", "acc_z", "gyr_x", "gyr_y","gyr_z")

diff_lh <- as_datetime(sync_time$sync_point_la) - as_datetime(sync_time$sync_point_lh)
diff_ra <- as_datetime(sync_time$sync_point_la) - as_datetime(sync_time$sync_point_ra)
diff_rh <- as_datetime(sync_time$sync_point_la) - as_datetime(sync_time$sync_point_rh)
diff_cw <- as_datetime(sync_time$sync_point_la) - as_datetime(sync_time$sync_point_cw)
diff_ch <- as_datetime(sync_time$sync_point_la) - as_datetime(sync_time$sync_point_ch)
test1 <- (as_datetime(sync_time$sync_point_lh[1]) + diff_lh) == as_datetime(sync_time$sync_point_la[1])
test2 <- (as_datetime(sync_time$sync_point_ra[1]) + diff_ra) == as_datetime(sync_time$sync_point_la[1])
test3 <- (as_datetime(sync_time$sync_point_rh[1]) + diff_rh) == as_datetime(sync_time$sync_point_la[1])
test4 <- (as_datetime(sync_time$sync_point_ch[1]) + diff_ch) == as_datetime(sync_time$sync_point_la[1])
test5 <- (as_datetime(sync_time$sync_point_cw[1]) + diff_cw) == as_datetime(sync_time$sync_point_la[1])

if (test1 & test2 & test3 & test4 & test5) {
  print("IMU signals successfully synchronized")
} else {
  print("IMU synchronization problem; abort and correct")
}

dsla <- read_csv(str_glue("{id}_LA.csv"), col_names, show_col_types = FALSE)
dsla$time <- force_tz(dsla$time, "America/Los_Angeles")
dsla <- mutate(dsla, across(contains("acc"), ~ ifelse(.x > 4, 4, .x)),
             across(contains("acc"), ~ ifelse(.x < -4, 4, .x))) %>% 
  mutate(acc_x = acc_x*-1, acc_z = acc_z*-1) %>% 
  mutate(gyr_x = gyr_x*-1, gyr_z = gyr_z*-1)
dsla$time_sync <- dsla$time

dsra <- read_csv(str_glue("{id}_RA.csv"), col_names, show_col_types = FALSE)
dsra$time <- force_tz(dsra$time, "America/Los_Angeles")
dsra <- mutate(dsra, across(contains("acc"), ~ ifelse(.x > 4, 4, .x)),
               across(contains("acc"), ~ ifelse(.x < -4, 4, .x))) %>% 
  mutate(acc_x = acc_x*-1, acc_z = acc_z*-1) %>% 
  mutate(gyr_x = gyr_x*-1, gyr_z = gyr_z*-1)
dsra$time_sync <- dsra$time + diff_ra

dslh <- read_csv(str_glue("{id}_LH.csv"), col_names, show_col_types = FALSE)
dslh$time <- force_tz(dslh$time, "America/Los_Angeles")
dslh <- mutate(dslh, across(contains("acc"), ~ ifelse(.x > 4, 4, .x)),
               across(contains("acc"), ~ ifelse(.x < -4, 4, .x))) %>% 
  mutate(acc_x = acc_x*-1, acc_z = acc_z*-1) %>% 
  mutate(gyr_x = gyr_x*-1, gyr_z = gyr_z*-1)
dslh$time_sync <- dslh$time + diff_lh

dsrh <- read_csv(str_glue("{id}_RH.csv"), col_names, show_col_types = FALSE)
dsrh$time <- force_tz(dsrh$time, "America/Los_Angeles")
dsrh <- mutate(dsrh, across(contains("acc"), ~ ifelse(.x > 4, 4, .x)),
               across(contains("acc"), ~ ifelse(.x < -4, 4, .x))) %>% 
  mutate(acc_x = acc_x*-1, acc_z = acc_z*-1) %>% 
  mutate(gyr_x = gyr_x*-1, gyr_z = gyr_z*-1)
dsrh$time_sync <- dsrh$time + diff_rh

dsch <- read_csv(str_glue("{id}_CH.csv"), col_names, show_col_types = FALSE)
dsch$time <- force_tz(dsch$time, "America/Los_Angeles")
dsch$time_sync <- dsch$time + diff_ch

dscw <- read_csv(str_glue("{id}_CW.csv"), col_names, show_col_types = FALSE)
dscw$time <- force_tz(dscw$time, "America/Los_Angeles")
dscw$time_sync <- dscw$time + diff_cw

# Flip leggings if needed
if (str_glue("{id}_{session}") %in% c("13_2")) {
  dsla$acc_y <- dsla$acc_y*-1
  dsla$gyr_y <- dsla$gyr_y*-1
  dsla$acc_z <- dsla$acc_z*-1
  dsla$gyr_z <- dsla$gyr_z*-1
  dsra$acc_y <- dsra$acc_y*-1
  dsra$gyr_y <- dsra$gyr_y*-1
  dsra$acc_z <- dsra$acc_z*-1
  dsra$gyr_z <- dsra$gyr_z*-1
  dslh$acc_y <- dslh$acc_y*-1
  dslh$gyr_y <- dslh$gyr_y*-1
  dslh$acc_z <- dslh$acc_z*-1
  dslh$gyr_z <- dslh$gyr_z*-1
  dsrh$acc_y <- dsrh$acc_y*-1
  dsrh$gyr_y <- dsrh$gyr_y*-1
  dsrh$acc_z <- dsrh$acc_z*-1
  dsrh$gyr_z <- dsrh$gyr_z*-1
  print("********Flipping Y and Z axes")
}


# window_start <- force_tz(as_datetime(sync_time$sync_point_la),"America/Los_Angeles")
# window_end <- window_start + seconds(60)
# ggplot() +
#   geom_line(data = filter(dsra, time_sync > window_start, time_sync < window_end), aes(x = time_sync, y = acc_x), color = "black",  alpha = .3) +
#   geom_line(data = filter(dsla, time_sync > window_start, time_sync < window_end), aes(x = time_sync, y = acc_x), color = "red", alpha = .3) +
#   geom_line(data = filter(dsrh, time_sync > window_start, time_sync < window_end), aes(x = time_sync, y = acc_x), color = "green",  alpha = .3) +
#   geom_line(data = filter(dslh, time_sync > window_start, time_sync < window_end), aes(x = time_sync, y = acc_x), color = "blue", alpha = .3) +
#   geom_line(data = filter(dsch, time_sync > window_start, time_sync < window_end), aes(x = time_sync, y = acc_x), color = "purple", alpha = .3) +
#   geom_line(data = filter(dscw, time_sync > window_start, time_sync < window_end), aes(x = time_sync, y = acc_x), color = "yellow", alpha = .3) +
#   theme_minimal()

test_date <- as.character(as_date(force_tz(as_datetime(sync_time$sync_point_lh),"America/Los_Angeles")))
start_time <- str_glue("{test_date} {sync_time$time_leg_on}:00")
start_time <- force_tz(as_datetime(start_time),"America/Los_Angeles")

end_time <- str_glue("{test_date} {sync_time$time_leg_off}:00")
end_time <- force_tz(as_datetime(end_time),"America/Los_Angeles")

print(str_glue("Read 6 IMU files; filtering data from {start_time} to {end_time}"))

# Turn into something we can analyze in Julia
dsra <- dsra %>% filter(time_sync >= start_time, time_sync < end_time)
dsla <- dsla %>% filter(time_sync >= start_time, time_sync < end_time)
dsrh <- dsrh %>% filter(time_sync >= start_time, time_sync < end_time)
dslh <- dslh %>% filter(time_sync >= start_time, time_sync < end_time)
dsch <- dsch %>% filter(time_sync >= start_time, time_sync < end_time)
dscw <- dscw %>% filter(time_sync >= start_time, time_sync < end_time)

dsla %>% mutate(time = as.numeric(time_sync)) %>% select(-time_sync) %>% 
  write_csv(str_glue("{id}_{session}/left_ankle_synced.csv"))
dsra %>% mutate(time = as.numeric(time_sync)) %>% select(-time_sync) %>% 
  write_csv(str_glue("{id}_{session}/right_ankle_synced.csv"))
dslh %>% mutate(time = as.numeric(time_sync)) %>% select(-time_sync) %>% 
  write_csv(str_glue("{id}_{session}/left_hip_synced.csv"))
dsrh %>% mutate(time = as.numeric(time_sync)) %>% select(-time_sync) %>% 
  write_csv(str_glue("{id}_{session}/right_hip_synced.csv"))
dsch %>% mutate(time = as.numeric(time_sync)) %>% select(-time_sync) %>% 
  write_csv(str_glue("{id}_{session}/caregiver_hip_synced.csv"))
dscw %>% mutate(time = as.numeric(time_sync)) %>% select(-time_sync) %>% 
  write_csv(str_glue("{id}_{session}/caregiver_wrist_synced.csv"))

print(str_glue("Successfully wrote synced IMU files to {id}_{session}/"))

