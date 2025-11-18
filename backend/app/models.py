"""
Modelos SQLAlchemy para o banco de dados
"""
from sqlalchemy import Column, Integer, String, DateTime, Index
from sqlalchemy.sql import func
from .database import Base


class Patrimonio(Base):
    """
    Modelo da tabela patrimonio
    Armazena informações dos itens patrimoniais do IFSUL
    """
    __tablename__ = "patrimonio"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    numero_patrimonio = Column(String, unique=True, index=True, nullable=False)
    descricao = Column(String, nullable=False)
    sala = Column(String, index=True, nullable=False)
    responsavel = Column(String, nullable=False)
    situacao = Column(String, nullable=False)
    observacoes = Column(String, nullable=True)
    foto_url = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # Índices adicionais para otimização de busca
    __table_args__ = (
        Index('idx_sala_responsavel', 'sala', 'responsavel'),
    )

    def __repr__(self):
        return f"<Patrimonio(numero={self.numero_patrimonio}, descricao={self.descricao})>"
