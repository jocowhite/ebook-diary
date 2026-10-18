# Tagebuch für KOReader – Tabellenfassung mit Umbrel-Abgleich

Zielgerät laut Nutzer: Kindle 11. Generation (2024), Firmware 5.19.6, Véra; KOReader `20260702000` läuft. USB-Zugriff auf den Plugin-Ordner ist möglich. Die erste Tabellenfassung lief laut Nutzer; die aktuelle Layout-/Sync-Fassung benötigt einen erneuten Gerätetest. Die lokale Nutzung benötigt weder KUAL noch Python, WLAN oder einen Heimserver. Für den Abgleich ist WLAN zum Umbrel erforderlich.

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
- `columns.json`: Namen, Reihenfolge und Sichtbarkeit der Spalten, Serveradresse und Verbindungsschlüssel.
- `conflicts-YYYY-MM.json`: die Umbrel-Fassungen offener Konflikte; die Kindle-Fassung bleibt in der Monatsdatei.
- `journal-status-YYYY-MM.json`: letzter erfolgreicher Tagebuch-Kontakt (UTC).
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
texlua tests/test_plugin_journal.lua
python3 tools/package_plugin.py
# Optional mit benachbartem my-umbrel-apps-Checkout:
python3 tools/check_sync_http.py
```

Die Tests prüfen Altdatenübernahme, Eingabegrenzen, Sleep Score einschließlich 0 und Entfernen, mehrere Sportarten, feste Spalten-IDs, Persistenz, Schreibfehler und Dateischutz. UI-Tests verwenden KOReader-API-Doubles und führen die tatsächlichen Controller-, Zeichen- und Tap-Funktionen aus. Ein synthetisches Tabellenbild mit Beispieldaten wird unter `/tmp/ebook-diary-table-test.svg` erzeugt. Das ist **kein KOReader-Emulator**; echte Widgets, RapidJSON, Fonts, SVG-Rendering und Geräteeingaben werden dadurch nicht validiert. Die Dateitests verwenden einen Test-Codec.

Die verwendeten Schnittstellen wurden mit dem offiziellen KOReader-Quellcode (Commit `9b10e0121f9011531ff095b31a1e55c79909c196`) abgeglichen, nicht mit dem exakten Geräte-Build. Der Paketbau nimmt ausschließlich Plugin-Lua-Dateien, fünf SVG-Symbole und diese Anleitung auf; persönliche Daten gehören nicht ins ZIP.

## Umbrel verbinden und HTTP 302 beheben

Die aktuelle Fassung benötigt **Health Dashboard 0.4.0** aus `jocowhite/my-umbrel-apps`. HTTP 302 kommt bei der bisherigen Einrichtung von der Umbrel-Anmeldung: Der Browser hat eine Sitzung, der Kindle nicht. Die neue App-Ausgabe nimmt exakt `/api/kindle/days` und `/api/kindle/journal` von der Cookie-Anmeldung aus und prüft dort stattdessen einen Verbindungsschlüssel. Dashboard, Editor und Verbindungsseite bleiben hinter der normalen Umbrel-Anmeldung. Eine Weiterleitung wird vom Plugin weiterhin nicht verfolgt.

1. Dashboard-App auf Umbrel auf **0.4.0** aktualisieren. Nur den Kindle zu aktualisieren behebt die Weiterleitung nicht.
2. Im angemeldeten Browser `http://192.168.178.98:8477/kindle-setup` öffnen (oder **Kindle verbinden** im Dashboard).
3. Den dort erzeugten Schlüssel auf dem Kindle unter **Umbrel → Verbindungsschlüssel** eintragen. Nicht das Umbrel-Passwort verwenden und den Schlüssel nicht im Chat teilen.
4. Unter **Umbrel → Server** steht `http://192.168.178.98:8477`; die Adresse bleibt änderbar.
5. **Umbrel → Jetzt abgleichen** wählen.

Der Schlüssel erlaubt das Lesen der Messwerte und das Lesen/Bearbeiten des Tagebuchs. Er bleibt auf beiden Geräten gespeichert; auf dem Kindle in `columns.json`, auf Umbrel in der privaten Datei `data/kindle-api-token`. Diese Version verwendet HTTP im eigenen Heimnetz, keine öffentliche Internetfreigabe und keinen HTTPS-Login. Die Dateien sind nicht verschlüsselt.

## Einträge in beide Richtungen synchronisieren

Der manuelle Abgleich betrifft den **gerade geöffneten Monat**:

- Neue und geänderte Kindle-Einträge werden auf Umbrel gespeichert.
- Im Dashboard gespeicherte Änderungen werden auf den Kindle geladen.
- Synchronisiert werden Text, Tracker-Werte und manuelle Schlaf-/Sportwerte. Namen eigener Tracker werden mit übertragen, damit sie im Dashboard lesbar sind. Anordnung und Sichtbarkeit der Spalten werden weiterhin auf dem Kindle eingestellt.
- Der Abgleich läuft zuerst für das Tagebuch, danach separat für Garmin-Messwerte. Ist InfluxDB ausgefallen, kann das Tagebuch trotzdem erfolgreich abgeglichen werden; das Plugin meldet den getrennten Messwertfehler.
- Es gibt keinen automatischen Hintergrundabgleich. Offline-Änderungen bleiben lokal. Für ältere Monate den jeweiligen Monat öffnen und abgleichen.

