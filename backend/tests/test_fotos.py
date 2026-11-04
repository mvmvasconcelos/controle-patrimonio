import secrets
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from app.api.endpoints import MAX_FOTO_BYTES
from app.main import create_app
from app.models import FotoPatrimonio, Patrimonio

JPEG = b"\xff\xd8\xff\xe0" + b"jpeg-bytes"


@pytest.fixture
def client(monkeypatch):
    username = f"admin-{uuid4().hex}"
    password = secrets.token_urlsafe(32)
    monkeypatch.setenv("ADMIN_USER", username)
    monkeypatch.setenv("ADMIN_PASSWORD", password)
    monkeypatch.setenv("JWT_SECRET_KEY", secrets.token_urlsafe(48))
    app = create_app(database_url="sqlite://")
    with TestClient(app, base_url="https://testserver") as test_client:
        test_client.post(
            "/api/v1/auth/login",
            json={"username": username, "password": password},
        )
        test_client.csrf = {"X-CSRF-Token": test_client.cookies["patrimonio_csrf"]}
        test_client.app_ref = app
        with app.state.session_factory() as db:
            for numero in ("1", "2"):
                db.add(
                    Patrimonio(
                        numero_patrimonio=numero,
                        descricao="Mesa",
                        sala="A",
                        responsavel="Ana",
                        situacao="Ativo",
                    )
                )
            db.commit()
        yield test_client


def url(numero="1", foto_id=None):
    base = f"/api/v1/patrimonio/{numero}/fotos"
    return base if foto_id is None else f"{base}/{foto_id}"


def upload(client, data=JPEG, numero="1", content_type="image/jpeg", csrf=True):
    return client.post(
        url(numero),
        files={"foto": ("foto.jpg", data, content_type)},
        headers=client.csrf if csrf else {},
    )


def test_requires_auth_and_csrf(client):
    assert upload(client, csrf=False).status_code == 403
    anonymous = TestClient(client.app_ref, base_url="https://testserver")
    assert anonymous.get(url()).status_code == 401
    assert anonymous.get(url(foto_id=1)).status_code == 401
    created = upload(client).json()
    assert client.delete(url(foto_id=created["id"])).status_code == 403


def test_upload_list_download_and_delete_round_trip(client):
    created = upload(client)
    assert created.status_code == 201
    foto_id = created.json()["id"]

    listed = client.get(url()).json()
    assert listed["total"] == 1
    assert listed["items"][0]["id"] == foto_id

    downloaded = client.get(url(foto_id=foto_id))
    assert downloaded.status_code == 200
    assert downloaded.content == JPEG
    assert downloaded.headers["content-type"] == "image/jpeg"
    assert downloaded.headers["x-content-type-options"] == "nosniff"

    assert client.delete(url(foto_id=foto_id), headers=client.csrf).status_code == 204
    assert client.delete(url(foto_id=foto_id), headers=client.csrf).status_code == 204
    assert client.get(url()).json()["total"] == 0


def test_photos_are_kept_per_patrimonio(client):
    foto_id = upload(client, numero="1").json()["id"]
    upload(client, numero="2")

    assert client.get(url("1")).json()["total"] == 1
    assert client.get(url("2")).json()["total"] == 1
    assert client.get(url("2", foto_id)).status_code == 404
    client.delete(url("2", foto_id), headers=client.csrf)
    assert client.get(url("1")).json()["total"] == 1


def test_unknown_patrimonio_is_404(client):
    assert upload(client, numero="999").status_code == 404
    assert client.get(url("999")).status_code == 404


def test_limit_of_three_photos_returns_409(client):
    for _ in range(3):
        assert upload(client).status_code == 201
    rejected = upload(client)
    assert rejected.status_code == 409
    assert "3 fotos" in rejected.json()["detail"]


def test_rejects_empty_file(client):
    response = upload(client, data=b"")
    assert response.status_code == 400
    assert "vazio" in response.json()["detail"]


def test_rejects_non_jpeg_mime_and_content(client):
    wrong_mime = upload(client, content_type="text/plain")
    assert wrong_mime.status_code == 415
    fake = upload(client, data=b"<html>not an image</html>")
    assert fake.status_code == 415
    assert client.get(url()).json()["total"] == 0


def test_rejects_oversized_file(client):
    response = upload(client, data=JPEG + b"0" * MAX_FOTO_BYTES)
    assert response.status_code == 413
    assert "MB" in response.json()["detail"]
    with client.app_ref.state.session_factory() as db:
        assert db.query(FotoPatrimonio).count() == 0
