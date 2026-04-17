"""
Endpoints da API REST
"""
from fastapi import APIRouter, Depends, File, HTTPException, Query, Response, UploadFile, status
from sqlalchemy.orm import Session
from typing import Optional
from .. import crud, schemas
from ..database import get_db

router = APIRouter()


@router.get("/patrimonio", response_model=schemas.PatrimonioListResponse)
def list_patrimonios(
    sala: Optional[str] = Query(None, description="Filtrar por sala"),
    responsavel: Optional[str] = Query(None, description="Filtrar por responsável"),
    situacao: Optional[str] = Query(None, description="Filtrar por situação"),
    offset: int = Query(0, ge=0, description="Número de itens para pular"),
    limit: Optional[int] = Query(None, ge=1, description="Número máximo de itens a retornar"),
    db: Session = Depends(get_db)
):
    """
    Listar patrimônios com filtros opcionais
    
    - **sala**: Filtrar por sala específica
    - **responsavel**: Filtrar por responsável
    - **situacao**: Filtrar por situação (Ativo, Baixado, etc)
    - **offset**: Paginação - número de itens para pular
    - **limit**: Paginação - máximo de itens a retornar
    """
    items, total = crud.get_patrimonios(
        db=db,
        skip=offset,
        limit=limit,
        sala=sala,
        responsavel=responsavel,
        situacao=situacao
    )
    
    return schemas.PatrimonioListResponse(
        total=total,
        items=items
    )


@router.get("/patrimonio/{numero_patrimonio}", response_model=schemas.PatrimonioResponse)
def get_patrimonio(
    numero_patrimonio: str,
    db: Session = Depends(get_db)
):
    """
    Buscar patrimônio específico por número
    """
    db_patrimonio = crud.get_patrimonio_by_numero(db, numero_patrimonio)
    if not db_patrimonio:
        raise HTTPException(
            status_code=404,
            detail=f"Patrimônio {numero_patrimonio} não encontrado"
        )
    return db_patrimonio


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


@router.post("/patrimonio", response_model=schemas.PatrimonioResponse, status_code=201)
def create_patrimonio(
    patrimonio: schemas.PatrimonioCreate,
    db: Session = Depends(get_db)
):
    """
    Criar novo patrimônio (para uso do script de importação ou registro manual)
    """
    # Verificar se já existe
    existing = crud.get_patrimonio_by_numero(db, patrimonio.numero_patrimonio)
    if existing:
        raise HTTPException(
            status_code=400,
            detail=f"Patrimônio {patrimonio.numero_patrimonio} já existe"
        )
    
    return crud.create_patrimonio(db=db, patrimonio=patrimonio)


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