Vorhandene Kindle-Einträge werden beim ersten Abgleich als noch nicht synchronisierte Einträge hochgeladen. Lokale Dateien bleiben erhalten. Ein HTTP-Fehler oder eine ungültige Antwort markiert lokale Änderungen nicht als synchronisiert. Eine verlorene Antwort nach erfolgreichem Upload lässt sich durch erneuten Abgleich auffangen, ohne doppelte Einträge zu erzeugen.

### Im Dashboard bearbeiten

Nach dem App-Update `http://192.168.178.98:8477/journal` öffnen oder **Tagebuch** im Dashboard wählen. Nach der normalen Umbrel-Anmeldung lassen sich Monat und Tag auswählen, Text/Tracker ändern und manuelle Schlaf-/Sportwerte bearbeiten. **Speichern** schreibt auf Umbrel; der Kindle übernimmt das beim nächsten Abgleich des Monats. Der Browser hat kein Autosave.

### Konflikte

Wenn derselbe Tag seit dem letzten gemeinsamen Stand auf beiden Geräten verändert wurde, wird er nicht automatisch überschrieben. Andere konfliktfreie Tage werden trotzdem synchronisiert.

Im Kindle unter **Umbrel → Konflikte** beide Fassungen ansehen und ausdrücklich die Umbrel-Fassung übernehmen oder die Kindle-Fassung für den nächsten Abgleich vormerken. Eine inzwischen erneut geänderte Umbrel-Fassung erzeugt wieder einen Konflikt. Im Browser bleibt bei einem Konflikt der Entwurf im Editor stehen; die aktuelle Umbrel-Fassung wird angezeigt und kann geladen oder nach Vergleich bewusst ersetzt werden.

Dies ist eine Synchronisierung aktueller Fassungen mit Konfliktschutz, keine unbegrenzte Versionshistorie. Vorhandene Daten vor dem ersten Abgleich sichern.

### Speicherort und Sicherung auf Umbrel

Unter dem verwalteten App-Verzeichnis `${APP_DATA_DIR}/data` liegen:

- `journal.sqlite3`: serverseitige Tagebucheinträge mit Revisionen und Tracker-Bezeichnungen.
- `kindle-api-token`: Verbindungsschlüssel.

Die Daten bleiben im persistenten Bind-Mount über Container-Neustarts und reguläre App-Updates erhalten. Für eine Dateisicherung Dashboard-App stoppen und den gesamten `data`-Ordner kopieren; die Sicherung separat aufbewahren. Auch den Kindle-Datenordner weiter sichern. Synchronisierung allein ist kein Schutz gegen den Verlust beider Geräte.

### Garmin-Messwerte

Schlaf und Sport werden weiterhin getrennt über `GET /api/kindle/days?month=YYYY-MM` geladen und im lokalen Messwert-Cache gehalten. Manuelle Vorgaben haben Vorrang, auch ein bewusst gelöschter Sleep Score oder eine bewusst leere Sportauswahl. **Umbrel-Wert verwenden** bzw. **Umbrel-Sportwerte verwenden** entfernt die manuelle Vorgabe. Die Tagebuch-Bearbeitung ändert keine Garmin-/InfluxDB-Quelldaten.

### Verifiziert und noch offen

Lua-Modell-, Datei-, Controller-, Sync- und Konflikttests bestehen. Der tatsächliche LuaSocket-Client hat lokal Einträge authentifiziert zum echten Dashboard-Endpunkt hochgeladen, aus SQLite wieder gelesen, Dashboard-Änderungen heruntergeladen und parallele Änderungen als Konflikt behalten. Im Cloud-Test ersetzt ein Python-JSON-Adapter KOReaders RapidJSON. Acht Backend-Tests sowie Browserprüfungen für Bearbeitung, Speicherung, Konflikte und Netzwerkfehler bestehen; der Dockerfile-Build wurde als UID 1000 mit persistentem Schreibzugriff geprüft. Die verwendeten Proxy-Ausnahmen wurden anhand des offiziellen Umbrel-Gateway-Codes geprüft.

Die aktualisierte App muss noch auf dem tatsächlichen Umbrel installiert werden. Das Heimnetz, die installierte Umbrel-Version, KOReaders RapidJSON und der echte Kindle-Lauf sind von hier nicht getestet. Bei weiterem HTTP 302 bitte die auf Umbrel tatsächlich installierte Version prüfen; HTTP 401 bedeutet fehlenden/falschen Verbindungsschlüssel. Den Schlüssel nicht in Fehlerberichte übernehmen.
