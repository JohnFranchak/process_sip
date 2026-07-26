args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  print("No id or session supplied; using test parameters instead")
  # Interaction for testing
  id <- 37
  session <-  2
} else {
  id <- args[1]
  session <- args[2]
}

library(tidyverse)
library(REDCapR)

uri <- "https://redcap.ucr.edu/api/"
source("api_token.R")

session_string  <-  as.character(factor(session, levels = 1:4, labels = c("visit_1_arm_1", "visit_2_arm_1", "visit_3_arm_1", "visit_4_arm_1")))

print(str_glue("Pulling REDCap data for {id} {session_string}"))

ds <- redcap_read(redcap_uri = uri, token = api_token, records = id, events = session_string, forms = c("session_notes"), guess_type = F) %>% 
  .[["data"]] %>% select(study_id, redcap_event_name, time_gopro_start:cg_off_6_reason)

if (nrow(ds) == 0) {
  print(str_glue("No REDCap data found -- correct and re-run the script"))
} else {
  dir.create(str_c(id,session,sep = "_"))
  write_csv(ds, str_glue("{id}_{session}/session_info.csv"))
  print(str_glue("Successfully wrote session_info.csv to {id}_{session}/"))
}

ds_multiday <- redcap_read(redcap_uri = uri, records = id, events = session_string, token = api_token, 
                           forms = c("day2_notes","day3_notes"), guess_type = F) %>% 
  .[["data"]] 
if (ds_multiday$use_day_2___1 == 1 | ds_multiday$use_day_3___1 == 1) {
  write_csv(ds_multiday, str_glue("{id}_{session}/multiday_info.csv"))
  print("Found multi-day information in REDCap")
}


