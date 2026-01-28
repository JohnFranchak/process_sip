library(tidyverse)
library(REDCapR)
library(rstatix)

uri <- "https://redcap.ucr.edu/api/"
source("api_token.R")

ds <- redcap_read_oneshot(redcap_uri = uri, token = api_token) %>% 
  .[["data"]] 

# Get completion and EMQ info for people who finished final call
completion <- ds %>% filter(redcap_event_name == "study_completion_arm_1") %>% 
  select(record_id, final_call_datetime:data_sharing_complete) %>% 
  filter(final_call_complete == 2)
emq <- ds %>% filter(redcap_event_name == "study_completion_arm_1") %>% 
  select(record_id, emqg1:emq_complete ) %>% 
  filter(record_id %in% completion$record_id)

# Get enrollment and EMA variables and demographics for complete sessions
enrollment <- ds %>% filter(redcap_event_name == "enrollment_arm_1") %>% 
  select(record_id, dust_id, dust_date, dob, age_group, due_date:comments) %>% 
  filter(record_id %in% completion$record_id)

ema <- ds %>% filter(redcap_event_name != "enrollment_arm_1" & 
                       redcap_event_name != "study_completion_arm_1") %>% 
  select(record_id, sent_time:survey_notes_complete) %>% 
  filter(record_id %in% completion$record_id)
demo <- ds %>% filter(redcap_event_name == "study_completion_arm_1") %>% 
  select(record_id, final_call_datetime:outdoor_space, -sibglings) %>% 
  filter(record_id %in% completion$record_id)

# Recode EMA fields to factors
ema <- ema %>% mutate(
  availability = factor(availability, levels = 1:3, labels = c("Infant Sleeping", "Not with Infant", "Available")),
  posture = factor(posture, levels = 1:7, labels = c("Supine", "Prone", "Sitting", "Reclined", "Upright", "Suspended","Other")),
  positioning = factor(positioning, levels = 1:8, labels = c("Device", "Adult Lap", "Adult Arms", "Worn", "Adult Support", "Furniture Support", "No Support", "Other")),
  object = factor(object, levels = 1:4, labels = c("Holding not Mouthing", "Mouthing not Holding", "Holding and Mouthing", "No Object")),
  activity = factor(activity, levels = 1:10, labels = c("Pre/Post Nap", "Feeding", "Bathing/Dressing", "Reading", "Video Call",
                                                        "Media", "Play", "Crying/Comforting", "Errands/Transportation", "Other"))
)
ds_unfiltered <- left_join(select(enrollment, record_id, age_group), ema, multiple = "all")
enroll <- select(enrollment, record_id, age_group, dust_id, dust_date, dob, sex_infant, due_date)

# Calculate Posture Rates
ds <- ds_unfiltered %>% filter(availability == "Available", posture != "Other") %>% drop_na(posture)

posture <- ds %>% count(record_id, age_group, posture)
posture <- posture %>% complete(posture, nesting(record_id, age_group), fill = list(n = 0)) %>% arrange(record_id)
posture <- posture %>% group_by(record_id) %>% mutate(total = sum(n), prop = n/total) %>% ungroup

ggplot(posture, aes(x = age_group, y = prop)) + 
  geom_point() + geom_smooth(method = "lm") + 
  scale_x_continuous(breaks = seq(3,24,3)) + 
  facet_wrap(~posture)

ggplot(posture, aes(x = age_group, y = prop)) + 
  geom_point() + geom_smooth(method = "loess") + 
  scale_x_continuous(breaks = seq(3,24,3)) + 
  facet_wrap(~posture)

# Calculate Position Rates
ds <- ds_unfiltered %>% filter(availability == "Available", positioning != "Other") %>% drop_na(positioning)

position <- ds %>% count(record_id, age_group, positioning)
position <- position %>% complete(positioning, nesting(record_id, age_group), fill = list(n = 0)) %>% arrange(record_id)
position <- position %>% group_by(record_id) %>% mutate(total = sum(n), prop = n/total) %>% 
  ungroup %>% select(-n, -total)

ggplot(position, aes(x = age_group, y = prop)) + 
  geom_point() + geom_smooth(method = "loess") + 
  scale_x_continuous(breaks = seq(3,24,3)) + 
  facet_wrap(~positioning)

# Calculate Activity Rates
ds <- ds_unfiltered %>% filter(availability == "Available", activity != "Other") %>% drop_na(activity)

activity <- ds %>% count(record_id, age_group, activity)
activity <- activity %>% complete(activity, nesting(record_id, age_group), fill = list(n = 0)) %>% arrange(record_id)
activity <- activity %>% group_by(record_id) %>% mutate(total = sum(n), prop = n/total) %>% 
  ungroup %>% select(-n, -total)

ggplot(activity, aes(x = age_group, y = prop)) + 
  geom_point() + geom_smooth(method = "lm") + 
  scale_x_continuous(breaks = seq(3,24,3)) + 
  facet_wrap(~activity)

# Calculate Object Holding Rates
ds <- ds_unfiltered %>% filter(availability == "Available") %>% drop_na(object)

object <- ds %>% count(record_id, age_group, object)
object <- object %>% complete(object, nesting(record_id, age_group), fill = list(n = 0)) %>% arrange(record_id)
object <- object %>% group_by(record_id) %>% mutate(total = sum(n), prop = n/total) %>% 
  ungroup %>% select(-n, -total)
object <- filter(object, object %in% c("Holding and Mouthing", "Holding not Mouthing"))
object <- object %>% group_by(record_id) %>%  summarize(holding = sum(prop))

