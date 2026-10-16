# Tagebuch für KOReader – Tabellenfassung mit Umbrel-Abgleich

Zielgerät laut Nutzer: Kindle 11. Generation (2024), Firmware 5.19.6, Véra; KOReader `20260702000` läuft. USB-Zugriff auf den Plugin-Ordner ist möglich. Die erste Tabellenfassung lief laut Nutzer; die aktuelle Layout-/Sync-Fassung benötigt einen erneuten Gerätetest. Sie benötigt weder KUAL noch Python, WLAN oder einen Heimserver.

## Installation / Update über USB

1. KOReader beenden und den Kindle per USB anschließen.
2. Den vorhandenen Datenordner `koreader/ebook-diary/` sichern, falls vorhanden.
3. Das ZIP entpacken und den Ordner `ebookdiary.koplugin` nach `koreader/plugins/` kopieren. Beim Update den alten **Plugin-Ordner** durch den neuen ersetzen. Ergebnis: `koreader/plugins/ebookdiary.koplugin/main.lua`. Auch der enthaltene Ordner `icons/` muss mitkopiert werden.
4. Den Datenordner **nicht** ersetzen oder löschen. Kindle sicher auswerfen, KOReader neu starten und unter den weiteren Werkzeugen **Ein Tag. Eine Zeile.** öffnen.

## Ansicht und Bedienung

Die Oberfläche orientiert sich am ersten Browser-Entwurf: Datum und Tagebuchzeile links, Sport, Schlaf und schwarze Tracker-Kacheln rechts. **1–15** bzw. **16–Monatsende** unten rechts zeigen eine Monatshälfte ohne Scrollen. Oben rechts neben **×** wechseln **‹ / ›** den Monat und **Heute** öffnet die aktuelle Hälfte. **×** schließt die Ansicht. Die Datumsspalte ist verbreitert, die Schrift in der Tagebuchzeile kleiner, die Kacheln sind quadratisch und ihre Titel um 90 Grad gedreht.

- **Text:** Eine Tagebuchzeile antippen, schreiben und **Speichern** wählen. Es gibt kein Autosave; Abbrechen verwirft die Änderung. Mehrzeilige Texte sind möglich, die Tabelle zeigt nur die erste Zeile gekürzt an.
- **Tracker:** Eine Kachel antippen. Schwarz bedeutet aktiv, Weiß inaktiv; die Änderung wird sofort gespeichert.
- **Sleep Score:** Die Schlafkachel antippen. Den Slider antippen/ziehen oder mit **− / +** in Einerschritten einstellen und **Speichern** wählen. **0 ist ein echter Wert.** **Keinen Wert eintragen** und Speichern erzeugt einen bewusst leeren Wert (Strich). **Umbrel-Wert verwenden** entfernt die manuelle Vorgabe. Je höher der Score, desto dunkler die Kachel.
- **Sport:** Die Sportkachel antippen. **Schwimmen, Radfahren, Laufen, Fußball und Padel** sind einzeln auswählbar, auch mehrere pro Tag. Änderungen werden sofort als manuelle Vorgabe gespeichert; **Fertig** schließt die Auswahl. **Umbrel-Sportwerte verwenden** entfernt die manuelle Vorgabe. In der Tabelle erscheinen eigene SVG-Symbole statt Buchstaben oder Emoji. Ohne Auswahl erscheint ein Strich. Es werden Sportarten, keine Dauer oder Strecken erfasst.
- **Spalten:** Unten **Spalten** öffnen und eine Spalte auswählen. Dort lassen sich Namen ändern, Spalten nach links/rechts verschieben und aus-/einblenden. Über **+ Eigene Tracker-Spalte** entstehen weitere Schwarz-Weiß-Tracker. Text- und Datumsspalte bleiben fest. Es können **höchstens sechs Kachelspalten gleichzeitig** sichtbar sein; vor dem Hinzufügen einer weiteren eine andere ausblenden. Sport und Schlaf lassen sich ebenfalls ausblenden und später wieder einblenden.
- **Eigene Spalten entfernen:** Eigene Tracker lassen sich nach Bestätigung aus der Konfiguration entfernen. Historische Werte bleiben in den Monatsdateien, sind dann aber nicht mehr über diese Spalte erreichbar. Zum späteren Wiedereinblenden stattdessen **ausblenden** wählen. Eine erneut angelegte Spalte bekommt eine neue Identität.

Schlaf und Sport können manuell erfasst oder lesend aus Umbrel übernommen werden. Noch kein Import/Export zum Browser-Prototyp und kein JSON-Exportknopf. Die Symbole sind schwarz-weiß und im Paket enthalten; es werden keine Schriften oder Bilder aus dem Netz geladen.

## Vorhandene Einträge und Sicherung

Dateien liegen unter `DataStorage:getDataDir()/ebook-diary/`, auf einem üblichen Kindle unter `koreader/ebook-diary/`:

- `YYYY-MM.json`: Einträge, Tracker, manuelle Sportarten und Sleep Scores.
- `columns.json`: Namen, Reihenfolge und Sichtbarkeit der Spalten sowie die Serveradresse.
- `metrics-YYYY-MM.json`: separat zwischengespeicherte Umbrel-Werte und Zeitstempel des letzten erfolgreichen Abgleichs (UTC).

Die drei bisherigen Tracker werden anhand ihrer bisherigen Position übernommen: Draußen, Lesen und Gut gegessen. Vorhandene Texte bleiben erhalten. Die Zuordnung eigener Spalten erfolgt über feste IDs, nicht über deren Namen; Umbenennen und Verschieben verändern keine Tageswerte. Das Update schreibt die Monatsdateien erst beim nächsten Speichern eines Eintrags im jeweiligen Monat neu. Die älteren Felder bleiben erhalten; für die neue Version ergänzte Felder können von einer alten Plugin-Version beim Speichern wieder verworfen werden. Daher vor einem Downgrade sichern.

