"""Development fixture with invented data, never Garmin data."""
import calendar
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlsplit


class Mock(BaseHTTPRequestHandler):
    def do_GET(self):
        month = parse_qs(urlsplit(self.path).query).get('month', ['2026-10'])[0]
        year, m = map(int, month.split('-'))
        days = []
        for d in range(1, calendar.monthrange(year, m)[1] + 1):
            days.append({'date': '%s-%02d' % (month, d), 'sleep_score': [0, 48, 68, 87, 95][d % 5], 'activities': [{'type': 'running', 'duration_minutes': 42}] if d % 3 == 0 else []})
        body = json.dumps({'month': month, 'days': days}).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == '__main__':
    print('DEMO-DATEN: http://127.0.0.1:8766', flush=True)
    HTTPServer(('127.0.0.1', 8766), Mock).serve_forever()
