# This file processes the raw CSV (1.5 million rows) into something more manageable. 
# Raw CSV from https://data.boston.gov/dataset/311-service-requests.
# Note that you must change your working directory to the correct address below (line 10).

library(tidyverse)
library(lubridate)

# Change the directory to wherever the CSV is saved.

setwd("C:/Users/Gabriel/Desktop")

# Read in the raw data.

raw <- read_csv("311_all.csv")

# Use data from only the past three years.
# In total this is about 683,000 rows.

df <- raw %>% 
  filter(open_dt >= "2016-01-01") %>% 
  
# Select only the variables of interest.
# No case_title because there are too many to factor them.
# No latitude, longitude, 
# Note that type may need to be dropped from any ML algorithm because it has too many levels.
  
  select(open_dt, target_dt, closed_dt, reason, type, department,
         fire_district, pwd_district, city_council_district, police_district,
         neighborhood, ward, location_zipcode, source)

# Count the NA values for each variable.

nulls <- tibble(vars = names(df), null = NA)
i <- 1
for (var in names(df)) {
  nulls$null[i] <- sum(is.na(df[var]))
  i <- i + 1
}

# Note that target_dt and location_zipcode have over 150,000 missing values each.

# Remove NA values.

df <- na.omit(df)

df <- df %>% 

# Add a month category.
  
  mutate(month_open = month(df$open_dt)) %>% 
  mutate(month_open = month.name[month_open]) %>% 

# Add a time of day factor variable for when the issue was submitted.
  
  mutate(time = case_when(
    hour(open_dt) >= 6 & hour(open_dt) < 12 ~ "morning",
    hour(open_dt) >= 12 & hour(open_dt) < 18 ~ "afternoon",
    hour(open_dt) >= 18 | hour(open_dt) <= 6 ~ "night"
  )) %>% 
  
# Add a duration for how long the job took.
# In period form and hours.
    
  mutate(completion_time = as.period(interval(open_dt, closed_dt))) %>% 
  mutate(completion_hours = round(as.numeric(completion_time) / 60^2, 5)) %>% 

# Add a duration for how long Boston promised to remedy the issue.
# In period form and hours.

  mutate(promised_time = as.period(interval(open_dt, df$target_dt))) %>% 
  mutate(promised_hours = round((as.numeric(promised_time) / 60^2), 5)) %>% 

# Add a performance measure. Difference between promised and completed.

  mutate(score = promised_hours - completion_hours)

# Convert the performance measure to a percentile score.

percentile <- ecdf(df$score)

df <- df %>% 
  mutate(score = percentile(score))

### Convert the character variables to factors.

# Cycle through variable names and save only those that are characters.

factors <- c()

for (var in names(df)) {
  if (class(df[[var]]) == "character") {
    factors <- c(factors, var)
  }
}

# Change the character variables to factors.

df <- df %>%
  mutate_at(.vars = factors, as.factor) %>% 

# Drop certain variables that has information already included in other variables.

  select(-completion_time, -promised_time) %>% 

# Drop extremes for completion or promised time.
# Less than 15 minutes or more than 6 months.

  filter(completion_hours > .25,
         completion_hours < 4392,
         promised_hours > .25,
         promised_hours < 4392)

# Drop the least common reasons for reporting a 311 call.
# Common is defined as less than 1 percent.

common <- count(df, reason) %>% 
  
# Create a percentage variable.
  
  mutate(percent = n / nrow(df)) %>% 

# Filter out requests that comprise less than 1%.
  
  filter(percent > .01)

# Now filter the entire dataset based on the important reasons.

df <- df %>% 
  filter(reason %in% common$reason) %>% 

# Refactor the variable so it has only 14 levels.
  
  mutate(reason = factor(reason))

# Save the file.

write_csv(df, "311_cleaned.csv")
write_rds(df, "311_cleaned.rds")