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
    situacao: Optional[str] = None
) -> tuple[List[models.Patrimonio], int]:
    """
    Buscar patrimônios com filtros opcionais
    Retorna tupla (items, total)
    """
    query = db.query(models.Patrimonio)
    
    # Aplicar filtros
    if sala:
        query = query.filter(models.Patrimonio.sala == sala)
    if responsavel:
        query = query.filter(models.Patrimonio.responsavel == responsavel)
    if situacao:
        query = query.filter(models.Patrimonio.situacao == situacao)
    
    # Contar total
    total = query.count()
    
    # Aplicar paginação
    query = query.offset(skip)
    if limit:
        query = query.limit(limit)
    
    items = query.all()
    
    return items, total


def create_patrimonio(db: Session, patrimonio: schemas.PatrimonioCreate) -> models.Patrimonio:
    """Criar novo patrimônio"""
    db_patrimonio = models.Patrimonio(**patrimonio.model_dump())
    db.add(db_patrimonio)
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
    for field, value in update_data.items():
        setattr(db_patrimonio, field, value)
    
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
