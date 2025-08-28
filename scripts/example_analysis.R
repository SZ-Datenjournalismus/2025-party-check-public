# Beispielanalyse von Daten aus Party Check

# Konfiguration laden ####
source("scripts/config.R")

# Gewichte für jede Gruppe auf Basis von Zensus-Daten berechnen ####
source(here("scripts", "weight_data.R"))

# annähernd repräsentative Stichprobe mit 2000 User:innen aus dem Party Check Datensatz ziehen ####
source(here("scripts", "calculate_quota_sample.R"))


