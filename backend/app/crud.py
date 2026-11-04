"""
Operações CRUD para o banco de dados
"""
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import Optional, List
from . import models, schemas


def get_patrimonio_by_numero(db: Session, numero_patrimonio: str) -> Optional[models.Patrimonio]:
    """Buscar patrimônio por número"""
    return db.query(models.Patrimonio).filter(
        models.Patrimonio.numero_patrimonio == numero_patrimonio
    ).first()


def get_patrimonios(
    db: Session,
    skip: int = 0,
    limit: Optional[int] = None,
    sala: Optional[str] = None,
    responsavel: Optional[str] = None,
    situacao: Optional[str] = None,
    q: Optional[str] = None,
    conferido: Optional[bool] = None,
) -> tuple[list[dict], int]:
    """
    Buscar patrimônios com filtros opcionais, em ordem estável por número.
    Retorna tupla (items, total); cada item inclui o estado de Conferência.
    """
    query = db.query(
        models.Patrimonio, models.Conferencia.conferido_em
    ).outerjoin(
        models.Conferencia,
        models.Conferencia.numero_patrimonio == models.Patrimonio.numero_patrimonio,
    )

    if q and q.strip():
        escaped = (
            q.strip().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
        )
        pattern = f"%{escaped}%"
        query = query.filter(
            models.Patrimonio.numero_patrimonio.ilike(pattern, escape="\\")
            | models.Patrimonio.descricao.ilike(pattern, escape="\\")
        )
    if conferido is True:
        query = query.filter(models.Conferencia.id.isnot(None))
    elif conferido is False:
        query = query.filter(models.Conferencia.id.is_(None))
    if sala:
        query = query.filter(models.Patrimonio.sala == sala)
    if responsavel:
        query = query.filter(models.Patrimonio.responsavel == responsavel)
    if situacao:
        query = query.filter(models.Patrimonio.situacao == situacao)

    total = query.count()

    query = query.order_by(
        models.Patrimonio.numero_patrimonio, models.Patrimonio.id
    ).offset(skip)
    if limit:
        query = query.limit(limit)

    items = [
        _with_conferencia(item, conferido_em) for item, conferido_em in query.all()
    ]

    return items, total


def _with_conferencia(item: models.Patrimonio, conferido_em) -> dict:
    data = schemas.PatrimonioResponse.model_validate(item).model_dump()
    data["conferido"] = conferido_em is not None
    data["conferido_em"] = conferido_em
    return data


def get_conferido_em(db: Session, numero_patrimonio: str):
    return (
        db.query(models.Conferencia.conferido_em)
        .filter(models.Conferencia.numero_patrimonio == numero_patrimonio)
        .scalar()
    )


def get_patrimonio_inventario(db: Session, numero_patrimonio: str) -> Optional[dict]:
    item = get_patrimonio_by_numero(db, numero_patrimonio)
    if not item:
        return None
    return _with_conferencia(item, get_conferido_em(db, numero_patrimonio))


def get_filtros(db: Session) -> dict:
    def distinct(column):
        return [
            value
            for (value,) in db.query(column).distinct().order_by(column)
            if value
        ]

    return {
        "salas": distinct(models.Patrimonio.sala),
        "situacoes": distinct(models.Patrimonio.situacao),
    }


def conferir_patrimonio(db: Session, numero_patrimonio: str) -> Optional[dict]:
    """Registra a Conferência de forma idempotente; None se o Patrimônio não existe."""
    if not get_patrimonio_by_numero(db, numero_patrimonio):
        return None
    conferido_em = get_conferido_em(db, numero_patrimonio)
    repetida = conferido_em is not None
    if conferido_em is None:
        db.add(models.Conferencia(numero_patrimonio=numero_patrimonio))
        db.commit()
        conferido_em = get_conferido_em(db, numero_patrimonio)
    return {
        "numero_patrimonio": numero_patrimonio,
        "conferido_em": conferido_em,
        "repetida": repetida,
    }


def create_patrimonio(db: Session, patrimonio: schemas.PatrimonioCreate) -> models.Patrimonio:
    """Criar um Patrimônio e, quando solicitado, sua Conferência atomicamente."""
    data = patrimonio.model_dump(exclude={"conferido"})
    db_patrimonio = models.Patrimonio(**data)
    db.add(db_patrimonio)
    if patrimonio.conferido:
        db.add(models.Conferencia(numero_patrimonio=patrimonio.numero_patrimonio))
    db.commit()
    db.refresh(db_patrimonio)
    return db_patrimonio


def update_patrimonio(
    db: Session,
    numero_patrimonio: str,
    updates: schemas.PatrimonioUpdate
) -> Optional[models.Patrimonio]:
    """
    Atualizar patrimônio existente
    Retorna o item atualizado ou None se não encontrado
    """
    db_patrimonio = get_patrimonio_by_numero(db, numero_patrimonio)
    
    if not db_patrimonio:
        return None
    
    # Atualizar apenas campos fornecidos
    update_data = updates.model_dump(exclude_unset=True)
    changed = False
    for field, value in update_data.items():
        if getattr(db_patrimonio, field) != value:
            setattr(db_patrimonio, field, value)
            changed = True

    if not changed:
        return db_patrimonio

    db.commit()
    db.refresh(db_patrimonio)
    return db_patrimonio


def delete_patrimonio(db: Session, numero_patrimonio: str) -> bool:
    """Deletar patrimônio (se necessário futuramente)"""
    db_patrimonio = get_patrimonio_by_numero(db, numero_patrimonio)
    if db_patrimonio:
        db.delete(db_patrimonio)
        db.commit()
        return True
    return False


def get_fotos_by_numero(
    db: Session,
    numero_patrimonio: str,
) -> List[models.FotoPatrimonio]:
    """Listar fotos de um patrimônio."""
    return (
        db.query(models.FotoPatrimonio)
        .filter(models.FotoPatrimonio.numero_patrimonio == numero_patrimonio)
        .order_by(models.FotoPatrimonio.data_modificacao.desc(), models.FotoPatrimonio.id.desc())
        .all()
    )


def get_foto_by_id(
    db: Session,
    numero_patrimonio: str,
    foto_id: int,
) -> Optional[models.FotoPatrimonio]:
    """Buscar foto específica de um patrimônio."""
    return (
        db.query(models.FotoPatrimonio)
        .filter(
            models.FotoPatrimonio.numero_patrimonio == numero_patrimonio,
            models.FotoPatrimonio.id == foto_id,
        )
        .first()
    )


def create_foto_patrimonio(
    db: Session,
    numero_patrimonio: str,
    image_bytes: bytes,
    sync_origin: str = "app",
) -> models.FotoPatrimonio:
    """Criar nova foto para um patrimônio."""
    total = (
        db.query(func.count(models.FotoPatrimonio.id))
        .filter(models.FotoPatrimonio.numero_patrimonio == numero_patrimonio)
        .scalar()
    )

    if (total or 0) >= 3:
        raise ValueError("Limite de 3 fotos por patrimônio atingido")

    db_photo = models.FotoPatrimonio(
        numero_patrimonio=numero_patrimonio,
        imagem_blob=image_bytes,
        sync_origin=sync_origin,
    )
    db.add(db_photo)
    db.commit()
    db.refresh(db_photo)
    return db_photo


def delete_foto_patrimonio(
    db: Session,
    numero_patrimonio: str,
    foto_id: int,
) -> bool:
    """Remover foto de um patrimônio."""
    db_photo = get_foto_by_id(db, numero_patrimonio, foto_id)
    if not db_photo:
        return False

    db.delete(db_photo)
    db.commit()
    return True
