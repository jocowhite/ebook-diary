# Ein Tag. Eine Zeile.

Lokaler Tagebuch-Prototyp für Joel, nach dem fotografierten Notizbuch.

## Status

Es gibt zwei lokale Oberflächen: den ursprünglichen Browser-Prototyp (`index.html` + `server.py`) und ein natives KOReader-Plugin. Das Plugin zeigt eine tabellarische Monatshälfte mit schwarzen Tracker-Kacheln, manuellen Sleep Scores, Sport-Symbolen und konfigurierbaren Spalten. Der erste Plugin-Entwurf lief laut Nutzer; die neue Tabellenfassung ist noch nicht am Kindle geprüft. Installation und Update: [koreader/README.md](koreader/README.md).

Der Browser-Prototyp wurde mit Integrationstests und Chromium geprüft. Sein optionaler Umbrel-Abgleich ist vom Plugin getrennt. Das Plugin benötigt weder Python noch KUAL.

Die echte Umbrel-Dashboard-App wurde nicht eingesehen oder verändert. Ihr API-Endpunkt muss dort noch ergänzt oder an den unten beschriebenen Vertrag angepasst werden.

## Sofort ansehen

`index.html` auf dem Mac im Browser öffnen: vollständig lokale **Vorschau mit ausdrücklich gekennzeichneten Beispieldaten**. Keine externen Schriften, Bibliotheken oder Netzwerkaufrufe. Vorschauänderungen landen im Browser-Speicher; diese Daten sind unabhängig vom eigentlichen Tagebuch. Ist der Browser-Speicher gesperrt, wird ein Speicherfehler angezeigt.

## Echter lokaler Betrieb auf dem Mac

Python 3 muss installiert sein. Im entpackten Ordner:

```bash
python3 server.py
```

Dann `http://127.0.0.1:8765` öffnen. Dafür ist kein Internet und kein Heimserver nötig. Der Dienst muss auf demselben Gerät wie der Browser laufen. In dieser Ansicht sind zunächst keine Einträge und keine erfundenen Messwerte vorhanden.

- Eine Zeile antippen, schreiben, nach 700 ms Schreibpause wird gespeichert.
- „Lokal gespeichert“ abwarten, bevor Browser oder Dienst geschlossen werden.
- Die drei manuellen Tracker sind zunächst Draußen, Lesen und Gut gegessen. Das sind anpassbare Vorschläge, keine bestätigte Übernahme aller Spalten aus dem Foto.
- 15 bzw. 16 Tage pro Seite für kleine Displays. Monat und Halbmonat können gewechselt werden.
- Sleep Score: 0–100, zunehmende Dunkelheit, kontrastierende Zahl. Fehlende Daten: „—“. Keine Aktivität: „·“. Fehlende Aktivitätsdaten: „—“.
- Sportkachel: Laufen, Radfahren, Schwimmen, Gehen oder Krafttraining. Antippen zeigt die erfassten Aktivitäten und deren Dauer.
- „Sicherung“ exportiert Einträge und Messwerte als JSON. Zusätzlich kann der gesamte `data`-Ordner kopiert werden. Ein Import-Knopf ist noch nicht implementiert; eine Dateisicherung wird bei gestopptem Dienst durch Zurückkopieren des `data`-Ordners wiederhergestellt.

### Speicherung

`data/entries/YYYY-MM-DD.json`: Tagebuchtext und manuelle Tracker, eine Datei pro Tag.

`data/metrics/YYYY-MM.json`: zwischengespeicherte Sport-/Schlafwerte und letzter erfolgreicher Abgleich.

Dateien werden mit temporärer Datei und atomarem Ersetzen geschrieben. Der Dienst bindet ausschließlich an 127.0.0.1. Keine Tagebuchtexte werden an Umbrel geschickt. Die lokalen Dateien sind nicht verschlüsselt.

## Umbrel-API (Vorschlag v1)

Auf der Dashboard-App einen nur lesenden Endpunkt anlegen, z. B.:

`GET /api/kindle/days?month=2026-10`

```json
{
  "month": "2026-10",
  "days": [
    {
      "date": "2026-10-16",
      "sleep_score": 87,
      "activities": [
        {"type": "running", "duration_minutes": 42}
      ]
    },
    {
      "date": "2026-10-15",
      "sleep_score": null,
      "activities": []
    }
  ]
}
```

