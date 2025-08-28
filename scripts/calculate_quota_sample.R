# In diesem Skript wird aus dem Party Check Datensatz und den via Zensus berechneten Gewichten
# eine annähernd repräsentative Stichprobe (n = 2000) erstellt.

# Konfiguration laden ####
source("scripts/config.R")

# Gewichte berechnen (wenn noch nicht geschehen) ####
# source("scripts/weight_data.R")

set.seed(123456) # für Reproduzierbarkeit

# Daten einlesen und vorbereiten ####
pc_data_weights <- read_csv(here("input", "party_check_data_weights_per_group.csv"), locale = locale(encoding = "UTF-8"))

pc_data <- read_csv(here("input", "party_check_data_weighted.csv"), locale = locale(encoding = "UTF-8")) %>%
  select(-w, -age)  # nicht benötigte Spalten entfernen

# Datensätze zusammenführen
pc_data_weighted <- pc_data %>%
  left_join(pc_data_weights, by = "id") %>%
  filter(!is.na(w))  # Fälle ohne Gewichte entfernen

# Datenbereinigung: NAs in EU-Voting und anderen wichtigen Variablen entfernen
pc_data_weighted <- pc_data_weighted %>%
  mutate(votinteu = if_else(votinteu > 90, NA_real_, votinteu)) %>%
  filter(!is.na(votinteu) & !is.na(antielitism) & !is.na(peoplecentrism) & !is.na(lrgen))

# Stichprobe ziehen mit Gewichtung ####
samp_idx <- sample(seq_len(nrow(pc_data_weighted)), 2000, prob = pc_data_weighted$w)
pc_data_weighted <- pc_data_weighted[samp_idx, ]

# Zensus-Daten für Gruppen einlesen
eurostat_census_weights <- read_csv(here("input", "eurostat_census_de_2024_weights.csv"))

# Daten für Gewichtung vorbereiten
weight_data <- pc_data_weighted %>%
  select(id, sex, age, edu, geo2) %>%
  drop_na()

# Survey-Design erstellen
rv_ger.d <- svydesign(ids = ~id, data = weight_data)

# Gewichte anpassen, damit sie zur Stichprobengröße passen
eurostat_census_weights <- eurostat_census_weights %>%
  mutate(
    pct = Freq / sum(Freq),
    Freq = pct * nrow(weight_data)
  ) %>%
  select(-pct)

# Raking durchführen ####
rv_ger.r <- rake(
  design = rv_ger.d, 
  sample.margins = list(~sex+age+edu+geo2),
  population.margins = list(eurostat_census_weights),
  control = list(maxit = 50)
)

# Überprüfung der Gewichte
cat("Bereich der Gewichte:", range(weights(rv_ger.r)), "\n")
cat("Summe der Gewichte:", sum(weights(rv_ger.r)), "(sollte der Stichprobengröße entsprechen)\n")

# Gewichte extrahieren
weights_df <- tibble(
  id = weight_data$id,
  w = weights(rv_ger.r)
)

# Gewichte mit Originaldaten zusammenführen ####
pc_data_quota_sample <- read_csv(here("input", "party_check_data_weighted.csv"), locale = locale(encoding = "UTF-8")) %>%
  select(-w) %>%
  left_join(weights_df, by = "id") %>%
  filter(!is.na(w)) %>%
  mutate(across(where(is.character), ~na_if(., "")))  # leere Strings zu NA umwandeln

# Überprüfung der EU-Voting-Verteilung
print(table(pc_data_quota_sample$votinteu))

# Gewichtete Daten speichern ####
write_csv(pc_data_quota_sample, here("input", "party_check_data_quota_weighted.csv"))
