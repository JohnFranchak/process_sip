library(tidyverse)
removeQuotes <- function(x) gsub("\"", "", x)

id <- 18
session <-  1

# FIGURE OUT SYNC TIMES
sync_time <- read_csv(str_glue("{id}_{session}/session_info.csv"), 
                      col_types = cols(.default = "c"))
col_names <- c("time", "acc_x","acc_y", "acc_z", "gyr_x", "gyr_y","gyr_z")

sync_time$sync_time_la <- sync_time$sync_point_matlab
sync_time$sync_time_lh <- "2026-01-21 09:37:40.360"
sync_time$sync_time_ra <- "2026-01-21 09:37:35.018"
sync_time$sync_time_rh <- "2026-01-21 09:37:35.018"

diff_lh <- as_datetime(sync_time$sync_time_la) - as_datetime(sync_time$sync_time_lh)
diff_ra <- as_datetime(sync_time$sync_time_la) - as_datetime(sync_time$sync_time_ra)
diff_rh <- as_datetime(sync_time$sync_time_la) - as_datetime(sync_time$sync_time_rh)
# THESE SHOULD BE TRUE
# (as_datetime(sync_time$sync_time_lh[1]) + diff_lh) == as_datetime(sync_time$sync_time_la[1])
# (as_datetime(sync_time$sync_time_ra[1]) + diff_ra) == as_datetime(sync_time$sync_time_la[1])
# (as_datetime(sync_time$sync_time_rh[1]) + diff_rh) == as_datetime(sync_time$sync_time_la[1])

dsla <- read_csv(str_glue("{id}_LA.csv"), col_names)
dsla$time <- force_tz(dsla$time, "America/Los_Angeles")
dsla <- mutate(dsla, across(contains("acc"), ~ ifelse(.x > 4, 4, .x)),
             across(contains("acc"), ~ ifelse(.x < -4, 4, .x))) %>% 
  mutate(acc_x = acc_x*-1, acc_z = acc_z*-1) %>% 
  mutate(gyr_x = gyr_x*-1, gyr_z = gyr_z*-1)
dsla$time_sync <- dsla$time

dsra <- read_csv(str_glue("{id}_RA.csv"), col_names)
dsra$time <- force_tz(dsra$time, "America/Los_Angeles")
dsra <- mutate(dsra, across(contains("acc"), ~ ifelse(.x > 4, 4, .x)),
               across(contains("acc"), ~ ifelse(.x < -4, 4, .x))) %>% 
  mutate(acc_x = acc_x*-1, acc_z = acc_z*-1) %>% 
  mutate(gyr_x = gyr_x*-1, gyr_z = gyr_z*-1)
dsra$time_sync <- dsra$time + diff_ra

dslh <- read_csv(str_glue("{id}_LH.csv"), col_names)
dslh$time <- force_tz(dslh$time, "America/Los_Angeles")
dslh <- mutate(dslh, across(contains("acc"), ~ ifelse(.x > 4, 4, .x)),
               across(contains("acc"), ~ ifelse(.x < -4, 4, .x))) %>% 
  mutate(acc_x = acc_x*-1, acc_z = acc_z*-1) %>% 
  mutate(gyr_x = gyr_x*-1, gyr_z = gyr_z*-1)
dslh$time_sync <- dslh$time + diff_lh

dsrh <- read_csv(str_glue("{id}_RH.csv"), col_names)
dsrh$time <- force_tz(dsrh$time, "America/Los_Angeles")
dsrh <- mutate(dsrh, across(contains("acc"), ~ ifelse(.x > 4, 4, .x)),
               across(contains("acc"), ~ ifelse(.x < -4, 4, .x))) %>% 
  mutate(acc_x = acc_x*-1, acc_z = acc_z*-1) %>% 
  mutate(gyr_x = gyr_x*-1, gyr_z = gyr_z*-1)
dsrh$time_sync <- dsrh$time + diff_rh

# window_start <- force_tz(as_datetime(sync_time$sync_time_la),"America/Los_Angeles")
# window_end <- window_start + seconds(60)
# ggplot() + 
#   geom_line(data = filter(dsra, time_sync > window_start, time_sync < window_end), aes(x = time_sync, y = acc_x), color = "black",  alpha = .3) + 
#   geom_line(data = filter(dsla, time_sync > window_start, time_sync < window_end), aes(x = time_sync, y = acc_x), color = "red", alpha = .3) +
#   geom_line(data = filter(dsrh, time_sync > window_start, time_sync < window_end), aes(x = time_sync, y = acc_x), color = "green",  alpha = .3) + 
#   geom_line(data = filter(dslh, time_sync > window_start, time_sync < window_end), aes(x = time_sync, y = acc_x), color = "blue", alpha = .3) 


test_date <- as.character(as_date(force_tz(as_datetime(sync_time$sync_time_lh),"America/Los_Angeles")))
start_time <- str_glue("{test_date} {sync_time$time_leg_on}:00")
start_time <- force_tz(as_datetime(start_time),"America/Los_Angeles")

end_time <- str_glue("{test_date} {sync_time$time_leg_off}:00")
end_time <- force_tz(as_datetime(end_time),"America/Los_Angeles")

# Turn into something we can analyze in Julia
dsra <- dsra %>% filter(time_sync >= start_time, time_sync < end_time)
dsla <- dsla %>% filter(time_sync >= start_time, time_sync < end_time)
dsrh <- dsrh %>% filter(time_sync >= start_time, time_sync < end_time)
dslh <- dslh %>% filter(time_sync >= start_time, time_sync < end_time)

dsla %>% mutate(time = as.numeric(time_sync)) %>% select(-time_sync) %>% 
  write_csv(str_glue("{id}_{session}/left_ankle_synced.csv"))
dsra %>% mutate(time = as.numeric(time_sync)) %>% select(-time_sync) %>% 
  write_csv(str_glue("{id}_{session}/right_ankle_synced.csv"))
dslh %>% mutate(time = as.numeric(time_sync)) %>% select(-time_sync) %>% 
  write_csv(str_glue("{id}_{session}/left_hip_synced.csv"))
dsrh %>% mutate(time = as.numeric(time_sync)) %>% select(-time_sync) %>% 
  write_csv(str_glue("{id}_{session}/right_hip_synced.csv"))

