import secrets
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import event
from sqlalchemy.orm import Session as OrmSession

from app.main import create_app
from app.models import Patrimonio

URL = "/api/v1/patrimonio"


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
        with app.state.session_factory() as db:
            db.add(
                Patrimonio(
                    numero_patrimonio="1000",
                    descricao="Mesa",
                    sala="Sala A",
                    responsavel="Ana",
                    situacao="Ativo",
                )
            )
            db.commit()
        yield test_client


def patch(client, body):
    return client.patch(f"{URL}/1000", json=body, headers=client.csrf)


def test_newer_client_edit_wins_and_records_time(client):
    response = patch(client, {"sala": "Sala B", "editado_em": "2026-01-01T10:00:00Z"})
    assert response.status_code == 200
    body = response.json()
    assert body["sala"] == "Sala B"
    assert body["edicao_aplicada"] is True
    assert body["editado_em"].startswith("2026-01-01T10:00:00")


def test_older_client_edit_is_discarded_and_returns_current_state(client):
    patch(client, {"sala": "Sala B", "editado_em": "2026-01-01T10:00:00Z"})
    response = patch(client, {"sala": "Sala C", "editado_em": "2026-01-01T09:59:59Z"})
    assert response.status_code == 200
    body = response.json()
    assert body["edicao_aplicada"] is False
    assert body["sala"] == "Sala B"
    assert client.get(f"{URL}/1000").json()["sala"] == "Sala B"


def test_retry_with_same_time_is_idempotent_and_later_edit_wins(client):
    first = {"descricao": "Mesa 2", "editado_em": "2026-01-01T10:00:00Z"}
    assert patch(client, first).json()["edicao_aplicada"] is True
    assert patch(client, first).json()["edicao_aplicada"] is True
    later = patch(client, {"descricao": "Mesa 3", "editado_em": "2026-01-01T10:00:01+00:00"})
    assert later.json()["descricao"] == "Mesa 3"


def test_offset_times_are_compared_as_instants(client):
    patch(client, {"sala": "Sala B", "editado_em": "2026-01-01T10:00:00Z"})
    older = patch(client, {"sala": "X", "editado_em": "2026-01-01T08:00:00-03:00"})
    assert older.json()["edicao_aplicada"] is True
    stale = patch(client, {"sala": "Y", "editado_em": "2026-01-01T06:00:00-03:00"})
    assert stale.json()["edicao_aplicada"] is False


def test_edit_without_time_uses_server_time_and_beats_old_offline_edit(client):
    assert patch(client, {"sala": "Sala B"}).json()["edicao_aplicada"] is True
    stale = patch(client, {"sala": "Sala C", "editado_em": "2020-01-01T00:00:00Z"})
    assert stale.json()["edicao_aplicada"] is False
    assert client.get(f"{URL}/1000").json()["sala"] == "Sala B"


def test_future_client_time_is_clamped_to_server_time(client):
    patch(client, {"sala": "Sala B", "editado_em": "2999-01-01T00:00:00Z"})
    later = patch(client, {"sala": "Sala C"})
    assert later.json()["edicao_aplicada"] is True
    assert later.json()["sala"] == "Sala C"


def test_editado_em_alone_is_not_an_update(client):
    assert patch(client, {"editado_em": "2026-01-01T10:00:00Z"}).status_code == 400


def test_lww_edit_and_timestamp_commit_atomically(client):
    commits = 0

    def count_commit(_session):
        nonlocal commits
        commits += 1

    event.listen(OrmSession, "before_commit", count_commit)
    try:
        response = patch(
            client,
            {"sala": "Sala atômica", "editado_em": "2026-01-01T10:00:00Z"},
        )
    finally:
        event.remove(OrmSession, "before_commit", count_commit)

    assert response.status_code == 200
    assert commits == 1


def test_conferencia_uses_client_time_and_stays_idempotent(client):
    response = client.post(
        f"{URL}/1000/conferencia",
        json={"editado_em": "2026-01-01T10:00:00Z"},
        headers=client.csrf,
    )
    assert response.status_code == 200
    assert response.json()["conferido_em"].startswith("2026-01-01T10:00:00")
    again = client.post(
        f"{URL}/1000/conferencia",
        json={"editado_em": "2026-02-01T10:00:00Z"},
        headers=client.csrf,
    )
    assert again.json()["repetida"] is True
    assert again.json()["conferido_em"].startswith("2026-01-01T10:00:00")


def test_conferencia_without_body_still_works(client):
    response = client.post(f"{URL}/1000/conferencia", headers=client.csrf)
    assert response.status_code == 200 and response.json()["repetida"] is False
