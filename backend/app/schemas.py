"""
Schemas Pydantic para validação de dados
"""
from pydantic import BaseModel, Field, field_validator
from typing import List, Optional
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
    conferido: bool = False

    @field_validator(
        "numero_patrimonio", "descricao", "sala", "responsavel", "situacao"
    )
    @classmethod
    def _required_text(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Campo obrigatório")
        return value


class PatrimonioUpdate(BaseModel):
    """Schema para atualização de patrimônio (campos opcionais)"""
    descricao: Optional[str] = None
    sala: Optional[str] = None
    responsavel: Optional[str] = None
    situacao: Optional[str] = None
    observacoes: Optional[str] = None
    foto_url: Optional[str] = None

    @field_validator("descricao", "sala", "responsavel", "situacao")
    @classmethod
    def _required_text(cls, value: Optional[str]) -> str:
        if value is None or not value.strip():
            raise ValueError("Campo obrigatório")
        return value.strip()


class PatrimonioResponse(PatrimonioBase):
    """Schema para resposta com dados do patrimônio"""
    id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class PatrimonioInventarioResponse(PatrimonioResponse):
    """Patrimônio com o estado de Conferência"""
    conferido: bool = False
    conferido_em: Optional[datetime] = None


class PatrimonioListResponse(BaseModel):
    """Schema para resposta de lista de patrimônios"""
    total: int
    items: list[PatrimonioInventarioResponse]


class InventarioFiltrosResponse(BaseModel):
    salas: list[str]
    situacoes: list[str]


class ConferenciaRelatorioGrupo(BaseModel):
    sala: str
    situacao: str
    total: int
    conferidos: int
    pendentes: int


class ConferenciaRelatorioResponse(BaseModel):
    total: int
    conferidos: int
    pendentes: int
    grupos: list[ConferenciaRelatorioGrupo]


class ConferenciaResponse(BaseModel):
    numero_patrimonio: str
    conferido_em: datetime


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


class InventarioImportErro(BaseModel):
    linha: int
    mensagem: str


class InventarioImportResponse(BaseModel):
    novos: int
    atualizados: int
    inalterados: int
    erros: List[InventarioImportErro]
