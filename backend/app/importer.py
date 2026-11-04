"""
Importação e exportação do Inventário do SUAP (CSV, XLS e XLSX)
"""
import csv
import io
from dataclasses import dataclass, field
from typing import Optional

import pandas as pd
from sqlalchemy import func
from sqlalchemy.orm import Session

from . import models

MAX_UPLOAD_BYTES = 10 * 1024 * 1024
ZIP_MAGIC = b"PK\x03\x04"
OLE_MAGIC = b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1"

SUAP_COLUMNS = {
    "NUMERO": "numero_patrimonio",
    "DESCRICAO": "descricao",
    "SALA": "sala",
    "CARGA ATUAL": "responsavel",
    "STATUS": "situacao",
}
STANDARD_COLUMNS = list(SUAP_COLUMNS.values())
UPDATABLE_FIELDS = ("descricao", "sala", "responsavel", "situacao")


class InventoryImportError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


@dataclass
class ImportResult:
    novos: int = 0
    atualizados: int = 0
    inalterados: int = 0
    erros: list = field(default_factory=list)


def _extension(filename: Optional[str]) -> str:
    name = (filename or "").lower()
    return name[name.rfind("."):] if "." in name else ""


def _decode_csv(content: bytes) -> str:
    if b"\x00" in content:
        raise InventoryImportError("O arquivo não é um CSV de texto válido")
    for encoding in ("utf-8-sig", "cp1252"):
        try:
            return content.decode(encoding)
        except UnicodeDecodeError:
            continue
    raise InventoryImportError("Não foi possível decodificar o CSV")


def _read_frame(filename: Optional[str], content: bytes) -> pd.DataFrame:
    extension = _extension(filename)
    if extension not in (".csv", ".xls", ".xlsx"):
        raise InventoryImportError("Formato não suportado. Envie um arquivo CSV, XLS ou XLSX")
    if not content:
        raise InventoryImportError("O arquivo está vazio")
    if len(content) > MAX_UPLOAD_BYTES:
        raise InventoryImportError("O arquivo excede o limite de 10 MB", 413)

    try:
        if extension == ".csv":
            text = _decode_csv(content)
            try:
                dialect = csv.Sniffer().sniff(text[:4096], delimiters=",;\t")
                separator = dialect.delimiter
            except csv.Error:
                separator = ","
            frame = pd.read_csv(
                io.StringIO(text), sep=separator, dtype=str, keep_default_na=False
            )
        elif extension == ".xlsx":
            if not content.startswith(ZIP_MAGIC):
                raise InventoryImportError("O conteúdo não corresponde a um arquivo XLSX")
            frame = pd.read_excel(
                io.BytesIO(content), dtype=str, keep_default_na=False, engine="openpyxl"
            )
        else:
            if not content.startswith(OLE_MAGIC):
                raise InventoryImportError("O conteúdo não corresponde a um arquivo XLS")
            frame = pd.read_excel(
                io.BytesIO(content), dtype=str, keep_default_na=False, engine="xlrd"
            )
    except InventoryImportError:
        raise
    except Exception as exc:
        raise InventoryImportError("Não foi possível ler o arquivo enviado") from exc

    frame.columns = [str(column).strip() for column in frame.columns]
    if all(column in frame.columns for column in STANDARD_COLUMNS):
        return frame
    if all(column in frame.columns for column in SUAP_COLUMNS):
        return frame.rename(columns=SUAP_COLUMNS)
    raise InventoryImportError(
        "Colunas obrigatórias ausentes. Use o formato SUAP "
        f"({', '.join(SUAP_COLUMNS)}) ou o padrão ({', '.join(STANDARD_COLUMNS)})",
        422,
    )


def _clean(value) -> str:
    return "" if value is None else str(value).strip()


