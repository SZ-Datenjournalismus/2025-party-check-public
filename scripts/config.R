# In diesem Skript werden alle notwendigen Packages installiert und geladen.

# Packages laden ####
## Pacman als Paketmanager installieren, falls noch nicht vorhanden ####
# nur laden, wenn noch nicht installiert
if (!requireNamespace("pacman", quietly = TRUE)) {
  install.packages("pacman")
}

library(pacman)

## alle anderen benötigten Pakete mit pacman laden ####
p_load(
  tidyverse, # Datenmanipulation
  lubridate, # Umgang mit Datumsformaten
  here, # Pfadmanagement
  eurostat, # Eurostat Zensus Daten
  data.table, # Datenmanipulation
  questionr, # Umfragen und Fragebögen
  survey, # Umfragen und Fragebögen
  roxygen2, # Dokumentation von Funktionen
  spatstat.geom # Statistiken mit Gewichtungen
)

# Hilfsfunktionen laden ####
source(here("scripts", "party_check_functions.R"))
