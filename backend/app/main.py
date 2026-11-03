"""
Aplicação FastAPI principal - Controle Patrimonial IFSUL
"""
import os
import secrets

from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import sessionmaker

from . import models
from .api import auth, endpoints
from .api.auth import hash_password, seed_admin
from .database import Base, SQLALCHEMY_DATABASE_URL, create_database_engine


def create_app(database_url: str | None = None) -> FastAPI:
    admin_username = os.getenv("ADMIN_USERNAME")
    admin_password = os.getenv("ADMIN_PASSWORD")
    jwt_secret = os.getenv("JWT_SECRET_KEY")
    provided_auth_config = any((admin_username, admin_password, jwt_secret))
    if provided_auth_config and not all((admin_username, admin_password, jwt_secret)):
        raise RuntimeError(
            "ADMIN_USERNAME, ADMIN_PASSWORD e JWT_SECRET_KEY devem ser configurados juntos"
        )
    if jwt_secret and len(jwt_secret) < 32:
        raise RuntimeError("JWT_SECRET_KEY deve conter pelo menos 32 caracteres")

    database_engine = create_database_engine(
        database_url or os.getenv("DATABASE_URL", SQLALCHEMY_DATABASE_URL)
    )
    Base.metadata.create_all(bind=database_engine)
    session_factory = sessionmaker(
        autocommit=False, autoflush=False, bind=database_engine
    )
    if admin_username and admin_password and jwt_secret:
        with session_factory() as db:
            seed_admin(db, admin_username, admin_password)

    app = FastAPI(
        title="Controle Patrimonial IFSUL - API",
        description="API REST para gerenciamento de patrimônio do IFSUL",
        version="1.0.0",
        docs_url=None,
        redoc_url=None,
        openapi_url=None,
    )
    app.state.engine = database_engine
    app.state.session_factory = session_factory
    app.state.jwt_secret = jwt_secret
    app.state.cookie_secure = os.getenv("COOKIE_SECURE", "").lower() == "true"
    app.state.dummy_password_hash = (
        hash_password(secrets.token_urlsafe(32)) if jwt_secret else None
    )

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
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Content-Type", "X-CSRF-Token"],
    )

    from fastapi.responses import JSONResponse

    @app.middleware("http")
    async def add_utf8_header(request, call_next):
        response = await call_next(request)
        if isinstance(response, JSONResponse):
            response.headers["Content-Type"] = "application/json; charset=utf-8"
        return response

    app.include_router(auth.router, prefix="/api/v1/auth", tags=["auth"])
    app.include_router(endpoints.router, prefix="/api/v1", tags=["patrimonio"])

    @app.get("/", dependencies=[Depends(auth.current_admin)])
    def root():
        return {
            "name": "Controle Patrimonial IFSUL - API",
            "version": "1.0.0",
            "status": "online",
        }

    @app.get("/health")
    def health_check():
        return {"status": "healthy"}

    return app


app = create_app()
