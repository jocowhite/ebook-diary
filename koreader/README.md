# Tagebuch für KOReader – Tabellenfassung

Zielgerät laut Nutzer: Kindle 11. Generation (2024), Firmware 5.19.6, Véra; KOReader `20260702000` läuft. USB-Zugriff auf den Plugin-Ordner ist möglich. Die erste Listenfassung lief laut Nutzer; die neue Tabellenfassung ist noch nicht auf dem Kindle geprüft. Sie benötigt weder KUAL noch Python, WLAN oder einen Heimserver.

## Installation / Update über USB

1. KOReader beenden und den Kindle per USB anschließen.
2. Den vorhandenen Datenordner `koreader/ebook-diary/` sichern, falls vorhanden.
3. Das ZIP entpacken und den Ordner `ebookdiary.koplugin` nach `koreader/plugins/` kopieren. Beim Update den alten **Plugin-Ordner** durch den neuen ersetzen. Ergebnis: `koreader/plugins/ebookdiary.koplugin/main.lua`. Auch der enthaltene Ordner `icons/` muss mitkopiert werden.
4. Den Datenordner **nicht** ersetzen oder löschen. Kindle sicher auswerfen, KOReader neu starten und unter den weiteren Werkzeugen **Ein Tag. Eine Zeile.** öffnen.

## Ansicht und Bedienung

Die Oberfläche orientiert sich am ersten Browser-Entwurf: Datum und Tagebuchzeile links, Sport, Schlaf und schwarze Tracker-Kacheln rechts. **1–15** bzw. **16–Monatsende** zeigen eine Monatshälfte ohne Scrollen. **‹ / ›** wechseln den Monat, **Heute** öffnet die aktuelle Hälfte und **×** schließt die Ansicht.

- **Text:** Eine Tagebuchzeile antippen, schreiben und **Speichern** wählen. Es gibt kein Autosave; Abbrechen verwirft die Änderung. Mehrzeilige Texte sind möglich, die Tabelle zeigt nur die erste Zeile gekürzt an.
- **Tracker:** Eine Kachel antippen. Schwarz bedeutet aktiv, Weiß inaktiv; die Änderung wird sofort gespeichert.
- **Sleep Score:** Die Schlafkachel antippen und eine ganze Zahl von **0 bis 100** eingeben. **0 ist ein echter Wert.** Das Feld leeren und speichern entfernt den Wert; dann erscheint ein Strich. Je höher der Score, desto dunkler die Kachel.
- **Sport:** Die Sportkachel antippen. **Schwimmen, Radfahren, Laufen, Fußball und Padel** sind einzeln auswählbar, auch mehrere pro Tag. Änderungen werden sofort gespeichert; **Fertig** schließt die Auswahl. In der Tabelle erscheinen eigene SVG-Symbole statt Buchstaben oder Emoji. Ohne Auswahl erscheint ein Strich. Es werden Sportarten, keine Dauer oder Strecken erfasst.
- **Spalten:** Unten **Spalten** öffnen und eine Spalte auswählen. Dort lassen sich Namen ändern, Spalten nach links/rechts verschieben und aus-/einblenden. Über **+ Eigene Tracker-Spalte** entstehen weitere Schwarz-Weiß-Tracker. Text- und Datumsspalte bleiben fest. Es können **höchstens sechs Kachelspalten gleichzeitig** sichtbar sein; vor dem Hinzufügen einer weiteren eine andere ausblenden. Sport und Schlaf lassen sich ebenfalls ausblenden und später wieder einblenden.
- **Eigene Spalten entfernen:** Eigene Tracker lassen sich nach Bestätigung aus der Konfiguration entfernen. Historische Werte bleiben in den Monatsdateien, sind dann aber nicht mehr über diese Spalte erreichbar. Zum späteren Wiedereinblenden stattdessen **ausblenden** wählen. Eine erneut angelegte Spalte bekommt eine neue Identität.

Alle Messwerte im Plugin werden derzeit **manuell** erfasst. Noch kein Umbrel-Abgleich, kein Import/Export zum Browser-Prototyp und kein JSON-Exportknopf. Die Symbole sind schwarz-weiß und im Paket enthalten; es werden keine Schriften oder Bilder aus dem Netz geladen.