# Score EMQ
emq_long <- emq %>% select(-emq_notes, -emq_complete) %>% pivot_longer(-record_id, names_to = "item", values_to = "score")

# Check missing
emq_long %>% group_by(record_id) %>% 
  summarize(num_na = sum(is.na(score))) %>% 
  arrange(desc(num_na))


emq_long <- emq_long %>% mutate(subscale = case_when(
  str_detect(item, "emqg") ~ "Gross",
  str_detect(item, "emqf") ~ "Fine",
  str_detect(item, "emqpa") ~ "PA"))
emq_score <- emq_long %>% group_by(record_id, subscale) %>% summarize(score = sum(score, na.rm = T)) %>% 
  pivot_wider(id_cols = record_id, names_from = subscale, values_from = score) %>% ungroup

# Get test date
ds <- ds_unfiltered %>% filter(availability == "Available") %>% drop_na(sent_time)
test_date <- ds %>% group_by(record_id) %>% summarize(sent_time = median(sent_time, na.rm = T))
test_date <- test_date %>% mutate(test_date = date(with_tz(as_datetime(sent_time), tz = "America/New_York")))

# Merge everything
ds <- left_join(emq_score, enroll) %>% left_join(demo)

ds <- left_join(ds, select(test_date, -sent_time))

ds <- left_join(ds, pivot_wider(posture, 
                                       id_cols = c(record_id, age_group, total), 
                                       names_from = posture, 
                                       values_from = prop))
ds <- left_join(ds, position %>% 
                  filter(positioning != "Other") %>% 
                  pivot_wider(id_cols = c(record_id, age_group), 
                              names_from = positioning, values_from = prop))

ds <- left_join(ds, activity %>% 
                  filter(activity != "Other") %>% 
                  pivot_wider(id_cols = c(record_id, age_group), 
                              names_from = activity, values_from = prop))

ds <- left_join(ds, emq %>% 
                  filter(record_id %in% ds$record_id) %>% 
                  select(- emq_notes, -emq_complete))

ds <- left_join(ds, object)

write_csv(ds, "merged.csv")

# Calculate DVs within Activity

# Posture
ds <- ds_unfiltered %>% 
  filter(availability == "Available", activity != "Other", posture != "Other") %>% 
  drop_na(activity, posture)

activity_posture <- ds %>% count(record_id, age_group, activity, posture)
activity_posture <- activity_posture %>% complete(activity, posture, nesting(record_id, age_group), fill = list(n = 0)) %>% arrange(record_id)
activity_posture <- activity_posture %>% group_by(record_id, activity) %>% mutate(total = sum(n), prop = n/total) %>% 
  ungroup %>%  mutate(prop = ifelse(is.nan(prop), NA, prop))

activity_posture %>% filter(activity %in% c("Play", "Errands/Transportation", "Feeding")) %>% 
  ggplot(aes(x = age_group, y = prop, color = posture)) + 
  geom_point() + geom_smooth(method = "lm", formula = y ~ x + I(x^2)) + 
  scale_x_continuous(breaks = seq(3,24,3)) + 
  facet_wrap(~activity)

activity_posture %>% filter(activity %in% c("Play", "Errands/Transportation", "Feeding")) %>% 
  ggplot(aes(x = age_group, y = prop, color = posture)) + 
  geom_point() + geom_smooth(method = "lm", formula = y ~ x + I(x^2)) + 
  scale_x_continuous(breaks = seq(3,24,3)) + 
  facet_wrap(~activity)

write_csv(activity_posture, "activity-posture.csv")

# Objects
ds <- ds_unfiltered %>% 
  filter(availability == "Available", activity != "Other", object != "Other") %>% 
  drop_na(activity, object)

activity_hold <- ds %>% count(record_id, age_group, activity, object)
activity_hold <- activity_hold %>% complete(activity, object, nesting(record_id, age_group), fill = list(n = 0)) %>% arrange(record_id)
activity_hold <- activity_hold %>% group_by(record_id, activity) %>% mutate(total = sum(n), prop = n/total) %>% 
  ungroup %>%  mutate(prop = ifelse(is.nan(prop), NA, prop))

activity_hold %>% filter(activity %in% c("Play", "Errands/Transportation", "Feeding")) %>% 
  ggplot(aes(x = age_group, y = prop, color = object)) + 
  geom_point() + 
  geom_smooth(method = "lm", formula = y ~ x + I(x^2)) + 
  #geom_smooth() +
  scale_x_continuous(breaks = seq(3,24,3)) + 
  facet_wrap(~activity)

write_csv(activity_hold, "activity-object.csv")

# Positioning
ds <- ds_unfiltered %>% 
  filter(availability == "Available", activity != "Other", positioning != "Other") %>% 
  drop_na(activity, positioning)

activity_position <- ds %>% count(record_id, age_group, activity, positioning)
activity_position <- activity_position %>% complete(activity, positioning, nesting(record_id, age_group), fill = list(n = 0)) %>% arrange(record_id)
activity_position <- activity_position %>% group_by(record_id, activity) %>% mutate(total = sum(n), prop = n/total) %>% 
  ungroup %>%  mutate(prop = ifelse(is.nan(prop), NA, prop))

activity_position %>% filter(activity %in% c("Play", "Errands/Transportation", "Feeding")) %>% 
  ggplot(aes(x = age_group, y = prop, color = positioning)) + 
  geom_point() + 
  geom_smooth(method = "lm", formula = y ~ x + I(x^2)) + 
  #geom_smooth() +
  scale_x_continuous(breaks = seq(3,24,3)) + 
  facet_wrap(~activity)

write_csv(activity_position, "activity-position.csv")