- Datum: Kalendertag in **Europe/Berlin**, nicht durch simples Abschneiden eines UTC-Zeitstempels ableiten. Schlaf wird dem lokalen Aufwachtag zugeordnet. Die Dashboard-App erledigt diese Zuordnung und fasst Aktivitäten pro lokalem Tag zusammen.
- Sleep Score: ganze Zahl 0–100 oder `null`, wenn nicht vorhanden. Keine Umrechnung aus Schlafdauer.
- Aktivitäten: `running`, `cycling`, `swimming`, `walking`, `strength`; andere Bezeichnungen werden als Text angezeigt. Eine Liste mit allen Aktivitäten des Tages; `[]` bedeutet keine Aktivität, `null` unbekannt.
- Jeder mitgelieferte Tag ersetzt seine beiden Messfelder vollständig; ausgelassene Tage bleiben im lokalen Cache unverändert. Liefert das Dashboard korrigierte Daten, werden diese beim nächsten Abgleich übernommen.
- Bei Fehlern, ungültiger Antwort oder nicht erreichbarem Umbrel bleibt der bisherige Cache erhalten. Ungültige Monatsantworten werden vollständig verworfen.
- Optional `Authorization: Bearer …` mit ausschließlich lesendem Token. Keine Garmin-Zugangsdaten auf den Kindle übertragen.

Dienst für den Abgleich starten (Beispieladresse durch die echte lokale Adresse ersetzen):

```bash
UMBREL_DASHBOARD_URL='http://DEIN-UMBREL:PORT/api/kindle/days' python3 server.py
```

Token bei Bedarf als Umgebungsvariable `UMBREL_DASHBOARD_TOKEN` setzen. Der Token liegt nicht in der Browser-Oberfläche. HTTP eignet sich nur für das vertraute Heimnetz; HTTPS wird ebenfalls unterstützt. Zugriff auf Umbrel erfolgt vom lokalen Python-Dienst, daher keine CORS-Freischaltung auf der Dashboard-App nötig.

Automatischer Abgleich: beim Laden eines Monats, beim Zurückkehren zur offenen App und alle zehn Minuten, solange die App sichtbar ist. Timeout nach fünf Sekunden beim Dashboard-Abruf. Kein WLAN-Scan, kein automatisches Einschalten von WLAN, kein Hintergrunddienst im Standby. Nach einer längeren Reise müssen ältere Monate geöffnet werden, um sie nachzuladen. Alle Einträge funktionieren weiterhin ohne Umbrel.

## Test-API

Nur für die Entwicklung, mit erfundenen Daten:

```bash
python3 mock_dashboard.py
```

In einem zweiten Terminal:

```bash
UMBREL_DASHBOARD_URL='http://127.0.0.1:8766/api/kindle/days' python3 server.py
```

## Prüfungen

```bash
python3 -m unittest discover -s tests -v
```

Integrationstests: Speicherung nach Dienstneustart, Export, gültiger API-Abgleich einschließlich Score 0, ungültige Daten, Cache-Erhalt bei Offline-Verbindung, Zurückweisen fremder Browser-Ursprünge. Chromium-Funktionstest: Eintrag schreiben, Autosave abwarten, Seite neu laden und den gespeicherten Text im JSON-Export prüfen. Dabei traten keine JavaScript-Laufzeitfehler auf. Screenshots bei 1024 und 600 Pixeln Breite wurden erzeugt; die 600-Pixel-Ansicht wurde visuell geprüft. Bildschirmtastatur, E-Ink-Verhalten und Betrieb auf einem echten Kindle sind weiterhin ungetestet.

## Kindle-Zielgerät

Vom Nutzer gemeldeter Stand:

