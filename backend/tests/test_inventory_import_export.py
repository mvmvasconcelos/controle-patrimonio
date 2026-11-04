import io
import secrets
from uuid import uuid4

import pandas as pd
import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from app.models import Conferencia, FotoPatrimonio, Patrimonio

IMPORT_URL = "/api/v1/inventario/importar"
CHANGES_URL = "/api/v1/inventario/exportar/alteracoes"
REPORT_URL = "/api/v1/inventario/exportar/relatorio"

HEADER = "NUMERO,DESCRICAO,SALA,CARGA ATUAL,STATUS\n"


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


def upload(client, name, content, content_type="application/octet-stream", csrf=True):
    return client.post(
        IMPORT_URL,
        files={"arquivo": (name, content, content_type)},
        headers=client.csrf if csrf else {},
    )


def csv_bytes(*rows, header=HEADER):
    return (header + "".join(row + "\n" for row in rows)).encode("utf-8")


def db_session(client):
    return client.app_ref.state.session_factory()


def test_import_requires_authentication_and_csrf(client):
    assert upload(client, "inv.csv", csv_bytes("1,Mesa,S1,Ana,Ativo"), csrf=False).status_code == 403
    client.cookies.clear()
    assert upload(client, "inv.csv", csv_bytes("1,Mesa,S1,Ana,Ativo")).status_code == 401
    assert client.get(CHANGES_URL).status_code == 401
    assert client.get(REPORT_URL).status_code == 401


def test_import_csv_reports_new_updated_and_row_errors(client):
    first = upload(
        client,
        "inv.csv",
        csv_bytes("1,Mesa,S1,Ana,Ativo", "2,Cadeira,S1,Ana,Ativo", ",Sem numero,S1,Ana,Ativo"),
    )
    assert first.status_code == 200
    body = first.json()
    assert (body["novos"], body["atualizados"], body["inalterados"]) == (2, 0, 0)
    assert len(body["erros"]) == 1
    assert body["erros"][0]["linha"] == 4

    second = upload(
        client,
        "inv.csv",
        csv_bytes("1,Mesa grande,S1,Ana,Ativo", "2,Cadeira,S1,Ana,Ativo", "3,Quadro,S2,Bia,Ativo"),
    )
    body = second.json()
    assert (body["novos"], body["atualizados"], body["inalterados"]) == (1, 1, 1)

    with db_session(client) as db:
        assert db.query(Patrimonio).count() == 3
        assert db.query(Patrimonio).filter_by(numero_patrimonio="1").one().descricao == "Mesa grande"


def test_import_accepts_standard_columns_semicolon_and_latin1(client):
    content = (
        "numero_patrimonio;descricao;sala;responsavel;situacao\n"
        "10;Cafeteira ção;S1;Ana;Ativo\n"
    ).encode("latin-1")
    response = upload(client, "inv.csv", content)
    assert response.status_code == 200
    assert response.json()["novos"] == 1


def test_import_accepts_xlsx(client):
    buffer = io.BytesIO()
    pd.DataFrame(
        [{"NUMERO": "77", "DESCRICAO": "Mesa", "SALA": "S", "CARGA ATUAL": "A", "STATUS": "Ativo"}]
    ).to_excel(buffer, index=False)
    response = upload(client, "inv.xlsx", buffer.getvalue())
    assert response.status_code == 200
    assert response.json()["novos"] == 1


@pytest.mark.parametrize(
    "name,content",
    [
        ("inv.txt", b"abc"),
        ("inv.csv", b""),
        ("inv.csv", b"NUMERO,DESCRICAO\n1,Mesa\n"),
        ("inv.csv", HEADER.encode()),
        ("inv.csv", b"\x00\x01\x02\xff\xfe binary"),
        ("inv.xlsx", b"nao e um xlsx"),
        ("inv.xls", b"nao e um xls"),
        ("inv.csv", csv_bytes(",Sem numero,S,A,Ativo")),
    ],
)
def test_invalid_file_is_rejected_without_changing_data(client, name, content):
    response = upload(client, name, content)
    assert response.status_code in (400, 422)
    assert response.json()["detail"]
    with db_session(client) as db:
        assert db.query(Patrimonio).count() == 0


