"""
Aplicação FastAPI principal - Controle Patrimonial IFSUL
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .database import engine, Base
from .api import endpoints

# Criar tabelas no banco de dados
Base.metadata.create_all(bind=engine)

# Criar aplicação FastAPI
app = FastAPI(
    title="Controle Patrimonial IFSUL - API",
    description="API REST para gerenciamento de patrimônio do IFSUL",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Configurar JSON encoder para UTF-8
from fastapi.responses import JSONResponse
from fastapi.encoders import jsonable_encoder

# Middleware para garantir UTF-8 nas respostas JSON
@app.middleware("http")
async def add_utf8_header(request, call_next):
    response = await call_next(request)
    if isinstance(response, JSONResponse):
        response.headers["Content-Type"] = "application/json; charset=utf-8"
    return response

# Configurar CORS para aceitar requisições do app Flutter
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:8090",
        "http://127.0.0.1:8090",
        "http://128.1.1.49:8090",
        "http://localhost:6090",
        "http://127.0.0.1:6090",
        "https://ifva.duckdns.org",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Incluir rotas da API
app.include_router(endpoints.router, prefix="/api/v1", tags=["patrimonio"])


@app.get("/")
def root():
    """Endpoint raiz - informações da API"""
    return {
        "name": "Controle Patrimonial IFSUL - API",
        "version": "1.0.0",
        "status": "online",
        "docs": "/docs"
    }


@app.get("/health")
def health_check():
    """Health check endpoint"""
    return {"status": "healthy"}
