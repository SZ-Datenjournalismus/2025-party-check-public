# This script contains helper functions for the Länder Expert Survey (LES)

#' Cleans raw data from the Länder Expert Survey (LES)
#'
#' Removes columns with only NA values, filters test responses, too short durations,
#' and responses outside the survey period.
#'
#' @param df Dataframe with raw LES data.
#' @param startdate_of_survey Start date of the survey (format: "YYYY-MM-DD").
#' @param cutoff_date Optional: End date of the survey (format: "YYYY-MM-DD").
#'
#' @return Cleaned dataframe.
#' @examples
#' les_clean_raw_data(df = les_results_raw, startdate_of_survey = "2026-01-08", cutoff_date = "2026-02-01")
les_clean_raw_data <- function(df, startdate_of_survey, cutoff_date = NULL) {
    # convert startdate_of_survey to date
    startdate_of_survey <- as.Date(startdate_of_survey)

    df_clean <- df |>
        # remove columns which include only NA values
        select(where(~ !all(is.na(.)))) |>
        # remove all rows with less than 3 minutes of survey time
        mutate(across(c(startdate, datestamp), ~ as.POSIXct(.))) |>
        filter(datestamp - startdate >= minutes(3)) |>
        # remove test responses
        filter(!str_detect(tolower(feedback), "test|probe") | is.na(feedback)) |>
        # remove responses before the official start date of the survey
        filter(as.Date(startdate) >= startdate_of_survey)

    # if cutoff_date is provided, remove responses after this date
    if (!is.null(cutoff_date)) {
        cutoff_date <- as.Date(cutoff_date)
        df_clean <- df_clean |>
            filter(as.Date(datestamp) <= cutoff_date)
    }

    # show messages about removed columns
    removed_cols <- setdiff(names(df), names(df_clean))
    if (length(removed_cols) > 0) {
        message("Removed columns with only NA values: ", paste(removed_cols, collapse = ", "))
    }

    return(df_clean)
}

#' Wide-to-long transformation for LES data
#'
#' Converts all columns matching the pattern <item>_<party><region> to long format and extracts item, party, and region.
#'
#' @param df Dataframe in wide format (e.g., output from les_clean_raw_data).
#' @param regions Vector of regions (default: c("bund", "bw", "by", ...)).
#'
#' @return Dataframe in long format with columns item, party, region, value, and all ID columns.
#' @examples
#' les_wide_to_long(df_clean, regions = c("bund", "bw", "rp"))
les_wide_to_long <- function(df, regions = c("bund", "bw", "by", "be", "bb", "hb", "hh", "he", "mv", "ni", "nw", "rp", "sl", "sn", "st", "sh", "th")) {
    # find columns that match the pattern <item>_<party><region>
    cols_long <- grep("^[a-z0-9]+_[a-z]+[a-z]+$", names(df), value = TRUE)
    # remove all columns before the first occurence of leftrightgeneral
    first_item_index <- which(grepl("leftrightgeneral", cols_long))[1]
    cols_long <- cols_long[first_item_index:length(cols_long)]
    region_regex <- paste0("(", paste(regions, collapse = "|"), ")$")
    df_long <- df |>
        pivot_longer(
            cols = all_of(cols_long),
            names_to = "variable",
            values_to = "value",
            values_transform = list(value = as.character)
        ) |>
        extract(
            col = "variable",
            into = c("item", "party", "region"),
            regex = paste0("^([a-z0-9]+)_([a-z]+)", region_regex)
        )
    return(df_long)
}

