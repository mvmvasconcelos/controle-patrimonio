"""
Endpoints da API REST
"""
from fastapi import APIRouter, Depends, File, HTTPException, Query, Response, UploadFile, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from typing import Optional
from .. import crud, schemas
from ..database import get_db
from .auth import current_admin, require_csrf

router = APIRouter(dependencies=[Depends(current_admin), Depends(require_csrf)])

MAX_PAGE_SIZE = 200
DEFAULT_PAGE_SIZE = 50


def _not_found(numero_patrimonio: str) -> HTTPException:
    return HTTPException(
        status_code=404,
        detail=f"Patrimônio {numero_patrimonio} não encontrado",
    )


@router.get("/patrimonio", response_model=schemas.PatrimonioListResponse)
def list_patrimonios(
    q: Optional[str] = Query(None, description="Busca por número ou descrição"),
    sala: Optional[str] = Query(None, description="Filtrar por sala"),
    responsavel: Optional[str] = Query(None, description="Filtrar por responsável"),
    situacao: Optional[str] = Query(None, description="Filtrar por situação"),
    conferido: Optional[bool] = Query(None, description="Filtrar por conferido ou não"),
    offset: int = Query(0, ge=0, description="Número de itens para pular"),
    limit: int = Query(
        DEFAULT_PAGE_SIZE, ge=1, le=MAX_PAGE_SIZE, description="Itens por página"
    ),
    db: Session = Depends(get_db)
):
    """Listar o Inventário com busca, filtros e paginação estável por número."""
    items, total = crud.get_patrimonios(
        db=db,
        skip=offset,
        limit=limit,
        sala=sala,
        responsavel=responsavel,
        situacao=situacao,
        q=q,
        conferido=conferido,
    )

    return schemas.PatrimonioListResponse(
        total=total,
        items=items
    )


@router.get("/patrimonio/filtros", response_model=schemas.InventarioFiltrosResponse)
def get_filtros(db: Session = Depends(get_db)):
    """Salas e situações existentes, para os filtros da lista."""
    return crud.get_filtros(db)


@router.get(
    "/patrimonio/relatorio/conferencia",
    response_model=schemas.ConferenciaRelatorioResponse,
)
def get_conferencia_report(
    sala: Optional[str] = Query(None, description="Filtrar por sala"),
    situacao: Optional[str] = Query(None, description="Filtrar por situação patrimonial"),
    db: Session = Depends(get_db),
):
    """Relatório agregado de Conferências por sala e situação patrimonial."""
    return crud.get_conferencia_report(db, sala=sala, situacao=situacao)


@router.get(
    "/patrimonio/{numero_patrimonio}",
    response_model=schemas.PatrimonioInventarioResponse,
)
def get_patrimonio(
    numero_patrimonio: str,
    db: Session = Depends(get_db)
):
    """
    Buscar patrimônio específico por número
    """
    item = crud.get_patrimonio_inventario(db, numero_patrimonio.strip())
    if not item:
        raise _not_found(numero_patrimonio)
    return item


@router.patch(
    "/patrimonio/{numero_patrimonio}",
    response_model=schemas.PatrimonioInventarioResponse,
)
def patch_patrimonio(
    numero_patrimonio: str,
    updates: schemas.PatrimonioUpdate,
    db: Session = Depends(get_db),
):
    """Editar campos de um Patrimônio."""
    numero_patrimonio = numero_patrimonio.strip()
    if not updates.model_dump(exclude_unset=True):
        raise HTTPException(
            status_code=400, detail="Nenhum campo para atualizar foi fornecido"
        )
    if not crud.update_patrimonio(db, numero_patrimonio, updates):
        raise _not_found(numero_patrimonio)
    return crud.get_patrimonio_inventario(db, numero_patrimonio)


@router.post(
    "/patrimonio/{numero_patrimonio}/conferencia",
    response_model=schemas.ConferenciaResponse,
)
def conferir_patrimonio(
    numero_patrimonio: str,
    db: Session = Depends(get_db),
):
    """Registrar a Conferência de um Patrimônio (idempotente)."""
    numero_patrimonio = numero_patrimonio.strip()
    result = crud.conferir_patrimonio(db, numero_patrimonio)
    if not result:
        raise _not_found(numero_patrimonio)
    return result


