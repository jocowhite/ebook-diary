# Tagebuch für KOReader – erster Gerätetest

Zielgerät laut Nutzer: Kindle 11. Generation (2024), Firmware 5.19.6, Véra; KOReader `20260702000` läuft. USB-Zugriff auf den Plugin-Ordner ist möglich.

Dies ist ein experimentelles KOReader-Plugin, noch kein auf diesem Kindle geprüftes Release. KUAL, Python, WLAN und ein laufender Heimserver werden dafür nicht benötigt. Es stellt eine native Monatsliste bereit, keine identische Kopie des tabellarischen Browser-Layouts.

## Installation über USB

1. KOReader beenden und den Kindle per USB anschließen.
2. Das ZIP entpacken. Den gesamten Ordner `ebookdiary.koplugin` in den bereits vorhandenen Ordner `koreader/plugins/` kopieren. Ergebnis: `koreader/plugins/ebookdiary.koplugin/main.lua`. Keine doppelte Ordner-Verschachtelung erzeugen.
3. Kindle sicher auswerfen und KOReader neu starten.
4. Im Hauptmenü unter den weiteren Werkzeugen nach **Ein Tag. Eine Zeile.** suchen. Falls nötig im Plugin-Manager aktivieren und KOReader nochmals starten.

Beim Aktualisieren nur den Plugin-Ordner ersetzen, den Datenordner erhalten.

## Bedienung und erster Test

- Monat wählen und einen Tag antippen.
- **Text schreiben / bearbeiten** öffnet den Editor mit Tastatur. **Speichern** schreibt den Eintrag; erst bei **Lokal gespeichert** ist die Speicherung bestätigt. Es gibt hier kein Autosave. **Abbrechen** verwirft den bearbeiteten Text.
- Die drei Tracker lassen sich in der Tagesansicht einzeln umschalten; jede Änderung wird sofort gespeichert.
- Einen kurzen Testeintrag mit Umlaut und Zeilenumbruch schreiben, Tracker umschalten, KOReader beenden und neu starten. Prüfen, ob Text und Tracker erhalten bleiben.
- Vorigen/nächsten Monat sowie den Betrieb ohne WLAN prüfen.

Das Gerätedatum und die Gerätezeitzone bestimmen den anfänglich geöffneten Monat. Bei Fehlern den Wortlaut notieren. Wenn das Plugin nicht erscheint oder KOReader abstürzt, den Plugin-Ordner per USB wieder entfernen und die relevanten Fehlermeldungen aus `koreader/crash.log` prüfen; keine persönlichen Tagebucheinträge teilen.

## Daten und Sicherung

Das Plugin speichert unter `DataStorage:getDataDir()/ebook-diary/YYYY-MM.json`, auf einem üblichen Kindle-KOReader unter `koreader/ebook-diary/`. Der Pfad liegt außerhalb des Plugin-Ordners. Vor Neuinstallation oder größeren Änderungen KOReader beenden und diesen gesamten Datenordner per USB sichern.

Die Daten sind unverschlüsselt. Eine Sicherung lässt sich bei beendetem KOReader durch Zurückkopieren des Datenordners wiederherstellen. Browser-Prototyp und Plugin haben derzeit getrennte Datenbestände. Es gibt noch keinen Datenimport, JSON-Exportknopf, Sport-/Schlafdaten oder Umbrel-Abgleich im Plugin. Eine Monatsdatei wird über eine temporäre Datei ersetzt; ein abruptes Ausschalten während eines Schreibvorgangs ist nicht als sicher getestet.

## Entwicklungsprüfung

Im Repository-Hauptverzeichnis:

```sh
texluac -p koreader/ebookdiary.koplugin/main.lua
texluac -p koreader/ebookdiary.koplugin/storage.lua
texlua tests/test_plugin_storage.lua
```

Die Dateispeichertests prüfen Persistenz, mehrere Einträge, Tracker, Eingabegrenzen, Schutz beschädigter Dateien und Schreibfehler. Sie verwenden einen eingesetzten Test-Codec; KOReaders `rapidjson` und die echte Geräteoberfläche sind damit nicht getestet. Die verwendeten Menü-, Editor- und Datenpfad-Schnittstellen wurden mit dem offiziellen KOReader-Quellcode (Commit `9b10e0121f9011531ff095b31a1e55c79909c196`) abgeglichen, nicht mit dem exakten Geräte-Build. Insbesondere Tastatur, Bildschirmgröße, Suspend/Resume und Neustart müssen auf dem Kindle geprüft werden.
