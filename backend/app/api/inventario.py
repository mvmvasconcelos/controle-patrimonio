"""
Endpoints de importação e exportação do Inventário
"""
from fastapi import APIRouter, Depends, File, HTTPException, Response, UploadFile
from sqlalchemy.orm import Session

from .. import importer, schemas
from ..database import get_db
from .auth import current_admin, require_csrf

router = APIRouter(dependencies=[Depends(current_admin), Depends(require_csrf)])


def _download(content: bytes, filename: str) -> Response:
    return Response(
        content=content,
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.post("/importar", response_model=schemas.InventarioImportResponse)
async def importar_inventario(
    arquivo: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    content = await arquivo.read(importer.MAX_UPLOAD_BYTES + 1)
    try:
        return importer.import_inventory(db, arquivo.filename, content)
    except importer.InventoryImportError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=500, detail="Falha ao importar o Inventário; nada foi alterado"
        ) from exc


@router.get("/exportar/alteracoes")
def exportar_alteracoes(db: Session = Depends(get_db)):
    return _download(importer.export_changes_csv(db), "alteracoes.csv")


@router.get("/exportar/relatorio")
def exportar_relatorio(db: Session = Depends(get_db)):
    return _download(importer.export_report_csv(db), "relatorio.csv")
