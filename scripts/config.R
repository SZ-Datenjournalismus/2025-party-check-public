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
  here # Pfadmanagement
)