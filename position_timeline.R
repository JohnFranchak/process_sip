args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  print("No id or session supplied; using test parameters instead")
  # Interaction for testing
  id <- 16
  session <-  2
} else {
  id <- args[1]
  session <- args[2]
}

library(tidyverse)
library(hms)
library(scales)
library(REDCapR)
library(patchwork)

uri <- "https://redcap.ucr.edu/api/"
source("api_token.R")

theme_update(text = element_text(size = 12),
             axis.text.x = element_text(size = 12, color = "black"), 
             axis.title.x = element_text(size = 14),
             axis.text.y = element_text(size = 12,  color = "black"), 
             axis.title.y = element_text(size = 14), 
             panel.background = element_blank(),panel.border = element_blank(), 
             panel.grid.major = element_blank(),
             panel.grid.minor = element_blank(), axis.line = element_blank(), 
             axis.ticks.length=unit(.25, "cm"), 
             legend.key = element_rect(fill = "white")) 

predictions <- read_csv(str_glue("{id}_{session}/infant_position_predictions_4s.csv")) %>% rename(time = time_start)
windows <- read_csv(str_glue("{id}_{session}/windows_4s.csv"))  %>% 
  rename(time = temp_time) %>% 
  select(-(time_sec:time_sec3))
sync <- left_join(predictions, windows)
sync$id = id
sync$time_plot <- as_hms(force_tz(sync$time, "America/Los_Angeles"))

sync_filt <- sync %>% filter(nap_period == 0, exclude_period == 0)

session_string  <-  as.character(factor(session, levels = 1:4, labels = c("visit_1_arm_1", "visit_2_arm_1", "visit_3_arm_1", "visit_4_arm_1")))
# ema <- redcap_read_oneshot(redcap_uri = uri, token = api_token, records = id, forms = c("hour_activity"), guess_type = F) %>% 
#   .[["data"]] 

events <- redcap_event_instruments(redcap_uri = uri, token = api_token)$data
events <- events %>% filter(str_detect(unique_event_name, str_glue("visit_{session}")),
                            form == "hour_activity") %>% pull(unique_event_name)
ema <- redcap_read(redcap_uri = uri, token = api_token, events = events, records = id, forms = "hour_activity")$data %>% 
  filter(str_detect(redcap_event_name, "test", negate = T))
hour_midpoints <- as_hms(c('07:30:00','08:30:00','09:30:00', '10:30:00', '11:30:00', '12:30:00', '13:30:00', '14:30:00', '15:30:00', '16:30:00', '17:30:00', '18:30:00', '19:30:00'))
ema$time <- hour_midpoints
# %>% select(study_id, redcap_event_name, time_gopro_start:cg_off_5_reason) %>% 
#   filter(id == study_id, redcap_event_name == session_string)

lims <- as_hms(c('07:00:00', '21:59:00'))
hour_breaks = as_hms(c('07:00:00','08:00:00','09:00:00', '10:00:00', '11:00:00', '12:00:00', '13:00:00', '14:00:00', '15:00:00', '16:00:00', '17:00:00', '18:00:00', '19:00:00', '20:00:00', '21:00:00'))
label_breaks = c("7am","","9am","","11am","","1pm","","3pm","","5pm","","7pm","","9pm")

ema_plot <- ema %>% select(time, hour_nap, play_inside, nurse) %>% 
  pivot_longer(cols = hour_nap:nurse, names_to = "Activity", values_to = "Minutes")

p1 <- ema_plot %>% mutate(Activity = factor(Activity, 
                                      levels=c("hour_nap", "play_inside", "nurse"),
                                      labels=c("Nap", "Play", "Eat/Drink/Nurse"))) %>% 
  ggplot(aes(x = time, y = Minutes, color = Activity)) + 
  geom_line() + geom_point() + 
  scale_x_time(breaks = hour_breaks, name = "", limits = lims, labels = label_breaks) + 
  theme(legend.position = "top",
        axis.title.x = element_blank(),
        axis.text.x = element_blank(),
        axis.ticks.x = element_blank()) + ylim(0,60)


pal <-  c("#F0E442","#009E73","#56B4E9", "#E69F00","#0072B2") %>%  set_names(c("Standing", "Sitting", "Prone", "Supine", "Held"))

p2 <- sync_filt %>% mutate(pos = ifelse(pos == "Upright", "Standing", pos),
                   pos = factor(pos, levels=c("Supine", "Prone", "Sitting", "Standing", "Held"))) %>% 
  ggplot(aes(x = time_plot, y = 1, fill = pos)) + 
  geom_raster() + scale_fill_manual(values = pal, name = "") + 
  facet_wrap(~id, ncol = 1, scales = "free_x", strip.position = "left") +
  scale_x_time(breaks = hour_breaks, name = "", limits = lims, labels = label_breaks) + 
  theme(
    axis.title.y = element_blank(),
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank(),
    strip.text = element_blank(),
    legend.position = "bottom"
  ) 

p1/p2
ggsave(str_glue("{id}_{session}/position_timeline.pdf"), width = 10, height = 6)
  