## Vorhandene Einträge und Sicherung

Dateien liegen unter `DataStorage:getDataDir()/ebook-diary/`, auf einem üblichen Kindle unter `koreader/ebook-diary/`:

- `YYYY-MM.json`: Einträge, Tracker, manuelle Sportarten und Sleep Scores.
- `columns.json`: Namen, Reihenfolge und Sichtbarkeit der Spalten.

Die drei bisherigen Tracker werden anhand ihrer bisherigen Position übernommen: Draußen, Lesen und Gut gegessen. Vorhandene Texte bleiben erhalten. Die Zuordnung eigener Spalten erfolgt über feste IDs, nicht über deren Namen; Umbenennen und Verschieben verändern keine Tageswerte. Das Update schreibt die Monatsdateien erst beim nächsten Speichern eines Eintrags im jeweiligen Monat neu. Die älteren Felder bleiben erhalten; für die neue Version ergänzte Felder können von einer alten Plugin-Version beim Speichern wieder verworfen werden. Daher vor einem Downgrade sichern.

Die Daten sind unverschlüsselt. Bei beendetem KOReader den **gesamten Datenordner** per USB sichern. Eine Sicherung wird bei beendetem KOReader durch Zurückkopieren dieses Ordners wiederhergestellt. Monatsdateien und Konfiguration werden über temporäre Dateien ersetzt. Stromausfall während des Schreibens ist nicht als sicher getestet.

## Gerätetest

1. Vorhandene Texte und die drei alten Tracker prüfen.
2. Einen Text mit Umlaut und Zeilenumbruch speichern; Tracker umschalten.
3. Sleep Score **0**, **100**, eine ungültige Zahl und anschließend ein leeres Feld testen.
4. Alle fünf Sportarten zusammen auswählen, danach einzelne wieder abwählen.
5. Eine eigene Spalte anlegen, aktivieren, umbenennen, verschieben und aus-/einblenden. Prüfen, ob ihr Tageswert erhalten bleibt.
6. KOReader beenden und neu starten; Einträge und Spalten prüfen. Beide Monatshälften sowie Betrieb ohne WLAN testen.

Die Ansicht richtet sich nach Displaygröße und Gerätezeit; das Hochformat ist der primäre Gerätetest. Tastatur, E-Ink-Aktualisierung, Suspend/Resume und die genaue KOReader-Version müssen am Gerät geprüft werden. Bei Fehlern den Wortlaut notieren. Wenn KOReader nicht mehr startet, den Plugin-Ordner per USB entfernen und relevante Meldungen aus `koreader/crash.log` prüfen; keine persönlichen Einträge teilen.

## Entwicklung und Paketbau

Im Repository-Hauptverzeichnis:

```sh
for file in koreader/ebookdiary.koplugin/*.lua; do texluac -p "$file" || exit; done
texlua tests/test_plugin_model.lua
texlua tests/test_plugin_storage.lua
texlua tests/test_plugin_ui.lua
python3 tools/package_plugin.py
```

Die Tests prüfen Altdatenübernahme, Eingabegrenzen, Sleep Score einschließlich 0 und Entfernen, mehrere Sportarten, feste Spalten-IDs, Persistenz, Schreibfehler und Dateischutz. UI-Tests verwenden KOReader-API-Doubles und führen die tatsächlichen Controller-, Zeichen- und Tap-Funktionen aus. Ein synthetisches Tabellenbild mit Beispieldaten wird unter `/tmp/ebook-diary-table-test.svg` erzeugt. Das ist **kein KOReader-Emulator**; echte Widgets, RapidJSON, Fonts, SVG-Rendering und Geräteeingaben werden dadurch nicht validiert. Die Dateitests verwenden einen Test-Codec.

Die verwendeten Schnittstellen wurden mit dem offiziellen KOReader-Quellcode (Commit `9b10e0121f9011531ff095b31a1e55c79909c196`) abgeglichen, nicht mit dem exakten Geräte-Build. Der Paketbau nimmt ausschließlich Plugin-Lua-Dateien, fünf SVG-Symbole und diese Anleitung auf; persönliche Daten gehören nicht ins ZIP.