#' Calculates summary statistics for LES long-format data
#'
#' Calculates median, mean, standard deviation, confidence intervals, etc.
#' for numeric values grouped by item, party, and region.
#'
#' @param df A dataframe in LES long format (e.g., les_results_long)
#' @param items_list A vector of item names for which statistics should be calculated.
#' @param min_n Minimum number of responses per group to include in the output (default: 1).
#'
#' @return Dataframe with summary statistics for each item/party/region combination.
les_calculate_stats <- function(df, items_list, min_n = 1) {
  required_cols <- c("item", "party", "region", "value")
  missing_cols <- setdiff(required_cols, names(df))
  if (length(missing_cols) > 0) {
    stop(paste("Folgende Spalten fehlen im Dataframe:", paste(missing_cols, collapse = ", ")))
  }

  selected_df <- df %>% select(item, party, region, value)

  prepare_df <- selected_df %>%
    filter(item %in% items_list) %>%
    mutate(value = as.numeric(value)) %>%
    filter(!is.na(party), !is.na(region)) %>%
    group_by(item, party, region) %>%
    drop_na(value)

  stats_df <- prepare_df %>%
    reframe(
      median = median(value, na.rm = TRUE),
      mean = mean(value, na.rm = TRUE, trim = 0.25),
      median_integer = case_when(
        median %% 1 == 0 ~ median,
        median %% 0.5 != 0 ~ round(median),
        abs(mean - floor(median)) < abs(mean - ceiling(median)) ~ floor(median),
        TRUE ~ ceiling(median)
      ),
      sd = sd(value, na.rm = TRUE),
      lower_ci = quantile(x = value, probs = 0.025, na.rm = TRUE),
      upper_ci = quantile(x = value, probs = 0.975, na.rm = TRUE),
      n = n()
    ) %>%
    filter(n >= min_n)

  result_df <- stats_df %>%
    mutate(item = factor(item, levels = items_list)) %>%
    arrange(item, party, region)

  n_per_group <- result_df %>% pull(n)
  message(paste0(
    "Gruppengröße: Minimum = ", min(n_per_group, na.rm = TRUE),
    ", Maximum = ", max(n_per_group, na.rm = TRUE),
    " Antworten pro Gruppe"
  ))

  return(result_df)
}

#' Calculate difference between state and federal answers per respondent, then metrics of these diffs
#'
#' For each respondent, party, and item, calculates the difference between state and "bund" (federal) responses,
#' then computes summary statistics for these differences.
#'
#' @param df Dataframe in long format (must contain respondent_id, item, party, region, value)
#' @param regions Vector of state regions to compare (e.g., c("bw", "rp"))
#' @param items_list Vector of item names to include (default: all items in df)
#' @param min_n Minimum number of responses per group to include in the output (default: 1)
#' @param respondent_id_col Name of respondent id column (default: "id")
#'
#' @return Dataframe with summary statistics for the difference per item/party/region
les_compare_state_federal_stats <- function(df, regions, items_list = NULL, min_n = 1, respondent_id_col = "id") {
  required_cols <- c(respondent_id_col, "item", "party", "region", "value")
  missing_cols <- setdiff(required_cols, names(df))
  if (length(missing_cols) > 0) {
    stop(paste("Missing columns in dataframe:", paste(missing_cols, collapse = ", ")))
  }

  df <- df %>%
    mutate(value = as.numeric(value))

  # Filter for selected items if provided
  if (!is.null(items_list)) {
    df <- df %>% filter(item %in% items_list)
  }

  # For each respondent, party, item: get state and federal value, then diff
  df_state <- df %>%
    filter(region %in% regions) %>%
    select(all_of(respondent_id_col), item, party, region, value_state = value)

  df_bund <- df %>%
    filter(region == "bund") %>%
    select(all_of(respondent_id_col), item, party, value_bund = value)

  df_diff <- df_state %>%
    left_join(df_bund, by = c(respondent_id_col, "item", "party")) %>%
    filter(!is.na(value_state), !is.na(value_bund)) %>%
    mutate(diff = value_state - value_bund)

  # Now calculate metrics of these diffs per item/party/region
  stats_df <- df_diff %>%
    group_by(item, party, region) %>%
    filter(n() >= min_n) %>%
    reframe(
      median = median(diff, na.rm = TRUE),
      mean = mean(diff, na.rm = TRUE, trim = 0.25),
      median_integer = case_when(
        median %% 1 == 0 ~ median,
        median %% 0.5 != 0 ~ round(median),
        abs(mean - floor(median)) < abs(mean - ceiling(median)) ~ floor(median),
        TRUE ~ ceiling(median)
      ),
      sd = sd(diff, na.rm = TRUE),
      lower_ci = quantile(diff, probs = 0.025, na.rm = TRUE),
      upper_ci = quantile(diff, probs = 0.975, na.rm = TRUE),
      n = n()
    ) %>%
    ungroup()

  result_df <- stats_df %>%
    mutate(item = if (!is.null(items_list)) factor(item, levels = items_list) else item) %>%
    arrange(item, party, region)

  n_per_group <- result_df %>% pull(n)
  message(paste0(
    "Gruppengröße: Minimum = ", min(n_per_group, na.rm = TRUE),
    ", Maximum = ", max(n_per_group, na.rm = TRUE),
    " Antworten pro Gruppe"
  ))

  return(result_df)
}

