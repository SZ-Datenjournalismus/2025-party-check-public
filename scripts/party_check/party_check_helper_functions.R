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
