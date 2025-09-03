# In diesem Skript werden die Rohdaten beispielhaft gewichtet

# Konfiguration laden ####
source("scripts/config.R")

set.seed(123) # für Reproduzierbarkeit

# Bevölkerungsdaten von Eurostat herunterladen und aufbereiten ####
# Dieser Teil des Codes ist auskommentiert, da die Daten bereits heruntergeladen
# und in der Datei input/eurostat_census_de_2024.csv gespeichert sind.

## Bevölkerungsdaten herunterladen ####
# eurostat_census <- get_eurostat("lfst_r_lfsd2pop")
# 
# # Daten filtern und aufbereiten ####
# german_nuts <- c("DE1", "DE2", "DE3", "DE4", "DE5", "DE6", "DE7", "DE8", "DE9",
#                  "DEA", "DEB", "DEC", "DED", "DEE", "DEF", "DEG")
# age_groups <- c("Y15-24", "Y25-34", "Y35-44", "Y45-54", "Y55-64", "Y_GE65")
# 
# eurostat_census <- eurostat_census %>%
#   filter(
#     # nur deutsche NUTS-Regionen behalten
#     geo %in% german_nuts,
#     # nur relevante Altersgruppen behalten
#     age %in% age_groups,
#     # für die Europawahl 2024 nur die Bevölkerungsstruktur von 2024 behalten
#     TIME_PERIOD == "2024-01-01" # kann alternativ auf ein anderes Jahr geändert werden
#   )
# 
# # Altersgruppen erstellen
# eurostat_census <- eurostat_census %>%
#   mutate(
#     age = case_when(
#       age %in% c("Y15-24", "Y25-34") ~ 1,  # Junge Erwachsene
#       age == "Y35-44" ~ 3,                 # Mittleres Alter
#       age %in% c("Y45-54", "Y55-64") ~ 4,  # Ältere Erwachsene
#       age == "Y_GE65" ~ 5,                 # Senioren
#       TRUE ~ NA_real_
#     )
#   )
# 
# # NUTS-Regionen in Bundesländer umkodieren
# nuts_mapping <- c(
#   DE1 = "Baden-Württemberg",
#   DE2 = "Bayern",
#   DE3 = "Berlin",
#   DE4 = "Brandenburg",
#   DE5 = "Bremen",
#   DE6 = "Hamburg",
#   DE7 = "Hessen",
#   DE8 = "Mecklenburg-Vorpommern",
#   DE9 = "Niedersachsen",
#   DEA = "Nordrhein-Westfalen",
#   DEB = "Rheinland-Pfalz",
#   DEC = "Saarland",
#   DED = "Sachsen",
#   DEE = "Sachsen-Anhalt",
#   DEF = "Schleswig-Holstein",
#   DEG = "Thüringen"
# )
# 
# # Regionen erstellen und umkodieren
# eurostat_census <- eurostat_census %>%
#   mutate(
#     geo = recode(geo, !!!nuts_mapping),
#     geo2 = case_when(
#       geo %in% c("Bremen", "Hamburg", "Schleswig-Holstein", "Niedersachsen") ~ "HBHHSHNS",
#       geo %in% c("Rheinland-Pfalz", "Saarland", "Hessen") ~ "RPSLHE",
#       geo %in% c("Mecklenburg-Vorpommern", "Brandenburg") ~ "MVBB",
#       geo %in% c("Thüringen", "Sachsen-Anhalt", "Sachsen") ~ "THSTSN",
#       TRUE ~ geo
#     ),
#     # Geschlecht umkodieren: 1=männlich, 2=weiblich
#     sex = case_when(
#       sex == "F" ~ 2,
#       sex == "M" ~ 1
#     ),
#     # Bildung umkodieren: 1=Hochschulabschluss, 0=kein Hochschulabschluss
#     edu = case_when(
#       isced11 %in% c("ED0-2", "ED3_4") ~ 0,  # Kein Hochschulabschluss
#       isced11 == "ED5-8" ~ 1                 # Hochschulabschluss
#     )
#   )
# 
# # Nur relevante Variablen behalten und NAs entfernen
# eurostat_census <- eurostat_census %>%
#   select(sex, edu, age, geo2, values) %>%
#   drop_na() %>%
#   # Werte sind in Tausend, daher mit 1000 multiplizieren
#   mutate(values = values * 1000)
# 
# # Für Gewichtung zusammenfassen
# eurostat_census <- eurostat_census %>%
#   group_by(sex, edu, age, geo2) %>%
#   summarise(Freq = sum(values), .groups = "drop")
# 
# # Speichern der Zensus-Daten für spätere Verwendung
# write_csv(eurostat_census, here("input", "eurostat_census_de_2024.csv"))

# Umfragedaten einlesen und nach Zensus gewichten ####

# Fehlermeldung, wenn Daten nicht heruntergeladen sind
if (!file.exists(here(eupc_folder, "europartycheck_data_unweighted.tab"))) {
  stop("Die Datei europartycheck_data_unweighted.tab wurde nicht gefunden. Lade die Datei mit der Funktion download_euro_party_check() herunter.")
}

