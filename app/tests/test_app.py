import pytest

from app import create_app


@pytest.fixture
def client():
    app = create_app()
    app.config["TESTING"] = True
    return app.test_client()


def test_health(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.get_json() == {"status": "ok"}


def test_index_shows_version_and_hostname(client):
    resp = client.get("/")
    assert resp.status_code == 200
    body = resp.get_data(as_text=True)
    assert "Wersja (commit)" in body
    assert "Replika (kontener)" in body


def test_info(client):
    data = client.get("/api/info").get_json()
    assert set(data) == {"version", "hostname", "uptime_seconds"}


def test_error_endpoint_returns_500(client):
    assert client.get("/api/error").status_code == 500


def test_slow_is_capped(client):
    data = client.get("/api/slow?seconds=0.01").get_json()
    assert data["slept"] == 0.01


def test_metrics_are_recorded(client):
    client.get("/health")
    body = client.get("/metrics").get_data(as_text=True)
    assert 'http_requests_total{endpoint="/health",method="GET",status="200"}' in body
    assert "http_request_duration_seconds_bucket" in body
    assert "app_info{" in body


def test_unknown_route_does_not_create_new_series(client):
    client.get("/nie-istnieje-123")
    body = client.get("/metrics").get_data(as_text=True)
    assert "/nie-istnieje-123" not in body
    assert 'endpoint="unknown"' in body
