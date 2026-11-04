import secrets
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from app.models import Conferencia, Patrimonio

LIST_URL = "/api/v1/patrimonio"


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
        yield test_client


def seed(client, count=5, sala="Sala A"):
    with client.app_ref.state.session_factory() as db:
        for i in range(count):
            db.add(
                Patrimonio(
                    numero_patrimonio=f"{1000 + i}",
                    descricao=f"Mesa {i}" if i % 2 == 0 else f"Cadeira {i}",
                    sala=sala if i < 3 else "Sala B",
                    responsavel="Ana",
                    situacao="Ativo" if i != 4 else "Baixado",
                )
            )
        db.commit()


def new_item(numero="9001", **overrides):
    body = {
        "numero_patrimonio": numero,
        "descricao": "Projetor",
        "sala": "Sala C",
        "responsavel": "Bia",
        "situacao": "Ativo",
    }
    body.update(overrides)
    return body


def test_requires_auth_and_csrf_for_new_endpoints(client):
    seed(client)
    for method, url, body in [
        ("post", f"{LIST_URL}/1000/conferencia", None),
        ("patch", f"{LIST_URL}/1000", {"sala": "X"}),
        ("post", LIST_URL, new_item()),
    ]:
        assert getattr(client, method)(url, json=body).status_code == 403
    client.cookies.clear()
    assert client.get(LIST_URL).status_code == 401
    assert client.get(f"{LIST_URL}/filtros").status_code == 401
    assert client.post(f"{LIST_URL}/1000/conferencia", headers=client.csrf).status_code == 401


def test_list_is_paginated_stably_with_limits(client):
    seed(client, count=5)
    first = client.get(LIST_URL, params={"limit": 2}).json()
    second = client.get(LIST_URL, params={"limit": 2, "offset": 2}).json()
    third = client.get(LIST_URL, params={"limit": 2, "offset": 4}).json()
    numbers = [i["numero_patrimonio"] for p in (first, second, third) for i in p["items"]]
    assert numbers == ["1000", "1001", "1002", "1003", "1004"]
    assert first["total"] == 5
    assert client.get(LIST_URL, params={"limit": 201}).status_code == 422
    assert client.get(LIST_URL, params={"limit": 0}).status_code == 422
    assert client.get(LIST_URL, params={"offset": -1}).status_code == 422
    assert len(client.get(LIST_URL).json()["items"]) == 5


def test_list_search_and_filters(client):
    seed(client)
    def numbers(**params):
        return [i["numero_patrimonio"] for i in client.get(LIST_URL, params=params).json()["items"]]

    assert numbers(q="1002") == ["1002"]
    assert numbers(q="mesa") == ["1000", "1002", "1004"]
    assert numbers(q="mesa", sala="Sala B") == ["1004"]
    assert numbers(situacao="Baixado") == ["1004"]
    assert numbers(q="%") == []
    assert client.get(LIST_URL, params={"q": "mesa"}).json()["total"] == 3


def test_list_conferido_filter_and_flag(client):
    seed(client)
    assert client.post(f"{LIST_URL}/1001/conferencia", headers=client.csrf).status_code == 200

    def items(**params):
        return client.get(LIST_URL, params=params).json()["items"]

    assert [i["numero_patrimonio"] for i in items(conferido="true")] == ["1001"]
    assert len(items(conferido="false")) == 4
    flags = {i["numero_patrimonio"]: i["conferido"] for i in items()}
    assert flags["1001"] is True and flags["1000"] is False
    assert client.get(f"{LIST_URL}/1001").json()["conferido"] is True
    assert client.get(f"{LIST_URL}/1000").json()["conferido"] is False


def test_filters_lists_rooms_and_statuses(client):
    seed(client)
    body = client.get(f"{LIST_URL}/filtros").json()
    assert body == {"salas": ["Sala A", "Sala B"], "situacoes": ["Ativo", "Baixado"]}


def test_conferencia_is_idempotent_and_uses_conferencia_table(client):
    seed(client)
    first = client.post(f"{LIST_URL}/1000/conferencia", headers=client.csrf)
    second = client.post(f"{LIST_URL}/1000/conferencia", headers=client.csrf)
    assert first.status_code == second.status_code == 200
    assert first.json()["numero_patrimonio"] == "1000"
    assert first.json()["conferido_em"] == second.json()["conferido_em"]
    with client.app_ref.state.session_factory() as db:
        assert db.query(Conferencia).filter_by(numero_patrimonio="1000").count() == 1


def test_conferencia_unknown_item_is_404_and_records_nothing(client):
    response = client.post(f"{LIST_URL}/nao-existe/conferencia", headers=client.csrf)
    assert response.status_code == 404
    with client.app_ref.state.session_factory() as db:
        assert db.query(Conferencia).count() == 0


def test_conferencia_trims_scanned_number(client):
    seed(client)
    assert client.post(f"{LIST_URL}/ 1000 /conferencia", headers=client.csrf).status_code == 200


def test_patch_updates_and_validates(client):
    seed(client)
    ok = client.patch(
        f"{LIST_URL}/1000",
        json={"sala": "Sala Z", "observacoes": "riscada"},
        headers=client.csrf,
    )
    assert ok.status_code == 200
    assert ok.json()["sala"] == "Sala Z"
    assert client.get(f"{LIST_URL}/1000").json()["observacoes"] == "riscada"
    assert client.patch(f"{LIST_URL}/1000", json={"sala": "  "}, headers=client.csrf).status_code == 422
    assert client.patch(f"{LIST_URL}/1000", json={}, headers=client.csrf).status_code == 400
    assert client.patch(f"{LIST_URL}/nope", json={"sala": "X"}, headers=client.csrf).status_code == 404


def test_create_validates_and_rejects_duplicates(client):
    seed(client)
    created = client.post(LIST_URL, json=new_item(), headers=client.csrf)
    assert created.status_code == 201
    assert created.json()["conferido"] is False
    assert client.post(LIST_URL, json=new_item(), headers=client.csrf).status_code == 409
    assert client.post(LIST_URL, json=new_item("1000"), headers=client.csrf).status_code == 409
    assert client.post(LIST_URL, json=new_item("  "), headers=client.csrf).status_code == 422
    assert client.post(LIST_URL, json=new_item("9002", descricao=""), headers=client.csrf).status_code == 422
    assert client.post(LIST_URL, json=new_item(" 9003 "), headers=client.csrf).json()["numero_patrimonio"] == "9003"
