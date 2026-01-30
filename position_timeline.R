args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  print("No id or session supplied; using test parameters instead")
  # Interaction for testing
  id <- 18
  session <-  1
} else {
  id <- args[1]
  session <- args[2]
}

library(tidyverse)
library(hms)
library(scales)

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

lims <- as_hms(c('08:00:00', '21:59:00'))
hour_breaks = as_hms(c('09:00:00', '10:00:00', '11:00:00', '12:00:00', '13:00:00', '14:00:00', '15:00:00', '16:00:00', '17:00:00', '18:00:00', '19:00:00', '20:00:00', '21:00:00'))
label_breaks = c("9am","","11am","","1pm","","3pm","","5pm","","7pm","","9pm")
pal <-  c("#F0E442","#009E73","#56B4E9", "#E69F00","#0072B2") %>%  set_names(c("Standing", "Sitting", "Prone", "Supine", "Held"))

sync_filt %>% mutate(pos = ifelse(pos == "Upright", "Standing", pos),
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
ggsave(str_glue("{id}_{session}/position_timeline.pdf"), width = 10, height = 4)
  