from fastapi.testclient import TestClient


def test_health_check(client: TestClient):
    """
    Verify GET /health returns 200 OK and expected structure.
    """
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["service"] == "KharchaAI API"
    assert "version" in data
    assert "timestamp" in data
    assert "database" in data


def test_api_v1_health_check(client: TestClient):
    """
    Verify GET /api/v1/health returns 200 OK and expected structure.
    """
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["service"] == "KharchaAI API"
    assert "version" in data
    assert "timestamp" in data
    assert "database" in data
