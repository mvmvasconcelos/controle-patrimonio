"""
Configuração do banco de dados SQLite
"""
from sqlalchemy import create_engine, text
from sqlalchemy.orm import declarative_base, sessionmaker
from sqlalchemy.pool import StaticPool
from fastapi import Request
import os

# Caminho para o banco de dados SQLite
DATABASE_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data")
os.makedirs(DATABASE_DIR, exist_ok=True)

SQLALCHEMY_DATABASE_URL = os.getenv(
    "DATABASE_URL",
    f"sqlite:///{os.path.join(DATABASE_DIR, 'patrimonio.db')}",
)


def create_database_engine(database_url: str):
    kwargs = {}
    if database_url.startswith("sqlite"):
        kwargs["connect_args"] = {"check_same_thread": False}
        if database_url in ("sqlite://", "sqlite:///:memory:"):
            kwargs["poolclass"] = StaticPool

    database_engine = create_engine(database_url, **kwargs)
    if database_url.startswith("sqlite"):
        with database_engine.connect() as connection:
            connection.execute(text("PRAGMA encoding = 'UTF-8'"))
            connection.commit()
    return database_engine


engine = create_database_engine(SQLALCHEMY_DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db(request: Request):
    db = request.app.state.session_factory()
    try:
        yield db
    finally:
        db.close()
