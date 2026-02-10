# This script serves as a template to read in and prepare the raw data
# of user responses on political positioning from a Party Check survey.

# You can run this script only if you have access to the raw data exported from LimeSurvey.
# Export the files "R (Syntax file)" and "R (Data file)" from LimeSurvey and adjust the file paths below accordingly.
# Select only one single answer to export the R syntax file to speed up the download process.

# 0. Load packages and helper functions ####
source("scripts/config.R")
source("scripts/party_check/party_check_helper_functions.R")

# 1. Load raw data ####
# Important: Adjust the file path to the raw data (csv) in the R syntax file as needed.
source(here("scripts", "ignore", "party_check_2026", "survey_736816_R_syntax_file.R"))

# rename raw data
party_check_results_raw <- data
rm(data)

message(paste0("Number of respondents: ", nrow(party_check_results_raw)))

# 2. Prepare data ####
# extract user answers for items
party_check_results_clean <- party_check_clean_raw_data(
    df = party_check_results_raw,
    startdate_of_survey = "2026-02-06",
    cutoff_date = NULL,
    min_survey_duration = 3,
    min_last_page = 19,
    region = "Baden-Württemberg"
)

message(paste0("Number of valid responses after cleaning: ", nrow(party_check_results_clean)))

# remove some columns
party_check_results_clean <- party_check_results_clean %>%
  select(
    -starts_with(c("G0", "submitdate", "startlanguage", "seed", "restart", "back", "G2", "select", "lrpos", "r9", "zusatz", "r6", "r3", "r4", "r8", "r5", "Gesamtzeit", "Gruppenzeit", "Fragenzeit")),
    -ends_with(c("match"))
  )

# 3. Calculate vote intention and recall based on several survey fields ####
party_check_results_clean <- party_check_results_clean %>%
    mutate(
        votintlandpre = case_when(
            !is.na(votintlandpre) ~ votintlandpre,
            !is.na(votintlandpre_other) ~ votintlandpre_other
        ),
        votintlandpost = case_when(
            !is.na(votintlandpost) ~ votintlandpost,
            !is.na(votintlandpost_other) ~ votintlandpost_other
        ),
        votintland_calc = case_when(
            !is.na(votintlandpre) ~ votintlandpre,
            !is.na(votintlandpost) ~ votintlandpost,
        ),
        recall = case_when(
            !is.na(recall) ~ recall,
            !is.na(recall_other) ~ recall_other
        ),
        recallland = case_when(
            !is.na(recallland) ~ recallland,
            !is.na(recallland_other) ~ recallland_other
        ),
        votint = case_when(
            !is.na(votint) ~ votint,
            !is.na(votint_other) ~ votint_other
        )
    )

# 4. Convert wide to long format ####
# sociodemographic variables (will be kept in wide format)
identifier_items <- c("id", "lastpage", "startdate", "datestamp")
sociodemographic_vars <- c(
    "votintland_calc", "gender", "age", "urabrural", "bundesland", "educationschool", "educationjob"
)
sociodemographic_vars_additional <- c(
    "votintlandpre", "votintlandpost", "recallland", "recall", "gemeinde", "votint", "konfession", "gottesdienst"
)

party_check_results_long <- party_check_results_clean %>%
    pivot_longer(
        cols = -c(all_of(c(sociodemographic_vars, sociodemographic_vars_additional, identifier_items))),
        names_to = "item",
        values_to = "value",
        values_transform = list(value = as.character)
    )

# replace SQ001 in "item", e.g. leftrightgeneral_SQ001 to leftrightgeneral
party_check_results_long <- party_check_results_long %>%
    mutate(item = str_replace(item, "_SQ001", "")) %>%
    # salience to wide format
    mutate(is_sal = ifelse(str_detect(item, "^sal"), "salience", "value")) %>%
    mutate(item = str_replace(item, "^sal", "")) %>%
    pivot_wider(
        names_from = is_sal,
        values_from = value
    )

# 5. Add weights ####
source(here("scripts", "party_check", "party_check_weight_data.R"))

# combine weights with main data, keep only respondents with valid weights
# w = weight for sociodemographic variables, w_votintland_calc = weight for vote intention
# you can remove one or both of the weights if you don't want to use them
# if you include weights_votintland_calc, all respondents without valid vote intention will be dropped
party_check_results_long <- weights_socdem_df %>%
    inner_join(weights_votintland_df, by = "id") %>%
    inner_join(party_check_results_long, by = "id")

# 5. Calculate summary statistics ####
items_to_calculate <- party_check_results_long %>%
    dplyr::select(item) %>%
    distinct() %>%
    pull(item)
standard_items <- items_to_calculate[c(3:21)]
additional_items <- c(
    "schoolrecom",
    str_detect(items_to_calculate, "regionalism"),
    "assimilation", "publicbroadcast", "ukraine",
    str_detect(items_to_calculate, "trustslider"),
    str_detect(items_to_calculate, "wlage"),
    "antiestablishment"
)
party_vote_likelihood_vars <- c(
    "ptvs_spd", "ptvs_cdu", "ptvs_greens", "ptvs_fdp", "ptvs_afd", "ptvs_left", "ptvs_bsw", "ptvs_fw"
)
character_items <- c(
    "matcheffect", "stadtbildloesung", "stadtbildloesung_other",
    "wichtigprob", "polint"
)

# only works for numeric items
party_check_stats <- calculate_pc_stats(
    df = party_check_results_long,
    items_list = standard_items,
    # sociodemography_list = sociodemographic_vars,
    sociodemography_list = c("votintland_calc", "gender"),
    min_n = 100,
    with_weights = TRUE,
    weight_column = "w"
)
