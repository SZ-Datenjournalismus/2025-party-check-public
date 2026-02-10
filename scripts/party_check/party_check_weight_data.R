# In diesem Skript werden die Rohdaten beispielhaft gewichtet

# Konfiguration laden ####
source("scripts/config.R")

set.seed(123) # für Reproduzierbarkeit

# Bevölkerungsdaten von Eurostat herunterladen und aufbereiten ####
# Dieser Teil des Codes ist auskommentiert, da die Daten bereits heruntergeladen
# und in der Datei input/eurostat_census_de_2024.csv gespeichert sind.

## Bevölkerungsdaten herunterladen ####
eurostat_census <- get_eurostat("lfst_r_lfsd2pop")

# Daten filtern und aufbereiten ####
german_nuts <- c("DE1", "DE2", "DE3", "DE4", "DE5", "DE6", "DE7", "DE8", "DE9",
                 "DEA", "DEB", "DEC", "DED", "DEE", "DEF", "DEG")
age_groups <- c("Y15-24", "Y25-34", "Y35-44", "Y45-54", "Y55-64", "Y_GE65")

eurostat_census <- eurostat_census %>%
  filter(
    # nur deutsche NUTS-Regionen behalten
    geo %in% german_nuts,
    # nur relevante Altersgruppen behalten
    age %in% age_groups,
    # für die Europawahl 2024 nur die Bevölkerungsstruktur von 2024 behalten
    TIME_PERIOD == "2024-01-01" # kann alternativ auf ein anderes Jahr geändert werden
  )
 
# NUTS-Regionen in Bundesländer umkodieren
nuts_mapping <- c(
  DE1 = "Baden-Württemberg",
  DE2 = "Bayern",
  DE3 = "Berlin",
  DE4 = "Brandenburg",
  DE5 = "Bremen",
  DE6 = "Hamburg",
  DE7 = "Hessen",
  DE8 = "Mecklenburg-Vorpommern",
  DE9 = "Niedersachsen",
  DEA = "Nordrhein-Westfalen",
  DEB = "Rheinland-Pfalz",
  DEC = "Saarland",
  DED = "Sachsen",
  DEE = "Sachsen-Anhalt",
  DEF = "Schleswig-Holstein",
  DEG = "Thüringen"
)

# Regionen erstellen und umkodieren
eurostat_census <- eurostat_census %>%
  mutate(
    geo = recode(geo, !!!nuts_mapping, .default = NA_character_),
    # Bildung umkodieren: niedrige Bildung bis Realschulabschluss, höhere Bildung ab Realschulabschluss
    edu = case_when(
      isced11 %in% c("ED0-2") ~ "bis Realschulabschluss",
      isced11 %in% c("ED3_4","ED5-8") ~ "höhere Bildung"
    )
  )

# nur BW
eurostat_census <- eurostat_census %>%
  filter(geo == "Baden-Württemberg")

# Nur relevante Variablen behalten und NAs entfernen
eurostat_census <- eurostat_census %>%
  select(sex, edu, age, values) %>%
  filter(sex %in% c("M", "F")) %>%
  drop_na() %>%
  # Werte sind in Tausend, daher mit 1000 multiplizieren
  mutate(values = values * 1000)

# Für Gewichtung zusammenfassen
eurostat_census <- eurostat_census %>%
  group_by(sex, edu, age) %>%
  summarise(Freq = sum(values), .groups = "drop")

# Speichern der Zensus-Daten für spätere Verwendung
# write_csv(eurostat_census, here("input", "eurostat_census_de_2024.csv"))

# Umfragedaten einlesen und nach Zensus gewichten ####



## Umfragedaten verarbeiten ####
# einlesen in read_party_check.R, hier nur die Gewichtung
pc_data <- party_check_results_clean

# Kernvariablen definieren und unvollständige Fälle entfernen
sociodem <- c("gender", "bundesland", "age", "educationschool", "votintlandpre")
items <- c(
  "lrecon", "childcare", "communityschool",
  "peopledecision", "genderlanguage", "liberalism",
  "lawandorder", "immigration", "asylumbenefit", "publicdebt",
  "rentcontrol", "afdcoop", "stadtbild", "renewenergy", "cars",
  "climatepolicy"
) %>%
  paste0("_SQ001")

pc_data <- pc_data[complete.cases(pc_data[, c(sociodem, items)]), ]

# Variablen für Gewichtung umkodieren
pc_data <- pc_data %>%
  # Bildung umkodieren
  mutate(
    edu = case_when(educationschool %in% c(
      "Schule beendet ohne Abschluss",
      "Hauptschulabschluss, Volksschulabschluss, Abschluss der polytechnischen Oberschule 8. oder 9. Klasse",
      "Realschulabschluss, Mittlere Reife, Fachschulreife oder Abschluss der polytechnischen Oberschule 10. Klasse"
    ) ~ "bis Realschulabschluss",
    educationschool %in% c(
      "Fachhochschulreife (Abschluss einer Fachoberschule, etc.)",
      "Abitur oder erweiterte Oberschule mit Abschluss 12. Klasse (Hochschulreife)"
    ) ~ "höhere Bildung")
  ) %>%
  # Alter umkodieren
  mutate(
    age = case_when(
      age %in% c(
        "16 bis 17 Jahre",
        "18 bis 20 Jahre",
        "21 bis 24 Jahre"
      ) ~ "Y15-24",
      age %in% c(
        "25 bis 29 Jahre",
        "30 bis 34 Jahre"
      ) ~ "Y25-34",
      age %in% c(
        "35 bis 39 Jahre",
        "40 bis 44 Jahre"
      ) ~ "Y35-44",
      age %in% c(
        "45 bis 49 Jahre",
        "50 bis 54 Jahre"
      ) ~ "Y45-54",
      age %in% c(
        "55 bis 59 Jahre",
        "60 bis 64 Jahre"
      ) ~ "Y55-64",
      age %in% c(
        "65 bis 69 Jahre",
        "70 bis 74 Jahre",
        "75 bis 79 Jahre",
        "80 Jahre und älter"
      ) ~ "Y_GE65"
    ),
    # Geschlecht umkodieren
    sex = case_when(
      gender == "Mann" ~ "M",
      gender == "Frau" ~ "F"
    )
  )

