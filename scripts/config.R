# In diesem Skript werden alle notwendigen Packages installiert und geladen.

# Packages laden ####
## Pacman als Paketmanager installieren, falls noch nicht vorhanden ####
# nur laden, wenn noch nicht installiert
if (!requireNamespace("pacman", quietly = TRUE)) {
  install.packages("pacman")
}

library(pacman)

## DatawRappr von github installieren, falls noch nicht vorhanden ####
if (!requireNamespace("DatawRappr", quietly = TRUE)) {
  pacman::p_install_gh("munichrocker/DatawRappr")
}

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
  spatstat.geom, # Statistiken mit Gewichtungen
  DatawRappr, # Visualisierung in Datawrapper
  dataverse # Zugriff auf Harvard Dataverse
)

# Hilfsfunktionen laden ####
source(here("scripts", "party_check_functions.R"))
