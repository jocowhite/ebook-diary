#!/usr/bin/env python3
"""Local journal prototype. Python 3 standard library only; no internet needed."""
import calendar
import datetime as dt
import json
import os
from pathlib import Path
import re
import tempfile
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlsplit, parse_qs, urlencode, urlunsplit
from urllib.request import Request, urlopen, build_opener, HTTPRedirectHandler

ROOT = Path(__file__).resolve().parent
DATA = Path(os.environ.get('JOURNAL_DATA_DIR', str(ROOT / 'data')))
API = os.environ.get('UMBREL_DASHBOARD_URL', '')
TOKEN = os.environ.get('UMBREL_DASHBOARD_TOKEN', '')
PORT = int(os.environ.get('JOURNAL_PORT', '8765'))


def atomic(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(dir=str(path.parent), prefix='.pending-')
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as f:
            f.write(value)
            f.flush()
            os.fsync(f.fileno())
        os.replace(name, str(path))
    finally:
        if os.path.exists(name):
            os.unlink(name)


def read_json(path, default):
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding='utf-8'))


def month_ok(month):
    if not re.fullmatch(r'\d{4}-\d{2}', month):
        raise ValueError('Ungültiger Monat')
    dt.date.fromisoformat(month + '-01')
    return month


def date_ok(date):
    if not isinstance(date, str) or not re.fullmatch(r'\d{4}-\d{2}-\d{2}', date):
        raise ValueError('Ungültiges Datum')
    dt.date.fromisoformat(date)
    return date


