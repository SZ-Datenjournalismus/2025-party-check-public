# Beispielanalyse von Daten aus Party Check

# Konfiguration laden ####
source("scripts/config.R")

# Daten des Euro Party Check herunterladen ####
eupc_folder <- download_euro_party_check(doi = "10.7910/DVN/7PBJS9")

# Gewichte für jede Gruppe auf Basis von Zensus-Daten berechnen ####
source(here("scripts", "weight_data.R"))

# annähernd repräsentative Stichprobe mit 2000 User:innen aus dem Party Check Datensatz ziehen ####
source(here("scripts", "calculate_quota_sample.R"))

# Codebook laden ####
# Vorsicht, Codebook wurde mit Hilfe von KI erstellt und nicht vollständig geprüft!
eupc_codebook <- read_csv(here("input", "codebook_eu_party_check.csv"))

# Daten für die Analyse vorbereiten ####
# Daten werden hier in weight_data.R geladen und vorbereitet
# hier nur ein Auszug aus den verfügbaren Items
items <- c(
  "lrgen",                # generelle politische Orientierung
  "econinterven",         # Sollte der Staat in die Wirtschaft eingreifen?
  "environment",          # Umwelt- und Klimaschutz vor Wirtschaft?
  "protectionism",       # Freihandel oder Protektionismus?
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
  "gender",               # Geschlecht
  "bundesland",           # Bundesland
  "age",                  # Alter
  "education",            # Bildungsniveau
  "university",           # Hochschulbildung (1=ja, 2=nein)
  "recall",               # gewählte Partei (Zweitstimme) bei der Bundestagswahl 2021
  "recallland",           # gewählte Partei (Zweitstimme) bei der Landtagswahl 2019, nur für Befragte in Brandenburg, Thüringen und Sachsen
  "recallland_other",     # andere Partei bei der Landtagswahl 2019, nur für Befragte in Brandenburg, Thüringen und Sachsen
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
  pivot_longer(cols = -c(all_of(c("id", "startdate", "datestamp", sociodemography, party_proxy_items, "w"))),
               names_to = "item",
               values_to = "value",
               values_transform = list(value = as.character))

# Geschlecht, Bundesland, Alter etc. umcodieren
# sociodemography ohne recallland_other und socself
for (item in setdiff(sociodemography, c("recallland_other", "socself"))) {
  if (item %in% names(pc_data_long)) {
    pc_data_long <- pc_data_long %>%
      recode_with_codebook(item, eupc_codebook)
  }
}

# Statistische Kennzahlen für ausgewählte Items und soziodemographische Gruppen berechnen ####
pc_stats_df <- calculate_pc_stats(df = pc_data_long,
                                  items_list = items, 
                                  sociodemography_list = c("gender", "bundesland", "age"), 
                                  with_weights = TRUE)

# nach Parteipräferenz (Wahlabsicht 2025)
calculate_pc_stats(pc_data_long,
                   items_list = c("lrgen", "econinterven", "immigratepolicy", "environment", "protectionism"),
                   sociodemography_list = c("votint"),
                   with_weights = TRUE) %>%
  view()
# nach Parteipräferenz (Wahlabsicht 2025) und Wahlentscheidung BTW21
calculate_pc_stats(pc_data_long,
                   items_list = c("lrgen", "econinterven", "immigratepolicy", "environment", "protectionism"),
                   sociodemography_list = c("votint", "recall"),
                   with_weights = TRUE) %>%
  filter(n >= 20) %>%
  view()
# nach Alter und Parteipräferenz (Wahlabsicht 2025)
calculate_pc_stats(pc_data_long,
                   items_list = c("lrgen", "econinterven", "immigratepolicy", "environment", "protectionism"),
                   sociodemography_list = c("age", "votint"),
                   with_weights = TRUE) %>%
  view()

# nach Alter (grob jung und alt) und Parteipräferenz (Wahlabsicht 2025)
calculate_pc_stats(pc_data_long %>%
                     mutate(age = case_when(age %in% (eupc_codebook %>% filter(item == "age") %>% mutate(value = as.integer(value)) %>% filter(value < 5 | value == 98) %>% pull(text)) ~ "unter 30 Jahre",
                                            age %in% (eupc_codebook %>% filter(item == "age") %>% mutate(value = as.integer(value)) %>% filter(value > 10, value < 98) %>% pull(text)) ~ "über 60 Jahre",
                                            age %in% (eupc_codebook %>% filter(item == "age") %>% mutate(value = as.integer(value)) %>% filter(value %in% 5:10) %>% pull(text)) ~ "30 bis 59 Jahre")),
                   items_list = c("lrgen", "econinterven", "immigratepolicy", "environment", "protectionism"),
                   sociodemography_list = c("age", "votint"),
                   with_weights = TRUE) %>%
  arrange(item, factor(age, levels = c("unter 30 Jahre", "30 bis 59 Jahre", "über 60 Jahre"))) %>%
  view()

# nach Stadt/Land (Wahlabsicht 2025)
calculate_pc_stats(pc_data_long %>%
                     mutate(urbanrurallive = case_when(urbanrurallive %in% (eupc_codebook %>% filter(item == "urbanrurallive") %>% mutate(value = as.integer(value)) %>% filter(value <= 3) %>% pull(text)) ~ "Stadt",
                                                       urbanrurallive %in% (eupc_codebook %>% filter(item == "urbanrurallive") %>% mutate(value = as.integer(value)) %>% filter(value > 3) %>% pull(text)) ~ "Land")),
                   items_list = c("lrgen", "econinterven", "immigratepolicy", "environment", "protectionism"),
                   sociodemography_list = c("urbanrurallive"),
                   with_weights = TRUE) %>%
  arrange(item, urbanrurallive) %>%
  view()

# alternative Gewichtung z.B. nach repräsentativer Wahlstatistik
eu_wahlstatistik <- read_csv2("https://www.bundeswahlleiterin.de/dam/jcr/94c9a6f3-37aa-448d-9f52-afb592d8cf7a/ew24_rws_est2.csv",
                              skip = 11)
eu_wahlbeteiligung <- read_csv2("https://www.bundeswahlleiterin.de/dam/jcr/255d85ae-ef1f-4be3-9add-ef24bbbaaf4e/ew24_rws_ew2.csv",
                                skip = 11)
# wir wählen nur die wichtigsten Parteien > 2 % aus
eu_wahlstatistik_selected <- eu_wahlstatistik %>%
  # CDU und CSU aufsummieren
  mutate("CDU/CSU" = sum(CDU, CSU, na.rm = TRUE)) %>%
  pivot_longer(cols= -c(1:4), names_to = "party", values_to = "votes") %>%
  mutate(pct = votes / Summe) %>%
  filter(pct > 0.02,
         !party %in% c("CDU", "CSU")) %>%
  mutate(party = case_when(
    party %in% c("GRÜNE", "DIE LINKE") ~ str_to_title(party),
    party == "dar. BSW" ~ "BSW",
    party == "dar. FREIE WÄHLER" ~ "Freie Wähler",
    TRUE ~ party
  ))

# 