@router.post("/patrimonio/update", response_model=schemas.PatrimonioUpdateResponse)
def update_patrimonio(
    request: schemas.PatrimonioUpdateRequest,
    db: Session = Depends(get_db)
):
    """
    Atualizar dados de um patrimônio existente
    
    - **numero_patrimonio**: Número do patrimônio a atualizar
    - **updates**: Objeto com os campos a serem atualizados
    """
    # Verificar se há campos para atualizar
    if not request.updates.model_dump(exclude_unset=True):
        raise HTTPException(
            status_code=400,
            detail="Nenhum campo para atualizar foi fornecido"
        )
    
    # Tentar atualizar
    updated_item = crud.update_patrimonio(
        db=db,
        numero_patrimonio=request.numero_patrimonio,
        updates=request.updates
    )
    
    if not updated_item:
        return schemas.PatrimonioUpdateResponse(
            success=False,
            message="Item patrimonial não encontrado",
            item=None
        )
    
    return schemas.PatrimonioUpdateResponse(
        success=True,
        message="Item atualizado com sucesso",
        item=updated_item
    )


@router.post(
    "/patrimonio",
    response_model=schemas.PatrimonioInventarioResponse,
    status_code=201,
)
def create_patrimonio(
    patrimonio: schemas.PatrimonioCreate,
    db: Session = Depends(get_db)
):
    """Registrar um Patrimônio fora do Inventário importado."""
    duplicate = HTTPException(
        status_code=409,
        detail=f"Patrimônio {patrimonio.numero_patrimonio} já existe",
    )
    if crud.get_patrimonio_by_numero(db, patrimonio.numero_patrimonio):
        raise duplicate
    try:
        crud.create_patrimonio(db=db, patrimonio=patrimonio)
    except IntegrityError as exc:
        db.rollback()
        raise duplicate from exc
    return crud.get_patrimonio_inventario(db, patrimonio.numero_patrimonio)


@router.post(
    "/patrimonio/{numero_patrimonio}/fotos",
    response_model=schemas.FotoPatrimonioMetadata,
    status_code=201,
)
async def upload_foto_patrimonio(
    numero_patrimonio: str,
    foto: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    """Enviar foto para um patrimônio."""
    image_bytes = await foto.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Arquivo de foto vazio")

    try:
        return crud.create_foto_patrimonio(
            db=db,
            numero_patrimonio=numero_patrimonio,
            image_bytes=image_bytes,
            sync_origin="app",
        )
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc


@router.get(
    "/patrimonio/{numero_patrimonio}/fotos",
    response_model=schemas.FotoPatrimonioListResponse,
)
def list_fotos_patrimonio(
    numero_patrimonio: str,
    db: Session = Depends(get_db),
):
    """Listar metadados das fotos de um patrimônio."""
    items = crud.get_fotos_by_numero(db, numero_patrimonio)
    return schemas.FotoPatrimonioListResponse(total=len(items), items=items)


@router.get("/patrimonio/{numero_patrimonio}/fotos/{foto_id}")
def download_foto_patrimonio(
    numero_patrimonio: str,
    foto_id: int,
    db: Session = Depends(get_db),
):
    """Baixar bytes da foto de um patrimônio."""
    foto = crud.get_foto_by_id(db, numero_patrimonio, foto_id)
    if not foto:
        raise HTTPException(status_code=404, detail="Foto não encontrada")

    return Response(content=foto.imagem_blob, media_type="image/jpeg")


@router.delete(
    "/patrimonio/{numero_patrimonio}/fotos/{foto_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_foto_patrimonio(
    numero_patrimonio: str,
    foto_id: int,
    db: Session = Depends(get_db),
):
    """Remover foto do servidor de forma idempotente."""
    crud.delete_foto_patrimonio(db, numero_patrimonio, foto_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
