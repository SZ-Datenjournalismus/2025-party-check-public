# This script contains helper functions for Party Check survey data

#' Cleans raw data from Party Check survey
#'
#' Removes columns with only NA values, filters test responses, too short durations,
#' and responses outside the survey period.
#'
#' @param df Dataframe with raw Party Check survey data.
#' @param startdate_of_survey Start date of the survey (format: "YYYY-MM-DD").
#' @param region Region to filter for in 'bundesland' column (e.g., "Baden-Württemberg"). Set to NULL (default) to skip filter.
#' @param cutoff_date Optional: End date of the survey (format: "YYYY-MM-DD").
#' @param min_survey_duration Minimum duration of the survey in minutes (default: 3).
#' @param min_last_page Minimum last page reached in the survey (default: 19).
#'
#' @return Cleaned dataframe.
#' @examples
#' party_check_clean_raw_data(df = party_check_results_raw, region = "Baden-Württemberg", startdate_of_survey = "2026-01-08", cutoff_date = "2026-02-01")
party_check_clean_raw_data <- function(df, startdate_of_survey, region = NULL, cutoff_date = NULL, min_survey_duration = 3, min_last_page = 19) {
    # convert startdate_of_survey to date
    startdate_of_survey <- as.Date(startdate_of_survey)

    df_clean <- df |>
        # remove all respondees who did not reach minimum last page
        filter(lastpage >= min_last_page) |>
        # remove all rows with less than min_survey_duration minutes of survey time
        mutate(across(c(startdate, datestamp), ~ as.POSIXct(.))) |>
        filter(datestamp - startdate >= minutes(min_survey_duration)) |>
        # remove responses before the official start date of the survey
        filter(as.Date(startdate) >= startdate_of_survey)
    
    # filter for specified region if provided
    if (!is.null(region)) {
        df_clean <- df_clean |>
            filter(bundesland == region)
    }

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


#' Calculates summary statistics for Party Check long-format data
#'
#' Calculates median, mean, standard deviation, confidence intervals, etc.
#' for numeric values grouped by item and sociodemographic variables.
#'
#' @param df A dataframe in Party Check long format
#' @param items_list A vector of item names for which statistics should be calculated.
#' @param sociodemography_list A vector of sociodemographic variable names to keep in the output.
#' @param min_n Minimum number of responses per group to include in the output (default: 1).
#'
#' @return Dataframe with summary statistics for each item/sociodemography combination.
#' @examples
#' party_check_calculate_stats(party_check_results_long, items_list = c("item1", "item2"), sociodemography_list = c("age", "gender"), min_n = 5)

#' Calculates summary statistics for Party Check long-format data
#'
#' Calculates median, mean, standard deviation, confidence intervals, etc.
#' for numeric values grouped by item and sociodemographic variables. Optional: weighted statistics.
#'
#' @param df A dataframe in Party Check long format
#' @param items_list A vector of item names for which statistics should be calculated.
#' @param sociodemography_list A vector of sociodemographic variable names to keep in the output.
#' @param min_n Minimum number of responses per group to include in the output (default: 1).
#' @param with_weights Logical, whether to calculate weighted statistics (default: FALSE)
#' @param weight_column Name of the weight column (default: "w")
#'
#' @return Dataframe with summary statistics for each item/sociodemography combination.
#' @examples
#' party_check_calculate_stats(party_check_results_long, items_list = c("item1", "item2"), sociodemography_list = c("age", "gender"), min_n = 5, with_weights = TRUE)
party_check_calculate_stats <- function(
    df, items_list, sociodemography_list,
    min_n = 1,
    with_weights = FALSE,
    weight_column = "w"
) {
    required_cols <- c("item", sociodemography_list, "value")
    missing_cols <- setdiff(required_cols, names(df))
    if (length(missing_cols) > 0) {
        stop(paste("Folgende Spalten fehlen im Dataframe:", paste(missing_cols, collapse = ", ")))
    }

    # Filter: nur ausgewählte Items, numerische Werte
    prepare_df <- df %>%
        filter(item %in% items_list) %>%
        mutate(value = as.numeric(value)) %>%
        # drop all rows containing at least one NA in sociodemography_list
        filter(!rowSums(is.na(across(all_of(sociodemography_list))))) %>%
        group_by(across(c(item, all_of(sociodemography_list)))) %>%
        drop_na(value)

    # Ungewichtete Statistiken
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
            median_conservative = case_when(
                median %% 1 == 0 ~ median,
                median > 10.5 ~ floor(median),
                median < 10.5 ~ ceiling(median),
                TRUE ~ median_integer
            ),
            sd = sd(value, na.rm = TRUE),
            lower_ci = quantile(x = value, probs = 0.025, na.rm = TRUE),
            upper_ci = quantile(x = value, probs = 0.975, na.rm = TRUE),
            n = n()
        ) %>%
        filter(n >= min_n)

    # Gewichtete Statistiken (optional)
    if (with_weights) {
        if (!weight_column %in% names(prepare_df)) {
            stop(paste("Die Spalte", weight_column, "ist im Dataframe nicht vorhanden."))
        }
        # Für weighted.median ggf. matrixStats oder Hmisc nötig
        if (!requireNamespace("matrixStats", quietly = TRUE)) {
            stop("Für gewichteten Median wird das Paket 'matrixStats' benötigt.")
        }
        stats_df_weighted <- prepare_df %>%
            drop_na({{weight_column}}) %>%
            reframe(
                mean_weighted = weighted.mean(value, w = .data[[weight_column]], na.rm = TRUE, trim = 0.05),
                median_weighted = matrixStats::weightedMedian(value, w = .data[[weight_column]], na.rm = TRUE),
                lower_ci_weighted = matrixStats::weightedQuantile(value, w = .data[[weight_column]], probs = 0.025, na.rm = TRUE),
                upper_ci_weighted = matrixStats::weightedQuantile(value, w = .data[[weight_column]], probs = 0.975, na.rm = TRUE)
            )
        stats_df <- bind_cols(stats_df, stats_df_weighted)
    }

    result_df <- stats_df %>%
        mutate(item = factor(item, levels = items_list)) %>%
        arrange(across(c(item, all_of(sociodemography_list))))

    n_per_group <- result_df %>% pull(n)
    message(paste0(
        "Gruppengröße: Minimum = ", min(n_per_group, na.rm = TRUE),
        ", Maximum = ", max(n_per_group, na.rm = TRUE),
        " Antworten pro Gruppe"
    ))

    return(result_df)
}
