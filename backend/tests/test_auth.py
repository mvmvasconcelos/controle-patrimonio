import base64
import hashlib
import hmac
import json
import secrets
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from app.models import Usuario


@pytest.fixture
def client(monkeypatch):
    username = f"admin-{uuid4().hex}"
    password = secrets.token_urlsafe(32)
    secret = secrets.token_urlsafe(48)
    monkeypatch.setenv("ADMIN_USER", username)
    monkeypatch.setenv("ADMIN_PASSWORD", password)
    monkeypatch.setenv("JWT_SECRET_KEY", secret)
    app = create_app(database_url="sqlite://")
    with TestClient(app, base_url="https://testserver") as test_client:
        test_client.admin_username = username
        test_client.admin_password = password
        test_client.jwt_secret = secret
        yield test_client


def login(client):
    return client.post(
        "/api/v1/auth/login",
        json={
            "username": client.admin_username,
            "password": client.admin_password,
        },
    )


def decode_segment(value):
    return json.loads(base64.urlsafe_b64decode(value + "=" * (-len(value) % 4)))


def expired_token(secret, username):
    header = base64.urlsafe_b64encode(
        json.dumps({"alg": "HS256", "typ": "JWT"}).encode()
    ).rstrip(b"=")
    payload = base64.urlsafe_b64encode(
        json.dumps(
            {
                "sub": username,
                "role": "administrador",
                "iat": 1,
                "exp": 2,
            }
        ).encode()
    ).rstrip(b"=")
    unsigned = header + b"." + payload
    signature = base64.urlsafe_b64encode(
        hmac.new(secret.encode(), unsigned, hashlib.sha256).digest()
    ).rstrip(b"=")
    return (unsigned + b"." + signature).decode()


def test_login_sets_http_only_30_day_session_cookie_without_returning_jwt(client):
    response = login(client)

    assert response.status_code == 200
    assert response.json()["username"] == client.admin_username
    assert response.json()["role"] == "administrador"
    assert response.json()["csrf_token"] == client.cookies.get("patrimonio_csrf")
    assert "token" not in response.json()

    session = client.cookies.get("patrimonio_session")
    csrf = client.cookies.get("patrimonio_csrf")
    assert session
    assert csrf
    set_cookies = response.headers.get_list("set-cookie")
    session_cookie = next(value for value in set_cookies if "patrimonio_session=" in value)
    csrf_cookie = next(value for value in set_cookies if "patrimonio_csrf=" in value)
    assert "httponly" in session_cookie.lower()
    assert "secure" in session_cookie.lower()
    assert "samesite=lax" in session_cookie.lower()
    assert f"max-age={30 * 24 * 60 * 60}" in session_cookie.lower()
    assert "httponly" not in csrf_cookie.lower()
    assert "secure" in csrf_cookie.lower()
    assert "samesite=lax" in csrf_cookie.lower()

    payload = decode_segment(session.split(".")[1])
    assert payload["exp"] - payload["iat"] == 30 * 24 * 60 * 60
    assert client.get("/api/v1/patrimonio").status_code == 200


def test_invalid_login_does_not_issue_authentication_cookies(client):
    response = client.post(
        "/api/v1/auth/login",
        json={
            "username": client.admin_username,
            "password": secrets.token_urlsafe(32),
        },
    )

    assert response.status_code == 401
    assert client.cookies.get("patrimonio_session") is None
    assert client.cookies.get("patrimonio_csrf") is None


def test_protected_inventory_requires_authentication(client):
    response = client.get("/api/v1/patrimonio")

    assert response.status_code == 401
    assert client.get("/").status_code == 401
    assert client.get("/openapi.json").status_code == 404


def test_health_is_public_and_seeded_password_is_hashed(client):
    assert client.get("/health").status_code == 200
    with client.app.state.session_factory() as db:
        user = db.query(Usuario).filter_by(username=client.admin_username).one()

    assert user.password_hash != client.admin_password
    assert user.password_hash.startswith("pbkdf2_sha256$")
    assert "role" not in Usuario.__table__.columns


def test_expired_session_is_rejected(client):
    client.cookies.set(
        "patrimonio_session",
        expired_token(client.jwt_secret, client.admin_username),
    )

    response = client.get("/api/v1/patrimonio")

    assert response.status_code == 401


def test_malformed_session_is_rejected_as_unauthorized(client):
    client.cookies.set("patrimonio_session", "____.e30.invalid")

    response = client.get("/api/v1/patrimonio")

    assert response.status_code == 401


def test_mutations_require_the_csrf_cookie_value_in_header(client):
    login(client)
    payload = {
        "numero_patrimonio": f"test-{uuid4().hex}",
        "descricao": "Bem de teste",
        "sala": "Sala de teste",
        "responsavel": "Administrador",
        "situacao": "Ativo",
    }

    rejected = client.post("/api/v1/patrimonio", json=payload)

    assert rejected.status_code == 403
    rejected_tampered = client.post(
        "/api/v1/patrimonio",
        json=payload,
        headers={"X-CSRF-Token": f"{client.cookies['patrimonio_csrf']}tampered"},
    )
    assert rejected_tampered.status_code == 403
    accepted = client.post(
        "/api/v1/patrimonio",
        json=payload,
        headers={"X-CSRF-Token": client.cookies["patrimonio_csrf"]},
    )
    assert accepted.status_code == 201


def test_logout_clears_session_and_csrf_cookies(client):
    login(client)
    response = client.post(
        "/api/v1/auth/logout",
        headers={"X-CSRF-Token": client.cookies["patrimonio_csrf"]},
    )

    assert response.status_code == 204
    assert client.get("/api/v1/patrimonio").status_code == 401
    set_cookies = response.headers.get_list("set-cookie")
    assert any("patrimonio_session=" in value and "max-age=0" in value.lower() for value in set_cookies)
    assert any("patrimonio_csrf=" in value and "max-age=0" in value.lower() for value in set_cookies)
