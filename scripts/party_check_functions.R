# Funktionen, um Daten aus Party Check aufzubereiten und zu analysieren

#' Berechnet statistische Kennzahlen für ausgewählte Items und soziodemographische Gruppen
#'
#' Diese Funktion berechnet verschiedene statistische Kennzahlen (Median, Mittelwert, Standardabweichung, 
#' Konfidenzintervalle) für numerische Variablen, gruppiert nach Items und soziodemographischen Merkmalen.
#'
#' @param df Ein Dataframe, der mindestens die Spalten 'item', 'value', 'question' und die in 
#'           sociodemography_list angegebenen Spalten enthält.
#' @param items_list Ein Vektor mit den Namen der Items, für die Statistiken berechnet werden sollen.
#'                   Diese müssen in der Spalte 'item' des Dataframes vorhanden sein.
#' @param sociodemography_list Ein Vektor mit den Namen der soziodemographischen Variablen, nach denen
#'                             gruppiert werden soll (z.B. "gender", "age", "education").
#' @param with_weights Logischer Wert, der angibt, ob die Berechnungen mit Gewichten durchgeführt werden sollen. Default TRUE.
#'                     Nur möglich, wenn eine Spalte mit Gewichten im Dataframe vorhanden ist.
#' @param weight_column Der Name der Spalte, die die Gewichte enthält, falls with_weights = TRUE. Default "w".
#'
#' @return Ein Dataframe mit den berechneten statistischen Kennzahlen für jede Kombination von Item und
#'         soziodemographischen Gruppen. Enthält die Spalten:
#'         - item: Das ausgewählte Item
#'         - Die angegebenen soziodemographischen Variablen
#'         - median: Der Median der Werte
#'         - mean: Der getrimmte Mittelwert (25% Trimming)
#'         - median_integer: Ein auf ganze Zahlen gerundeter Median
#'         - sd: Die Standardabweichung
#'         - lower_ci: Die untere Grenze des 95%-Konfidenzintervalls
#'         - upper_ci: Die obere Grenze des 95%-Konfidenzintervalls
#'         - n: Die Anzahl der Beobachtungen in der Gruppe
#'
#' @examples
#' # Beispiel:
#' # stats_df <- calculate_pc_stats(
#' #   df = survey_data,
#' #   items_list = c("econinterven", "environment", "protectionism"),
#' #   sociodemography_list = c("gender", "age"),
#' #   with_weights = TRUE
#' # )
calculate_pc_stats <- function(df, items_list, sociodemography_list, with_weights = FALSE, weight_column = "w") {
  # Überprüfen, ob die erforderlichen Spalten im Dataframe vorhanden sind
  required_cols <- c("item", "value")
  missing_cols <- setdiff(c(required_cols, sociodemography_list), names(df))
  
  if (length(missing_cols) > 0) {
    stop(paste("Folgende Spalten fehlen im Dataframe:", 
               paste(missing_cols, collapse = ", ")))
  }
  
  # Dataframe filtern und vorbereiten
  if (with_weights) {
    # Überprüfen, ob die Gewichtungsspalte vorhanden ist
    if (!weight_column %in% names(df)) {
      stop(paste("Die Spalte", weight_column, "ist im Dataframe nicht vorhanden."))
    }
    
    selected_df <- df %>%
      select(item, value, all_of(sociodemography_list), all_of(weight_column))
  } else {
    selected_df <- df %>%
      select(item, value, all_of(sociodemography_list))
  }
  
  prepare_df <- selected_df %>%
    # Nur die angegebenen Items behalten
    filter(item %in% items_list) %>%
    # Werte in numerisches Format umwandeln
    mutate(value = as.numeric(value)) %>%
    # Zeilen mit NA-Werten in den soziodemographischen Variablen entfernen
    filter(if_all(all_of(sociodemography_list), ~ !is.na(.))) %>%
    # Nach Item, soziodemographischen Variablen und Frage gruppieren
    group_by(across(c(item, all_of(sociodemography_list)))) %>%
    # Zeilen mit NA-Werten in der Value-Spalte entfernen
    drop_na(value)
  
  if (with_weights) {
    # Mit Gewichten arbeiten
    stats_df_weight_columns <- prepare_df %>%
      drop_na(weight_column) %>%
      reframe(
        # Berechnung der gewichteten Mittelwerte
        mean_weighted = weighted.mean(x = value, w = !!sym(weight_column), na.rm = TRUE, trim = 0.05),
        # Median der Werte unter Berücksichtigung der Gewichte
        median_weighted = weighted.median(x = value, w = !!sym(weight_column), na.rm = TRUE),
        # Konfidenzintervall gewichtet
        lower_ci_weighted = quantile(x = value, probs = 0.025, na.rm = TRUE, weights = !!sym(weight_column)),
        upper_ci_weighted = quantile(x = value, probs = 0.975, na.rm = TRUE, weights = !!sym(weight_column))
      )
  }
  
  stats_df <- prepare_df %>%
    # Statistische Kennzahlen berechnen
    reframe(
      # Median der Werte
      median = median(value, na.rm = TRUE),
      # Getrimmter Mittelwert (25% der extremsten Werte werden entfernt)
      mean = mean(value, na.rm = TRUE, trim = 0.25),
      # Berechnung eines ganzzahligen Medians nach speziellen Regeln:
      # - Wenn Median bereits ganzzahlig ist, behalte ihn
      # - Wenn Median nicht durch 0.5 teilbar ist, runde normal
      # - Sonst runde auf oder ab, je nachdem was näher am Mittelwert liegt
      median_integer = case_when(
        median %% 1 == 0 ~ median,
        median %% 0.5 != 0 ~ round(median),
        abs(mean - floor(median)) < abs(mean - ceiling(median)) ~ floor(median),
        TRUE ~ ceiling(median)
      ),
      # Standardabweichung
      sd = sd(value, na.rm = TRUE),
      # Untere Grenze des 95%-Konfidenzintervalls (2.5%-Quantil)
      lower_ci = quantile(x = value, probs = 0.025, na.rm = TRUE),
      # Obere Grenze des 95%-Konfidenzintervalls (97.5%-Quantil)
      upper_ci = quantile(x = value, probs = 0.975, na.rm = TRUE),
      # Anzahl der Beobachtungen in der Gruppe
      n = n()
    )
  
  if (with_weights) {
    # Wenn mit Gewichten gearbeitet wird, die gewichteten Statistiken hinzufügen
    stats_df <- stats_df %>%
      bind_cols(stats_df_weight_columns %>%
                  select(
                    mean_weighted, 
                    median_weighted, 
                    lower_ci_weighted, 
                    upper_ci_weighted
                  ))
  }
  
  result_df <- stats_df %>%
    # Items als Faktoren mit der vorgegebenen Reihenfolge definieren
    mutate(
      item = factor(item, levels = items_list)
    ) %>%
    # Nach Items und soziodemographischen Variablen sortieren
    arrange(across(c(item, all_of(sociodemography_list))))
  
  # Informationen über die Gruppengröße ausgeben
  n_per_group <- result_df %>% pull(n)
  
  message(paste0(
    "Gruppengröße: Minimum = ", min(n_per_group, na.rm = TRUE), 
    ", Maximum = ", max(n_per_group, na.rm = TRUE), 
    " Antworten pro Gruppe"
  ))
  
  return(result_df)
}