def test_import_rolls_back_everything_on_failure(client, monkeypatch):
    from app import importer

    def boom(*args, **kwargs):
        raise RuntimeError("falha simulada")

    monkeypatch.setattr(importer, "_apply_rows", boom)
    response = upload(client, "inv.csv", csv_bytes("1,Mesa,S1,Ana,Ativo"))
    assert response.status_code == 500 or response.status_code == 400
    with db_session(client) as db:
        assert db.query(Patrimonio).count() == 0


def test_reimport_preserves_conferencias_and_photos(client):
    upload(client, "inv.csv", csv_bytes("1,Mesa,S1,Ana,Ativo", "2,Cadeira,S1,Ana,Ativo"))
    with db_session(client) as db:
        db.add(Conferencia(numero_patrimonio="1"))
        db.add(FotoPatrimonio(numero_patrimonio="1", imagem_blob=b"jpeg-bytes"))
        db.commit()

    response = upload(client, "inv.csv", csv_bytes("1,Mesa nova,S9,Bia,Baixado"))
    assert response.status_code == 200
    assert response.json()["atualizados"] == 1

    with db_session(client) as db:
        assert db.query(Conferencia).filter_by(numero_patrimonio="1").count() == 1
        foto = db.query(FotoPatrimonio).filter_by(numero_patrimonio="1").one()
        assert foto.imagem_blob == b"jpeg-bytes"
        assert db.query(Patrimonio).filter_by(numero_patrimonio="2").count() == 1


def test_export_changes_downloads_conferidos_and_photographed_items(client):
    upload(
        client,
        "inv.csv",
        csv_bytes("1,Mesa,S1,Ana,Ativo", "2,Cadeira,S1,Ana,Ativo", "3,Quadro,S1,Ana,Ativo"),
    )
    with db_session(client) as db:
        db.add(Conferencia(numero_patrimonio="1"))
        db.add(FotoPatrimonio(numero_patrimonio="2", imagem_blob=b"x"))
        db.commit()
    updated = client.post(
        "/api/v1/patrimonio/update",
        json={
            "numero_patrimonio": "3",
            "updates": {"descricao": "Quadro revisado"},
        },
        headers=client.csrf,
    )
    assert updated.status_code == 200

    response = client.get(CHANGES_URL)
    assert response.status_code == 200
    assert "attachment" in response.headers["content-disposition"]
    assert ".csv" in response.headers["content-disposition"]
    frame = pd.read_csv(io.BytesIO(response.content), dtype=str, encoding="utf-8-sig")
    assert sorted(frame["numero_patrimonio"]) == ["1", "2", "3"]


def test_reimport_does_not_mark_imported_changes_as_field_edits(client):
    upload(client, "inv.csv", csv_bytes("1,Mesa,S1,Ana,Ativo"))

    response = upload(client, "inv.csv", csv_bytes("1,Mesa atualizada,S2,Ana,Ativo"))
    assert response.status_code == 200
    with db_session(client) as db:
        item = db.query(Patrimonio).filter_by(numero_patrimonio="1").one()
        assert item.updated_at == item.created_at
    changes = client.get(CHANGES_URL)
    frame = pd.read_csv(io.BytesIO(changes.content), dtype=str, encoding="utf-8-sig")

    assert frame.empty


def test_export_report_lists_all_items_and_neutralizes_formulas(client):
    upload(client, "inv.csv", csv_bytes("1,=HYPERLINK(1),S1,Ana,Ativo", "2,Cadeira,S1,Ana,Ativo"))
    with db_session(client) as db:
        db.add(Conferencia(numero_patrimonio="1"))
        db.commit()

    response = client.get(REPORT_URL)
    assert response.status_code == 200
    assert "attachment" in response.headers["content-disposition"]
    frame = pd.read_csv(io.BytesIO(response.content), dtype=str, encoding="utf-8-sig")
    assert len(frame) == 2
    assert frame.set_index("numero_patrimonio").loc["1", "conferido"] == "Sim"
    assert frame.set_index("numero_patrimonio").loc["2", "conferido"] == "Não"
    assert not frame["descricao"].iloc[0].startswith("=")