- Kindle 11. Generation, Modelljahr 2024
- Firmware: 5.19.6
- Jailbreak: [Véra](https://kindlemodding.org/jailbreaking/Vera)
- KOReader: läuft laut Nutzer
- KOReader-Version laut Nutzer: `20260702000`
- Zugriff auf `koreader/plugins` per USB: möglich
- KUAL: läuft laut Nutzer noch nicht; Installationsstatus ungeklärt

Die erste Listenfassung des Plugins lief laut Nutzer auf dem Gerät. Die neue Layout-/Sync-Fassung benötigt einen erneuten Gerätetest.

## Für die Kindle-Version noch zu klären

1. Das experimentelle KOReader-Plugin nach der Anleitung in `koreader/README.md` auf dem Gerät testen.
2. Tabellenlayout, Tastatur und Speicherung auf dem Gerät prüfen. Python ist für das Plugin nicht nötig.
3. Der Quellcode der bestehenden Dashboard-App liegt im benachbarten Repository `my-umbrel-apps/my-store-triathlon-hq`; der vorgeschlagene Tagesdaten-Endpunkt muss dort noch geprüft bzw. umgesetzt werden.
4. Eigene Tracker lassen sich jetzt direkt im Plugin über „Spalten“ konfigurieren.

Danach: geeigneter Startmechanismus, Einrichtung auf dem Kindle und Tests mit Flugmodus, Tastatur, Standby und Neustart. Dieses Paket führt keine Systemänderungen am Kindle durch und enthält kein geratenes Launcher-Script.

## Projektstruktur

- `index.html`: Oberfläche und separate lokale Dateivorschau
- `server.py`: lokaler HTTP-Dienst, Speicherung, Export und optionaler Umbrel-Abgleich
- `mock_dashboard.py`: lokale Demo-API mit erfundenen Messwerten
- `tests/test_journal.py`: Integrationstests ohne externe Dienste

Python 3.12 ist in der Entwicklungsumgebung geprüft. Es sind keine zusätzlichen Python-Pakete nötig. Private Laufzeitdaten unter `data/`, lokale `.env`-Dateien und Python-Caches werden von Git ausgeschlossen. Um Daten außerhalb des Repositories abzulegen:

```bash
JOURNAL_DATA_DIR=/pfad/zu/privaten-tagebuchdaten python3 server.py
```

Mit `JOURNAL_PORT` lässt sich der Standardport 8765 überschreiben. Umgebungsvariablen müssen beim Start gesetzt werden; `.env`-Dateien werden nicht automatisch geladen.

## Nächste Entwicklungsschritte

1. Die neue Tabellenfassung auf dem Kindle prüfen, insbesondere bestehende Einträge, Kacheln und manuelle Sport-/Schlafwerte.
2. Den lesenden Tagesdaten-Endpunkt mit der bestehenden Umbrel-Dashboard-App abstimmen.
3. Die Bedienung anhand des Gerätetests verfeinern.

## Experimentelles KOReader-Plugin

Unter `koreader/ebookdiary.koplugin` liegt die native Lua-Version mit tabellarischer Monatshälfte, Texteditor, schwarzen Tracker-Kacheln, manuellem Sleep Score (0–100) und Symbolen für Schwimmen, Radfahren, Laufen, Fußball und Padel. Spalten lassen sich hinzufügen (als Tracker), umbenennen, verschieben und aus-/einblenden; bis zu sechs Kachelspalten sind gleichzeitig sichtbar. Bisherige Texte und Tracker werden übernommen.

USB-Installation, Datensicherung und Gerätetest: [koreader/README.md](koreader/README.md). Das fertige Paket liegt unter [`dist/ebook-diary-koreader-prototype.zip`](dist/ebook-diary-koreader-prototype.zip) und lässt sich mit `python3 tools/package_plugin.py` neu erzeugen. Diese Version benötigt weder Python auf dem Kindle noch KUAL. Browser-Prototyp und Plugin verwenden getrennte Datenbestände; ein gemeinsamer Import/Export ist noch nicht implementiert. Das Plugin kann den aktuellen Monat lesend vom aktualisierten Dashboard laden; die IP-Adresse ist mit `192.168.178.98:8477` vorbelegt. Manuelle Werte bleiben vorrangig.

## Neue Designvorschau zur Abstimmung

[HTML-Vorschau](docs/design-preview.html) · [Tabellenbild](docs/design-preview.png) · [Sleep-Score-Slider](docs/design-preview-slider.png)

Die Vorschau zeigt die vorgeschlagene nächste Anordnung: Navigation oben rechts, Halbmonatswechsel unten rechts, breitere Datumsspalte, kleinere Tagebuchschrift, quadratische Kacheln und senkrechte Spaltentitel. Der Sleep Score ist über einen Slider mit ±1-Tasten und optionalem Löschen bedienbar. Es sind ausschließlich erfundene Daten; Änderungen gelten nur bis zum Neuladen. Der bestätigte Entwurf ist jetzt ins KOReader-Plugin übertragen, einschließlich Schlaf-Slider. Die HTML-Datei bleibt eine Vorschau mit Beispieldaten; der echte Umbrel-Abgleich steckt im Plugin. [Details und Browserprüfung](docs/design-preview.md).