def validate_metrics(payload, month):
    if not isinstance(payload, dict) or payload.get('month') != month:
        raise ValueError('API: Monat stimmt nicht überein')
    days = payload.get('days')
    if not isinstance(days, list) or len(days) > 31:
        raise ValueError('API: days muss eine Liste mit höchstens 31 Tagen sein')
    out = {}
    for day in days:
        if not isinstance(day, dict):
            raise ValueError('API: ungültiger Tag')
        date = date_ok(day.get('date'))
        if not date.startswith(month + '-') or date in out:
            raise ValueError('API: falscher oder doppelter Tag')
        score = day.get('sleep_score')
        if score is not None and (type(score) is not int or not 0 <= score <= 100):
            raise ValueError('API: Sleep Score muss 0–100 oder null sein')
        sports = day.get('activities')
        if sports is not None:
            if not isinstance(sports, list) or len(sports) > 30:
                raise ValueError('API: ungültige Aktivitäten')
            for sport in sports:
                if not isinstance(sport, dict) or not isinstance(sport.get('type'), str) or len(sport['type']) > 60:
                    raise ValueError('API: ungültige Sportart')
                minutes = sport.get('duration_minutes')
                if type(minutes) not in (int, float) or not 0 <= minutes <= 10080:
                    raise ValueError('API: ungültige Dauer')
        out[date] = {'sleep_score': score, 'activities': sports}
    return out


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None  # Never forward the dashboard token to a redirect target.


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def reply(self, value, status=200, mime='application/json; charset=utf-8'):
        body = value.encode('utf-8') if isinstance(value, str) else json.dumps(value, ensure_ascii=False).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', mime)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.end_headers()
        self.wfile.write(body)

    def trusted(self):
        # Limit the local, unauthenticated service to its loopback origin.
        allowed = {'localhost:' + str(PORT), '127.0.0.1:' + str(PORT)}
        return self.headers.get('Host') in allowed and self.headers.get('Origin', 'http://' + self.headers.get('Host', '')) in {'http://' + h for h in allowed}

    def do_GET(self):
        if not self.trusted():
            return self.reply({'error': 'Ungültiger Ursprung'}, 403)
        try:
            url = urlsplit(self.path)
            if url.path == '/':
                return self.reply((ROOT / 'index.html').read_text(encoding='utf-8'), mime='text/html; charset=utf-8')
            if url.path == '/api/month':
                month = month_ok(parse_qs(url.query).get('month', [''])[0])
                entries = {}
                for f in (DATA / 'entries').glob(month + '-??.json'):
                    entries[f.stem] = read_json(f, {})
                metrics = read_json(DATA / 'metrics' / (month + '.json'), {'days': {}, 'synced_at': None})
                return self.reply({'entries': entries, 'metrics': metrics, 'sync_configured': bool(API)})
            if url.path == '/api/export':
                entries = [read_json(f, {}) for f in sorted((DATA / 'entries').glob('*.json'))]
                metrics = {f.stem: read_json(f, {}) for f in sorted((DATA / 'metrics').glob('*.json'))}
                return self.reply({'version': 1, 'entries': entries, 'metrics': metrics})
            self.reply({'error': 'Nicht gefunden'}, 404)
        except (ValueError, OSError) as e:
            self.reply({'error': str(e)}, 400)

    def do_POST(self):
        if not self.trusted():
            return self.reply({'error': 'Ungültiger Ursprung'}, 403)
        try:
            size = int(self.headers.get('Content-Length', '0'))
            if not 0 < size <= 100000:
                raise ValueError('Ungültige Datengröße')
            value = json.loads(self.rfile.read(size))
            if not isinstance(value, dict):
                raise ValueError('Ungültige Daten')
            if self.path == '/api/entry':
                date = date_ok(value.get('date'))
                text, habits = value.get('text'), value.get('habits')
                if not isinstance(text, str) or len(text) > 20000:
                    raise ValueError('Text zu lang')
                if not isinstance(habits, list) or len(habits) != 3 or any(type(v) is not bool for v in habits):
                    raise ValueError('Ungültige Tracker')
                entry = {'date': date, 'text': text, 'habits': habits}
                atomic(DATA / 'entries' / (date + '.json'), json.dumps(entry, ensure_ascii=False))
                return self.reply({'saved': True})
            if self.path == '/api/sync':
                month = month_ok(value.get('month', ''))
                if not API:
                    return self.reply({'error': 'Umbrel-Schnittstelle noch nicht konfiguriert'}, 503)
                url = urlsplit(API)
                if url.scheme not in ('http', 'https') or not url.hostname or url.username or url.fragment:
                    raise ValueError('Ungültige Umbrel-URL')
                query = parse_qs(url.query)
                query['month'] = [month]
                target = urlunsplit((url.scheme, url.netloc, url.path, urlencode(query, doseq=True), ''))
                headers = {'Accept': 'application/json'}
                if TOKEN:
                    headers['Authorization'] = 'Bearer ' + TOKEN
                with build_opener(NoRedirect()).open(Request(target, headers=headers), timeout=5) as response:
                    body = response.read(500001)
                if len(body) > 500000:
                    raise ValueError('API-Antwort zu groß')
                days = validate_metrics(json.loads(body), month)
                cached = read_json(DATA / 'metrics' / (month + '.json'), {'days': {}})
                # Response contains authoritative values for each included day;
                # omitted dates retain their previous cached measurements.
                cached['days'].update(days)
                cached['synced_at'] = dt.datetime.now(dt.timezone.utc).isoformat()
                atomic(DATA / 'metrics' / (month + '.json'), json.dumps(cached, ensure_ascii=False))
                return self.reply(cached)
            self.reply({'error': 'Nicht gefunden'}, 404)
        except (ValueError, OSError, TypeError) as e:
            self.reply({'error': str(e)}, 400)
        except Exception:
            self.reply({'error': 'Umbrel nicht erreichbar. Gespeicherte Werte bleiben erhalten.'}, 503)


if __name__ == '__main__':
    DATA.mkdir(parents=True, exist_ok=True)
    print('Tagebuch: http://127.0.0.1:%s — Beenden mit Ctrl+C' % PORT, flush=True)
    HTTPServer(('127.0.0.1', PORT), Handler).serve_forever()
