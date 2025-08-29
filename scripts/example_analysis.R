# Beispielanalyse von Daten aus Party Check

# Konfiguration laden ####
source("scripts/config.R")

# Gewichte für jede Gruppe auf Basis von Zensus-Daten berechnen ####
source(here("scripts", "weight_data.R"))

# annähernd repräsentative Stichprobe mit 2000 User:innen aus dem Party Check Datensatz ziehen ####
source(here("scripts", "calculate_quota_sample.R"))

# Daten für die Analyse vorbereiten ####
# Daten werden hier in weight_data.R geladen und vorbereitet
# hier nur ein Auszug aus den verfügbaren Items
items <- c(
  "lrgen",                # generelle politische Orientierung
  "econinterven",         # Sollte der Staat in die Wirtschaft eingreifen?
  "environment",          # Umwelt- und Klimaschutz vor Wirtschaft?
  "protectionsism",       # Freihandel oder Protektionismus?
  "redistribution",       # Soll der Staat umverteilen?
  "eucohesion",           # Soll die EU mehr Geld für ärmere Regionen ausgeben?
  "euenlargement",        # Soll die EU weiter wachsen?
  "euforeign",            # Soll die EU eine gemeinsame Außenpolitik haben?
  "euintegrationtoofar",  # Ist die EU-Integration zu weit fortgeschritten?
  "euposition",           # Generelle Haltung zur EU
  "civliblaworder",       # Bürgerrechte vs. Sicherheit
  "immigratepolicy",      # Einwanderungspolitik
  "lgb",                  # Einstellung zu LGBTQ+ Themen
  "multiculturalism",     # Einstellung zu Multikulturalismus
  "trans"                 # Transgender Rechte
)

sociodemography <- c(
  "recall",               # gewählte Partei (Zweitstimme) bei der Bundestagswahl 2021
  "votinteu",             # Wahlabsicht (Partei) bei der Europawahl 2024
  "gender",               # Geschlecht
  "bundesland",           # Bundesland
  "age",                  # Alter
  "education",            # Bildungsniveau
  "university",           # Hochschulbildung (1=ja, 2=nein)
  "recall",               # gewählte Partei (Zweitstimme) bei der Bundestagswahl 2021
  "recallland",           # gewählte Partei (Zweitstimme) bei der Landtagswahl 2019, nur für Befragte in Brandenburg, Thüringen und Sachsen
  "votinteu",             # Wahlabsicht (Partei) bei der Europawahl 2024
  "votint",               # Wahlabsicht (Partei) bei der Bundestagswahl 2025
  "urbanrurallive",       # Selbsteinschätzung der Größe des Wohnorts
  "socself"               # Soziale Selbstidentifikation (1=konservativ, 11=progressiv)
)

party_proxy_items <- c( # Frage nach der Wahrscheinlichkeit, in Zukunft die Partei zu wählen
  "ptv_spd", "ptv_cdu", "ptv_csu", "ptv_greens", "ptv_fdp", "ptv_fdp", "ptv_left", "ptv_bsw", "ptv_freevoters", "ptv_volt", "ptv_climatelist"
)

# Daten in langes Format bringen
pc_data_long <- pc_data_final %>%
  pivot_longer(cols = -c(all_of(c("id", "startdate", "datestamp", sociodemography, names(party_proxy_items), "w"))),
               names_to = "item",
               values_to = "value",
               values_transform = list(value = as.character))

# Geschlecht, Bundesland und Alter umcodieren
pc_data_long <- pc_data_long %>%
  mutate(gender = case_when(gender == 1 ~ "male",
                            gender == 2 ~ "female",
                            gender == 3 ~ "diverse",
                            gender == 4 ~ "other"),
         bundesland = recode(bundesland, !!!bundesland_mapping, .default = NA_character_),
         age = case_when(
           age == 98 ~ "< 16",
           age == 1 ~ "16-17",
           age == 2 ~ "18-20",
           age == 3 ~ "21-24",
           age == 4 ~ "25-29",
           age == 5 ~ "30-34",
           age == 6 ~ "35-39",
           age == 7 ~ "40-44",
           age == 8 ~ "45-49",
           age == 9 ~ "50-54",
           age == 10 ~ "55-59",
           age == 11 ~ "60-64",
           age == 12 ~ "65-69",
           age == 13 ~ "70-74",
           age == 14 ~ "75-79",
           age == 15 ~ "> 80"
         ))

# Statistische Kennzahlen für ausgewählte Items und soziodemographische Gruppen berechnen ####
pc_stats_df <- calculate_pc_stats(df = pc_data_long,
                                  items_list = items, 
                                  sociodemography_list = c("gender", "bundesland", "age"), 
                                  with_weights = TRUE)
