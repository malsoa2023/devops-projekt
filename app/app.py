"""Aplikacja demonstracyjna projektu DevOps.

Prosty serwis HTTP (Flask), który:
- pokazuje wersję (SHA commita) i nazwę repliki, która obsłużyła żądanie,
- wystawia metryki Prometheusa pod /metrics,
- ma endpointy pomocnicze do demonstracji monitoringu i alertów.
"""

import logging
import os
import socket
import threading
import time

from flask import Flask, Response, g, jsonify, render_template_string, request
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Gauge, Histogram, generate_latest

APP_VERSION = os.getenv("APP_VERSION", "dev")
HOSTNAME = socket.gethostname()

REQUESTS = Counter(
    "http_requests_total", "Liczba obsłużonych żądań HTTP", ["method", "endpoint", "status"]
)
LATENCY = Histogram(
    "http_request_duration_seconds",
    "Czas obsługi żądania HTTP",
    ["endpoint"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10),
)
APP_INFO = Gauge("app_info", "Wersja aplikacji i nazwa repliki", ["version", "hostname"])

INDEX_HTML = """<!doctype html>
<html lang="pl">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Projekt DevOps</title>
  <style>
    body { font-family: system-ui, sans-serif; background: #0f172a; color: #e2e8f0;
           display: grid; place-items: center; min-height: 100vh; margin: 0; padding: 16px; }
    .card { background: #1e293b; border-radius: 16px; padding: 32px 40px; max-width: 560px; width: 100%; }
    h1 { margin-top: 0; }
    dt { color: #94a3b8; font-size: 0.85rem; margin-top: 14px; }
    dd { margin: 4px 0 0; font-family: ui-monospace, monospace; font-size: 1.05rem; word-break: break-all; }
    a { color: #38bdf8; }
    p.hint { color: #94a3b8; font-size: 0.9rem; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Projekt dyplomowy DevOps</h1>
    <dl>
      <dt>Wersja (commit)</dt><dd>{{ version }}</dd>
      <dt>Replika (kontener)</dt><dd>{{ hostname }}</dd>
      <dt>Odwiedziny tej repliki</dt><dd>{{ visits }}</dd>
      <dt>Czas działania repliki</dt><dd>{{ uptime }} s</dd>
    </dl>
    <p class="hint">Odśwież stronę: load balancer kieruje ruch na różne repliki.</p>
    <p><a href="/grafana/">Grafana</a> · <a href="/api/info">/api/info</a> · <a href="/health">/health</a></p>
  </div>
</body>
</html>"""


def create_app() -> Flask:
    app = Flask(__name__)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
    log = logging.getLogger("app")

    APP_INFO.labels(APP_VERSION, HOSTNAME).set(1)
    # Liczniki z zerem od startu: bez tego rate() nie widzi pierwszych błędów nowej serii
    for endpoint, status in (("/", "200"), ("/health", "200"), ("/api/error", "500")):
        REQUESTS.labels("GET", endpoint, status)
    started = time.time()
    visits = {"count": 0}
    lock = threading.Lock()

    @app.before_request
    def start_timer():
        g.start = time.perf_counter()

    @app.after_request
    def record_metrics(response):
        # Szablon trasy zamiast pełnej ścieżki, żeby nie mnożyć serii w Prometheusie.
        endpoint = request.url_rule.rule if request.url_rule else "unknown"
        if endpoint != "/metrics":
            REQUESTS.labels(request.method, endpoint, str(response.status_code)).inc()
            LATENCY.labels(endpoint).observe(time.perf_counter() - g.start)
        return response

    @app.get("/")
    def index():
        with lock:
            visits["count"] += 1
            count = visits["count"]
        return render_template_string(
            INDEX_HTML,
            version=APP_VERSION,
            hostname=HOSTNAME,
            visits=count,
            uptime=int(time.time() - started),
        )

    @app.get("/favicon.ico")
    def favicon():
        return "", 204

    @app.get("/health")
    def health():
        return jsonify(status="ok")

    @app.get("/api/info")
    def info():
        return jsonify(version=APP_VERSION, hostname=HOSTNAME, uptime_seconds=int(time.time() - started))

    @app.get("/api/slow")
    def slow():
        """Sztucznie wolna odpowiedź - do pokazania wykresu opóźnień."""
        seconds = min(float(request.args.get("seconds", 1)), 5)
        time.sleep(seconds)
        return jsonify(slept=seconds)

    @app.get("/api/error")
    def error():
        """Celowy błąd 500 - do pokazania alertu o wysokim odsetku błędów."""
        log.error("Celowo wywołany błąd (endpoint demonstracyjny)")
        return jsonify(error="celowy błąd demonstracyjny"), 500

    @app.get("/metrics")
    def metrics():
        return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

    return app