# Daten für Gewichtung vorbereiten
pc_weight_data <- pc_data %>%
  select(id, sex, age, edu) %>%
  drop_na()

## Zensus-Daten vorbereiten ####
eurostat_census <- eurostat_census %>%
  select(sex, edu, age, Freq) %>%
  drop_na()

## Gewichtung mit survey::rake ####
# Berechne Anteile für die Gewichtung
eurostat_census_weights <- eurostat_census %>%
  mutate(
    pct = Freq / sum(Freq),
    Freq = pct * nrow(pc_weight_data)
  ) %>%
  select(-pct)

# Survey-Design erstellen
data_w <- svydesign(ids = ~id, data = pc_weight_data)

# Raking durchführen
pc_data_r <- rake(
  design = data_w, 
  sample.margins = list(~sex+age+edu),
  population.margins = list(eurostat_census_weights),
  control = list(maxit = 50)
)

# Gewichte extrahieren und prüfen
weights_socdem_df <- tibble(
  id = pc_weight_data$id,
  w = weights(pc_data_r)
)

# Überprüfung der Gewichte
cat("Bereich der Gewichte:", range(weights_socdem_df$w), "\n")
cat("Summe der Gewichte:", sum(weights_socdem_df$w), "(sollte der Stichprobengröße entsprechen)\n")

# Zusätzliche Gewichtung nach Umfragedaten (votint_calc) ####

# Umfragedaten vorbereiten (Stand 2026-02-10)
parties <- c(
  "Grüne", "CDU", "Die Linke", "AfD", "SPD", "FDP", "BSW"
)

polls_bw <- tibble(
  votintland_calc = parties,
  poll_pct = c(21.25, 29.25, 6.97, 20.22, 9.43, 5.17, 3.05)
)
# Sonstige berechnen
polls_bw <- polls_bw %>%
  bind_rows(
    tibble(
      votintland_calc = "Sonstige",
      poll_pct = 100 - sum(polls_bw$poll_pct, na.rm = TRUE)
    )
  ) %>%
  drop_na()

# Party Check Daten vorbereiten
pc_data_votintland <- party_check_results_clean %>%
  mutate(votintland_calc = case_when(
    votintland_calc %in% parties ~ votintland_calc,
    !votintland_calc %in% c("Weiß ich nicht", "Würde nicht wählen gehen", "keine Angabe", "Ich wäre nicht wahlberechtigt", NA) ~ "Sonstige"
  ))

# Kernvariablen definieren und unvollständige Fälle entfernen
sociodem <- c("gender", "bundesland", "age", "educationschool", "votintland_calc")
items <- c(
  "lrecon", "childcare", "communityschool",
  "peopledecision", "genderlanguage", "liberalism",
  "lawandorder", "immigration", "asylumbenefit", "publicdebt",
  "rentcontrol", "afdcoop", "stadtbild", "renewenergy", "cars",
  "climatepolicy"
) %>%
  paste0("_SQ001")

pc_data_votintland <- pc_data_votintland[complete.cases(pc_data_votintland[, c(sociodem, items)]), ]

# Daten für Gewichtung vorbereiten
pc_weight_data_votintland <- pc_data_votintland %>%
  select(id, votintland_calc) %>%
  drop_na()

## Gewichtung mit survey::rake
# Berechne Anteile für die Gewichtung
polls_bw_weights <- polls_bw %>%
  mutate(
    pct = poll_pct / sum(poll_pct),
    Freq = pct * nrow(pc_weight_data_votintland)
  ) %>%
  select(-pct, -poll_pct)

# Survey-Design erstellen
data_w_votintland <- svydesign(ids = ~id, data = pc_weight_data_votintland)

# Raking durchführen
pc_data_r_votintland <- rake(
  design = data_w_votintland,
  sample.margins = list(~ votintland_calc),
  population.margins = list(polls_bw_weights),
  control = list(maxit = 50)
)

# Gewichte extrahieren und prüfen
weights_votintland_df <- tibble(
  id = pc_weight_data_votintland$id,
  w_votintland_calc = weights(pc_data_r_votintland)
)

# Überprüfung der Gewichte
cat("Bereich der Gewichte nach Umfragedaten:", range(weights_votintland_df$w_votintland_calc), "\n")
cat("Summe der Gewichte nach Umfragedaten:", sum(weights_votintland_df$w_votintland_calc), "(sollte der Stichprobengröße entsprechen)\n")
