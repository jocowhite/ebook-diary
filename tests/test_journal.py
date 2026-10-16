import importlib.util
import json
from pathlib import Path
import tempfile
import threading
import unittest
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.request import Request, urlopen
from urllib.error import HTTPError

spec = importlib.util.spec_from_file_location('journal', Path(__file__).resolve().parents[1] / 'server.py')
journal = importlib.util.module_from_spec(spec)
spec.loader.exec_module(journal)


class Fixture(BaseHTTPRequestHandler):
    payload = {'month': '2026-10', 'days': [{'date': '2026-10-16', 'sleep_score': 0, 'activities': []}]}

    def log_message(self, *_):
        pass

    def do_GET(self):
        body = json.dumps(self.payload).encode()
        self.send_response(200)
        self.end_headers()
        self.wfile.write(body)


class JournalTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        journal.DATA = Path(self.temp.name)
        self.server = HTTPServer(('127.0.0.1', 0), journal.Handler)
        journal.PORT = self.server.server_port
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.fixture = HTTPServer(('127.0.0.1', 0), Fixture)
        Fixture.payload = {'month': '2026-10', 'days': [{'date': '2026-10-16', 'sleep_score': 0, 'activities': []}]}
        self.worker = threading.Thread(target=self.fixture.serve_forever, daemon=True)
        self.worker.start()
        journal.API = 'http://127.0.0.1:%s/api/kindle/days' % self.fixture.server_port

    def tearDown(self):
        self.server.shutdown()
        self.fixture.shutdown()
        self.server.server_close()
        self.fixture.server_close()
        self.thread.join()
        self.worker.join()
        self.temp.cleanup()

    def call(self, path, payload=None, origin=None):
        headers = {'Content-Type': 'application/json'}
        if origin:
            headers['Origin'] = origin
        req = Request('http://127.0.0.1:%s%s' % (journal.PORT, path), data=None if payload is None else json.dumps(payload).encode(), headers=headers)
        try:
            with urlopen(req, timeout=10) as response:
                return response.status, json.load(response)
        except HTTPError as e:
            return e.code, json.load(e)

    def test_persistence_export_and_restart(self):
        entry = {'date': '2026-10-16', 'text': 'Schöner Tag ♥\nZweite Zeile', 'habits': [True, False, True]}
        self.assertEqual(self.call('/api/entry', entry)[0], 200)
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.server = HTTPServer(('127.0.0.1', journal.PORT), journal.Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.assertEqual(self.call('/api/month?month=2026-10')[1]['entries']['2026-10-16'], entry)
        self.assertEqual(self.call('/api/export')[1]['entries'], [entry])

    def test_sync_zero_offline_and_invalid_cache_preservation(self):
        code, value = self.call('/api/sync', {'month': '2026-10'})
        self.assertEqual(code, 200)
        self.assertEqual(value['days']['2026-10-16']['sleep_score'], 0)
        Fixture.payload['days'][0]['sleep_score'] = 101
        self.assertEqual(self.call('/api/sync', {'month': '2026-10'})[0], 400)
        self.assertEqual(self.call('/api/month?month=2026-10')[1]['metrics'], value)
        self.fixture.shutdown()
        self.fixture.server_close()
        self.worker.join()
        self.assertNotEqual(self.call('/api/sync', {'month': '2026-10'})[0], 200)
        self.assertEqual(self.call('/api/month?month=2026-10')[1]['metrics'], value)

    def test_reject_bad_date_and_origin(self):
        entry = {'date': '../../oops', 'text': 'test', 'habits': [False]*3}
        self.assertEqual(self.call('/api/entry', entry)[0], 400)
        entry['date'] = '2026-10-16'
        self.assertEqual(self.call('/api/entry', entry, 'https://example.org')[0], 403)
        self.assertEqual(self.call('/api/month?month=2026-10')[1]['entries'], {})


if __name__ == '__main__':
    unittest.main()
