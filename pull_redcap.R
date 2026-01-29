args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  #stop("You must provide a filename argument", call. = FALSE)
  # Interaction for testing
  id <- 18
  session <-  1
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

ds <- redcap_read_oneshot(redcap_uri = uri, token = api_token, forms = c("session_notes"), guess_type = F) %>% 
  .[["data"]] %>% select(study_id, redcap_event_name, time_gopro_start:cg_off_5_reason) %>% 
  filter(id == study_id, redcap_event_name == session_string)

if (nrow(ds) == 0) {
  print(str_glue("No REDCap data found -- correct and re-run the script"))
} else {
  dir.create(str_c(id,session,sep = "_"))
  write_csv(ds, str_glue("{id}_{session}/session_info.csv"))
  print(str_glue("Successfully wrote session_info.csv to {id}_{session}/"))
}


