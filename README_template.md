# PROJEKTNAME

Hier wird das Projekt in Kürze beschrieben und wichtige Dokumente werden verlinkt. Was ist das Ziel der Analyse? Welche Kontextinformationen sind wichtig?

- **Artikel:** Link zur Veröffentlichung

## Datenquellen

Woher stammen die Daten?

## Verwendung

Hier wird das technische Setup der Analyse beschgi tsrieben. Welche Schritte müssen ausgeführt werden, um die Analyse starten zu können?

1. Repository klonen ```git clone git@github.com:SZ-Datenjournalismus/data-analysis-r-template.git```
2. AWS-Credentials in ```.Renviron``` ablegen
3. Code-chunks in ```main.Rmd```ausführen

### Skripte

Handelt es sich um eine kompliziertere Analyse bzw. müssen verschiedene Skripte ausgeführt werden, sollten diese hier genauer beschrieben werden. Um die Reihenfolge kenntlich zu machen, kann es Sinn machen, den Dateinamen mit einer Zahl zu beginnen, z.B. `01-data-cleaning.R`, `02-data-analysis.R`, etc.

### Ordnerstruktur

Grundsätzlich gilt: Alle in einer Geschichte verwendeten Zahlen, sollten entweder im Markdown-File explizit berechnet und gekennzeichnet werden, oder im `output`-Ordner als Datensatz abgelegt werden. Infografiken können auch mit ```ggsave()``` als Bilddateien abgelegt werden, oder per ```dw_data_to_chart()``` direkt an Datawrapper geschickt werden.






