# This script serves as a template to read in and prepare the raw data 
# of expert responses on party positioning from a Länder Expert Survey (LES).

# You can run this script only if you have access to the raw data exported from LimeSurvey.
# Export the files "R (Syntax file)" and "R (Data file)" from LimeSurvey and adjust the file paths below accordingly.

# 0. Load packages and helper functions ####
if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
library(pacman)
if(!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes")
if (!requireNamespace("threadr", quietly = TRUE)) remotes::install_github("skgrange/threadr")
p_load(tidyverse, lubridate, here, stringr, threadr)

source(here("scripts", "les", "les_helper_functions.R"))

# 1. Load raw data ####

# Important: Adjust the file path to the raw data (csv) in the R syntax file as needed.
source(here("scripts", "ignore", "les_2026", "survey_814884_R_syntax_file.R"))

# rename raw data
les_results_raw <- data
rm(data)

# Helper function to extract expert choices
extract_expert_choices <- function(df, prefix, var_name) {
  lgl_col <- paste0(var_name, "_lgl")
  les_results_raw %>%
    dplyr::select(id, starts_with(prefix)) %>%
    pivot_longer(!id, names_to = paste0(var_name, "_var"), values_to = var_name) %>%
    distinct() %>%
    mutate(
      !!lgl_col := case_when(.data[[var_name]] == "Ja" ~ TRUE, TRUE ~ FALSE),
      !!paste0(var_name, "_var") := str_extract(.data[[paste0(var_name, "_var")]], "(?<=_).*")
    ) %>%
    select(-all_of(var_name)) %>%
    arrange(id)
}

# Identify for each expert, which states, parties, and policy fields they chose to evaluate
states_experts <- extract_expert_choices(les_results_raw, "laender", "state")
parties_experts <- extract_expert_choices(les_results_raw, "parties1", "party")
policyfields_experts <- extract_expert_choices(les_results_raw, "policyfields", "policyfield")
# add general policy field for each expert
general_policies <- c("leftrightgeneral", "lrecon", "galtan")
policyfields_experts <- policyfields_experts %>%
  bind_rows(
    policyfields_experts %>%
      dplyr::select(id) %>%
      distinct() %>%
      mutate(
        policyfield_var = "general",
        policyfield_lgl = TRUE
      )
  )

# combine expert choices into one dataframe
expert_choices <- states_experts %>%
  left_join(parties_experts, relationship = "many-to-many", by = "id") %>%
  left_join(policyfields_experts, relationship = "many-to-many", by = "id") %>%
  # calculate if all three dimensions were selected
  mutate(all_selected = state_lgl & party_lgl & policyfield_lgl) %>%
  # filter NA
  drop_na() %>%
  # drop not all selected
  filter(all_selected)

# 2. Clean data ####
les_results_clean <- les_clean_raw_data(
  df = les_results_raw,
  startdate_of_survey = "2026-01-08",
  cutoff_date = "2026-02-01",
  min_survey_duration = 2
)

# 3. Convert wide to long format ####
les_results_long <- les_wide_to_long(les_results_clean, regions = c("bund", "bw", "rp"))

# match items and policy fields
items_policyfields <- les_results_long %>%
  dplyr::select(item) %>%
  distinct() %>%
  mutate(policyfield_var = case_when(
    item %in% general_policies ~ "general",
    item %in% c("childcare", "communityschool", "schoolrecom") ~ "edu",
    item %in% c("antielitism", "peopledecision") ~ "pop",
    item %in% c("genderlanguage", "liberalism", "lawandorder") ~ "soc",
    item %in% c("assimilation", "immigration", "asylumbenefit") ~ "mig",
    item %in% c("publicdebt", "rentcontrol", "publicbroadcast") ~ "econ",
    item %in% c("ukraine", "afdcoop", "stadtbild") ~ "deb",
    item %in% c("renewenergy", "cars", "climatepolicy") ~ "clim"
  ))

# 4. Calculate general metrics ####
les_metrics <- les_calculate_stats(
  les_results_long,
  items_list = unique(les_results_long$item),
  min_n = 5, # adjust minimum n as needed
  expert_choices = expert_choices,
  items_policyfields = items_policyfields,
  min_completion = 0.1,
  respondent_id_col = "id"
)

# 5. Calculate comparative metrics between state and federal level ####
les_state_federal_diff <- les_compare_state_federal_stats(
  les_results_long,
  regions = c("bw", "rp"),
  items_list = unique(les_results_long$item),
  min_n = 5, # adjust minimum n as needed
  respondent_id_col = "id",
  expert_choices = expert_choices,
  items_policyfields = items_policyfields,
  min_completion = 0.1
)

# 6. Output summary of responses ####
cat("Number of respondents:", n_distinct(les_results_long$id), "\n")
cat("Items in data:", paste(unique(les_results_long$item), collapse = ", "), "\n")
cat("Parties in data:", paste(unique(les_results_long$party), collapse = ", "), "\n")
cat("Regions in data:", paste(unique(les_results_long$region), collapse = ", "), "\n")

# calculate party-region-item combinations missing in les_metrics
all_party_region_item_combinations <- expand.grid(
  party = unique(les_results_long$party),
  region = unique(les_results_long$region),
  item = unique(les_results_long$item)
)

missing_combinations <- all_party_region_item_combinations %>%
  anti_join(
    les_metrics %>%
      dplyr::select(party, region, item) %>%
      distinct(),
    by = c("party", "region", "item")
  ) %>%
  # collapse
  group_by(party, region) %>%
  reframe(
    missing_items = paste(item, collapse = ", "),
  ) %>%
  arrange(region, party)

if (nrow(missing_combinations) > 0) {
  cat("Missing party-region-item combinations in les_metrics:\n")
  print(missing_combinations)
} else {
  cat("No missing party-region-item combinations in les_metrics.\n")
}

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

# 8. Generate party check HTML table for Lime Survey ####
# Read in existing party check data from HTML table
current_party_check_data <- threadr::read_html_tables("les_median_05.html") %>%
  distinct() %>%
  filter(party != "party") %>%
  # every column but party and bl is numeric
  mutate(across(-c(party, bl), as.numeric))

# Create new party check data from les_metrics
new_party_check_data <- les_metrics %>%
  filter(region != "bund") %>%
  dplyr::select(party, bl = region, item, value = median) %>%
  pivot_wider(names_from = item)
  
new_party_check_data <- current_party_check_data %>%
  filter(!bl %in% unique(les_metrics$region)) %>%
  bind_rows(new_party_check_data)

# Convert new party check data to HTML table
html <- paste0(
  "<table>\n",
  paste0(
    "<tr>", paste0("<th>", names(new_party_check_data), "</th>", collapse = ""), "</tr>\n",
    apply(new_party_check_data, 1, function(row)
      paste0("<tr>", paste0("<td>", row, "</td>", collapse = ""), "</tr>\n")
    ),
    collapse = ""
  ),
  "</table>\n"
)

# Write updated HTML table to file
# TODO: Adjust file path as needed or replace manually
writeLines(html, here("output", "ignore", "les_median_05.html"))
