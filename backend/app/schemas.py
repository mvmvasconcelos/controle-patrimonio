"""
Schemas Pydantic para validação de dados
"""
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class PatrimonioBase(BaseModel):
    """Schema base para Patrimonio"""
    numero_patrimonio: str = Field(..., description="Número único do patrimônio")
    descricao: str = Field(..., description="Descrição do item")
    sala: str = Field(..., description="Sala/localização atual")
    responsavel: str = Field(..., description="Nome do responsável")
    situacao: str = Field(..., description="Situação do item (Ativo, Baixado, etc)")
    observacoes: Optional[str] = Field(None, description="Observações adicionais")
    foto_url: Optional[str] = Field(None, description="URL da foto do item")


class PatrimonioCreate(PatrimonioBase):
    """Schema para criação de novo patrimônio"""
    pass


class PatrimonioUpdate(BaseModel):
    """Schema para atualização de patrimônio (campos opcionais)"""
    descricao: Optional[str] = None
    sala: Optional[str] = None
    responsavel: Optional[str] = None
    situacao: Optional[str] = None
    observacoes: Optional[str] = None
    foto_url: Optional[str] = None


class PatrimonioResponse(PatrimonioBase):
    """Schema para resposta com dados do patrimônio"""
    id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class PatrimonioListResponse(BaseModel):
    """Schema para resposta de lista de patrimônios"""
    total: int
    items: list[PatrimonioResponse]


class PatrimonioUpdateRequest(BaseModel):
    """Schema para requisição de atualização"""
    numero_patrimonio: str = Field(..., description="Número do patrimônio a atualizar")
    updates: PatrimonioUpdate = Field(..., description="Campos a serem atualizados")


class PatrimonioUpdateResponse(BaseModel):
    """Schema para resposta de atualização"""
    success: bool
    message: str
    item: Optional[PatrimonioResponse] = None


class ErrorResponse(BaseModel):
    """Schema para resposta de erro"""
    success: bool = False
    message: str
    numero_patrimonio: Optional[str] = None


class FotoPatrimonioMetadata(BaseModel):
    """Metadados de uma foto patrimonial."""

    id: int
    numero_patrimonio: str
    data_modificacao: datetime
    sync_origin: str

    class Config:
        from_attributes = True


class FotoPatrimonioListResponse(BaseModel):
    """Lista de fotos de um item patrimonial."""

    total: int
    items: list[FotoPatrimonioMetadata]