## Umfragedaten einlesen ####
pc_data_raw <- read_csv(here(eupc_folder, "europartycheck_data_unweighted.tab"), locale = locale(encoding = "UTF-8")) %>%
  # ID für späteres Zusammenführen erstellen
  mutate(id = row_number()) %>%
  # leere Antworten zu NA umwandeln
  mutate(across(where(is.character), ~ na_if(.x, "")))

## Zensus-Daten einlesen ####
eurostat_census <- read_csv(here("input", "eurostat_census_de_2024.csv"))

## Daten für Gewichtung vorbereiten, nur vollständige Zeilen filtern ####
# Bundesländer umkodieren
bundesland_mapping <- c(
  "1" = "Baden-Württemberg",
  "2" = "Bayern",
  "3" = "Berlin",
  "4" = "Brandenburg",
  "5" = "Bremen",
  "6" = "Hamburg",
  "7" = "Hessen",
  "8" = "Mecklenburg-Vorpommern",
  "9" = "Niedersachsen",
  "10" = "Nordrhein-Westfalen",
  "11" = "Rheinland-Pfalz",
  "12" = "Saarland",
  "13" = "Sachsen",
  "14" = "Sachsen-Anhalt",
  "15" = "Schleswig-Holstein",
  "16" = "Thüringen"
)

# Regionen erstellen
pc_data <- pc_data_raw %>%
  mutate(
    geo = recode(bundesland, !!!bundesland_mapping, .default = NA_character_),
    geo2 = case_when(
      geo %in% c("Bremen", "Hamburg", "Schleswig-Holstein", "Niedersachsen") ~ "HBHHSHNS",
      geo %in% c("Rheinland-Pfalz", "Saarland", "Hessen") ~ "RPSLHE",
      geo %in% c("Mecklenburg-Vorpommern", "Brandenburg") ~ "MVBB",
      geo %in% c("Thüringen", "Sachsen-Anhalt", "Sachsen") ~ "THSTSN",
      TRUE ~ geo
    )
  )

# User:innen, die die Umfrage zu schnell abgeschlossen haben, identifizieren und entfernen
pc_data <- pc_data %>%
  mutate(
    datestamp = as.POSIXct(datestamp, format="%Y-%m-%d %H:%M:%S"),
    startdate = as.POSIXct(startdate, format="%Y-%m-%d %H:%M:%S"),
    time = as.numeric(datestamp - startdate),
    speeder = time < 170
  ) %>%
  filter(!speeder)

# Kernvariablen definieren und unvollständige Fälle entfernen
items <- c("gender", "bundesland", "age", "education", "university", 
           "econinterven", "environment", "protectionism", "redistribution", 
           "eucohesion", "euenlargement", "euforeign", "euintegrationtoofar", 
           "euposition", "civliblaworder", "immigratepolicy", "lgb", 
           "multiculturalism", "trans", "urbanrural")

pc_data <- pc_data[complete.cases(pc_data[, items]), ]

# Variablen für Gewichtung umkodieren
pc_data <- pc_data %>%
  # Bildung umkodieren
  mutate(
    edu = if_else(university == 1, 1, 0)
  ) %>%
  # Unplausible Fälle entfernen
  filter(!(university == 1 & (education == 1 | education == 7))) %>%
  # Alter umkodieren
  mutate(
    age = case_when(
      age <= 5 ~ 1,                # Junge Erwachsene
      age >= 6 & age <= 7 ~ 3,     # Mittleres Alter
      age >= 8 & age <= 11 ~ 4,    # Ältere Erwachsene
      age >= 12 & age <= 15 ~ 5,   # Senioren
      TRUE ~ NA_real_
    ),
    # Geschlecht umkodieren: 1=männlich, 2=weiblich
    sex = case_when(
      gender == 1 ~ 1,
      gender == 2 ~ 2,
      TRUE ~ NA_real_
    )
  )

# Daten für Gewichtung vorbereiten
pc_weight_data <- pc_data %>%
  select(id, sex, age, edu, geo2) %>%
  drop_na()

## Zensus-Daten vorbereiten ####
eurostat_census <- eurostat_census %>%
  mutate(sex = as.numeric(sex)) %>%
  select(sex, edu, age, geo2, Freq) %>%
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
  sample.margins = list(~sex+age+edu+geo2),
  population.margins = list(eurostat_census_weights),
  control = list(maxit = 50)
)

# Gewichte extrahieren und prüfen
weights_df <- tibble(
  id = pc_weight_data$id,
  w = weights(pc_data_r)
)

# Überprüfung der Gewichte
cat("Bereich der Gewichte:", range(weights_df$w), "\n")
cat("Summe der Gewichte:", sum(weights_df$w), "(sollte der Stichprobengröße entsprechen)\n")

## Gewichte exportieren ####
write_csv(eurostat_census_weights, here("input", "eurostat_census_de_2024_weights.csv"))
pc_weight_data_export <- pc_weight_data %>%
  bind_cols(w = weights(pc_data_r))
write_csv(pc_weight_data_export, here("input", "party_check_data_weights_per_group.csv"))

## Gewichte mit Originaldaten zusammenführen ####
pc_data_final <- pc_data_raw %>%
  left_join(weights_df, by = "id") %>%
  filter(!is.na(w))

# Gewichtete Daten speichern
write_csv(pc_data_final, here("input", "party_check_data_weighted.csv"))

message("Gewichtete Daten wurden erfolgreich berechnet und gespeichert.")

