# This script serves as a template to read in and prepare the raw data 
# of expert responses on party positioning from a Länder Expert Survey (LES).

# You can run this script only if you have access to the raw data exported from LimeSurvey.
# Export the files "R (Syntax file)" and "R (Data file)" from LimeSurvey and adjust the file paths below accordingly.

# 0. Load packages and helper functions ####
if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
library(pacman)
p_load(tidyverse, lubridate, here)

source(here("scripts", "ignore", "les_2026", "les_helper_functions.R"))

# 1. Load raw data ####

# Important: Adjust the file path to the raw data (csv) in the R syntax file as needed.
source(here("scripts", "ignore", "les_2026", "survey_814884_R_syntax_file.R"))

# rename raw data
les_results_raw <- data
rm(data)

# 2. Clean data ####
les_results_clean <- les_clean_raw_data(
  df = les_results_raw,
  startdate_of_survey = "2026-01-08",
  cutoff_date = "2026-02-01"
)

# 3. Convert wide to long format ####
les_results_long <- les_wide_to_long(les_results_clean, regions = c("bund", "bw", "rp"))
saveRDS(les_results_long, here("output", "ignore", "copilot", "les_results_long.rds"))

# 4. Calculate general metrics ####
les_metrics <- les_calculate_stats(les_results_long, items_list = unique(les_results_long$item), min_n = 5)

# 5. Calculate comparative metrics between state and federal level ####
les_state_federal_diff <- les_compare_state_federal_stats(
  les_results_long,
  regions = c("bw", "rp"),
  items_list = unique(les_results_long$item),
  min_n = 5,
  respondent_id_col = "id"
)

# 6. Output summary of responses ####
cat("Number of respondents:", n_distinct(les_results_long$id), "\n")
cat("Items in data:", paste(unique(les_results_long$item), collapse = ", "), "\n")
cat("Parties in data:", paste(unique(les_results_long$party), collapse = ", "), "\n")
cat("Regions in data:", paste(unique(les_results_long$region), collapse = ", "), "\n")

# 7. Small multiple chart: positions per party, item, and region ####

# Order parties by median for the first item, include all parties present in the data
first_item <- unique(les_results_long$item)[1]
party_levels <- les_metrics %>%
  filter(item == first_item) %>%
  arrange(median) %>%
  pull(party) %>%
  as.character() %>%
  unique()
party_levels <- unique(c(party_levels, setdiff(unique(as.character(les_results_long$party)), party_levels)))

medians_plot <- les_metrics %>%
  mutate(
    item = factor(item, levels = unique(les_results_long$item)),
    party = factor(as.character(party), levels = party_levels)
  )

ggplot(
  les_results_long %>%
    mutate(
      item = factor(item, levels = unique(item)),
      party = factor(as.character(party), levels = party_levels)
    ),
  aes(x = as.numeric(value), y = party, color = region)
) +
  geom_jitter(height = 0.2, alpha = 0.3, size = 1) +
  geom_point(
    data = medians_plot,
    aes(x = median, y = party, fill = region),
    color = "black", shape = 21, size = 2, inherit.aes = FALSE
  ) +
  facet_wrap(~ item, scales = "free_x") +
  labs(
    title = "Party Positions by Item and Region",
    x = "Position (Value)",
    y = "Party",
    color = "Region",
    fill = "Region"
  ) +
  theme_minimal(base_size = 12) +
  theme(axis.text.y = element_text(hjust = 1))