def _parse_rows(frame: pd.DataFrame, result: ImportResult) -> list[dict]:
    rows: list[dict] = []
    seen: set[str] = set()
    for position, record in enumerate(frame.to_dict("records")):
        line = position + 2
        row = {name: _clean(record.get(name)) for name in STANDARD_COLUMNS}
        if not row["numero_patrimonio"]:
            result.erros.append({"linha": line, "mensagem": "Número do patrimônio ausente"})
        elif not row["descricao"]:
            result.erros.append(
                {"linha": line, "mensagem": f"Descrição ausente ({row['numero_patrimonio']})"}
            )
        elif row["numero_patrimonio"] in seen:
            result.erros.append(
                {"linha": line, "mensagem": f"Número duplicado no arquivo ({row['numero_patrimonio']})"}
            )
        else:
            seen.add(row["numero_patrimonio"])
            rows.append(row)
    return rows


def _apply_rows(db: Session, rows: list[dict], result: ImportResult) -> None:
    existing = {
        item.numero_patrimonio: item
        for item in db.query(models.Patrimonio).filter(
            models.Patrimonio.numero_patrimonio.in_([row["numero_patrimonio"] for row in rows])
        )
    }
    for row in rows:
        item = existing.get(row["numero_patrimonio"])
        if item is None:
            db.add(models.Patrimonio(**row, observacoes=""))
            result.novos += 1
            continue
        changed = False
        for name in UPDATABLE_FIELDS:
            if getattr(item, name) != row[name]:
                setattr(item, name, row[name])
                changed = True
        if changed:
            result.atualizados += 1
        else:
            result.inalterados += 1


def import_inventory(db: Session, filename: Optional[str], content: bytes) -> ImportResult:
    """Importa o Inventário em uma única transação; Conferências e fotos nunca são tocadas."""
    frame = _read_frame(filename, content)
    result = ImportResult()
    rows = _parse_rows(frame, result)
    if not rows:
        detail = "Nenhum registro válido encontrado no arquivo"
        if result.erros:
            detail += f" ({len(result.erros)} linha(s) com erro)"
        raise InventoryImportError(detail, 422)
    try:
        _apply_rows(db, rows, result)
        db.commit()
    except Exception:
        db.rollback()
        raise
    return result


def _safe_cell(value) -> str:
    text = "" if value is None else str(value)
    return "'" + text if text[:1] in ("=", "+", "-", "@", "\t", "\r") else text


def _to_csv(headers: list[str], rows: list[list]) -> bytes:
    buffer = io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow(headers)
    for row in rows:
        writer.writerow([_safe_cell(value) for value in row])
    return buffer.getvalue().encode("utf-8-sig")


REPORT_HEADERS = [
    "numero_patrimonio",
    "descricao",
    "sala",
    "responsavel",
    "situacao",
    "observacoes",
    "conferido",
    "fotos",
]


def _report_rows(db: Session, only_changed: bool) -> list[list]:
    conferidos = {
        numero for (numero,) in db.query(models.Conferencia.numero_patrimonio)
    }
    fotos = dict(
        db.query(models.FotoPatrimonio.numero_patrimonio, func.count(models.FotoPatrimonio.id))
        .group_by(models.FotoPatrimonio.numero_patrimonio)
        .all()
    )
    rows = []
    for item in db.query(models.Patrimonio).order_by(models.Patrimonio.numero_patrimonio):
        number = item.numero_patrimonio
        if only_changed and number not in conferidos and not fotos.get(number):
            continue
        rows.append(
            [
                number,
                item.descricao,
                item.sala,
                item.responsavel,
                item.situacao,
                item.observacoes or "",
                "Sim" if number in conferidos else "Não",
                fotos.get(number, 0),
            ]
        )
    return rows


def export_changes_csv(db: Session) -> bytes:
    """Patrimônios com Conferência ou fotos registradas."""
    return _to_csv(REPORT_HEADERS, _report_rows(db, only_changed=True))


def export_report_csv(db: Session) -> bytes:
    """Relatório completo do Inventário com o estado de Conferência."""
    return _to_csv(REPORT_HEADERS, _report_rows(db, only_changed=False))