Die Daten sind unverschlüsselt. Bei beendetem KOReader den **gesamten Datenordner** per USB sichern. Eine Sicherung wird bei beendetem KOReader durch Zurückkopieren dieses Ordners wiederhergestellt. Monatsdateien und Konfiguration werden über temporäre Dateien ersetzt. Stromausfall während des Schreibens ist nicht als sicher getestet.

## Gerätetest

1. Vorhandene Texte und die drei alten Tracker prüfen.
2. Einen Text mit Umlaut und Zeilenumbruch speichern; Tracker umschalten.
3. Sleep Score **0**, **100**, −/+-Schritte, Abbrechen und anschließend „Keinen Wert eintragen“ testen.
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
texlua tests/test_plugin_sync.lua
python3 tools/package_plugin.py
# Optional mit benachbartem my-umbrel-apps-Checkout:
python3 tools/check_sync_http.py
```

Die Tests prüfen Altdatenübernahme, Eingabegrenzen, Sleep Score einschließlich 0 und Entfernen, mehrere Sportarten, feste Spalten-IDs, Persistenz, Schreibfehler und Dateischutz. UI-Tests verwenden KOReader-API-Doubles und führen die tatsächlichen Controller-, Zeichen- und Tap-Funktionen aus. Ein synthetisches Tabellenbild mit Beispieldaten wird unter `/tmp/ebook-diary-table-test.svg` erzeugt. Das ist **kein KOReader-Emulator**; echte Widgets, RapidJSON, Fonts, SVG-Rendering und Geräteeingaben werden dadurch nicht validiert. Die Dateitests verwenden einen Test-Codec.

Die verwendeten Schnittstellen wurden mit dem offiziellen KOReader-Quellcode (Commit `9b10e0121f9011531ff095b31a1e55c79909c196`) abgeglichen, nicht mit dem exakten Geräte-Build. Der Paketbau nimmt ausschließlich Plugin-Lua-Dateien, fünf SVG-Symbole und diese Anleitung auf; persönliche Daten gehören nicht ins ZIP.

## Umbrel verbinden

Die Serveradresse ist mit **`http://192.168.178.98:8477`** vorbelegt. Port 8477 stammt aus dem bestehenden Dashboard-Manifest; die tatsächliche Erreichbarkeit von diesem Kindle aus ist noch nicht geprüft. Unter **Umbrel → Server** lässt sich die Adresse ändern. **Umbrel → Jetzt abgleichen** lädt den gerade geöffneten Monat. KOReader fragt bei Bedarf nach WLAN; der Abgleich benötigt nur eine Verbindung zum Heimnetz, keinen Internetzugriff. Es gibt vorerst keinen automatischen Hintergrundabgleich.

Voraussetzung ist die aktualisierte **Health Dashboard 0.3.1** aus `jocowhite/my-umbrel-apps` auf dem Umbrel-Server. Dort ist jetzt der nur lesende Endpunkt implementiert:

```text
GET http://192.168.178.98:8477/api/kindle/days?month=2026-10
```

Er muss JSON direkt liefern. Falls die Umbrel-App-Authentifizierung stattdessen eine Anmeldeseite oder Weiterleitung liefert, kann das Plugin damit noch nicht synchronisieren; diese Authentifizierung wurde mangels Zugriff auf das tatsächliche Gerät nicht geprüft. Sie wird vom Plugin nicht umgangen. Diese Fassung verwendet eine HTTP-Heimnetzadresse und unterstützt noch keinen HTTPS- oder Token-Login.

Es werden nur Schlaf- und Sportwerte heruntergeladen. Tagebuchtexte, eigene Tracker und manuelle Werte werden nicht hochgeladen. Bei HTTP-Fehlern, Offlinebetrieb oder ungültigen Antworten bleibt der letzte Cache erhalten. Nur vollständig gültige Antworten werden gespeichert; vom Backend ausgelassene Tage bleiben im Cache unverändert. Ein gelieferter Tag ersetzt die beiden heruntergeladenen Messfelder; null bedeutet fehlende Daten.

**Manuelle Werte haben Vorrang**, auch ein bewusst gelöschter Sleep Score oder eine bewusst leere Sportauswahl. In der Schlafansicht **Umbrel-Wert verwenden** bzw. in der Sportauswahl **Umbrel-Sportwerte verwenden** wählen, um diese Vorgabe zurückzusetzen. Ein alter gespeicherter Sleep Score und eine alte nicht leere Sportauswahl werden als manuelle Werte behandelt. Text- oder Trackeränderungen schreiben keine synchronisierten Werte in die manuellen Felder.

### Bisher verifiziert

Lua-Syntax, Modell-/Datei-/Controller-Tests mit API-Doubles, Sync-Validierung und Fehlerbehandlung bestehen. Zusätzlich hat der tatsächliche LuaSocket-Client über einen lokalen HTTP-Server den echten Dashboard-Endpunkt abgefragt und dessen Beispieldaten validiert; die Testumgebung verwendete dabei einen Python-JSON-Testadapter statt KOReaders RapidJSON. Der Dashboard-Endpunkt besteht drei Tests auch im offiziellen Python-3.13-Alpine-Container. Reale InfluxDB-Daten, die installierte Umbrel-Version, Netzwerk/Authentifizierung im Heimnetz, KOReaders RapidJSON und die neuen Gerätegesten sind noch nicht live geprüft.
