import base64
import hashlib
import hmac
import json
import secrets
import time

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from .. import models
from ..database import get_db

SESSION_COOKIE = "patrimonio_session"
CSRF_COOKIE = "patrimonio_csrf"
SESSION_SECONDS = 30 * 24 * 60 * 60
PASSWORD_HASH_ITERATIONS = 600_000
router = APIRouter()


class LoginRequest(BaseModel):
    username: str
    password: str


def hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac(
        "sha256", password.encode(), salt, PASSWORD_HASH_ITERATIONS
    )
    return "$".join(
        (
            "pbkdf2_sha256",
            str(PASSWORD_HASH_ITERATIONS),
            base64.urlsafe_b64encode(salt).decode(),
            base64.urlsafe_b64encode(digest).decode(),
        )
    )


def verify_password(password: str, password_hash: str) -> bool:
    try:
        algorithm, iterations, encoded_salt, encoded_digest = password_hash.split("$")
        if algorithm != "pbkdf2_sha256":
            return False
        salt = base64.urlsafe_b64decode(encoded_salt)
        expected = base64.urlsafe_b64decode(encoded_digest)
        actual = hashlib.pbkdf2_hmac(
            "sha256", password.encode(), salt, int(iterations)
        )
        return hmac.compare_digest(actual, expected)
    except (ValueError, TypeError):
        return False


def seed_admin(db: Session, username: str, password: str) -> None:
    if db.query(models.Usuario).count() == 0:
        db.add(
            models.Usuario(
                username=username,
                password_hash=hash_password(password),
            )
        )
        db.commit()


def _b64encode(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode()


def _b64decode(value: str) -> bytes:
    return base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))


def create_session_token(username: str, secret: str, now: int | None = None) -> str:
    issued_at = int(time.time()) if now is None else now
    header = _b64encode(b'{"alg":"HS256","typ":"JWT"}')
    payload = _b64encode(
        json.dumps(
            {
                "sub": username,
                "role": "administrador",
                "iat": issued_at,
                "exp": issued_at + SESSION_SECONDS,
            },
            separators=(",", ":"),
        ).encode()
    )
    signing_input = f"{header}.{payload}".encode()
    signature = hmac.new(secret.encode(), signing_input, hashlib.sha256).digest()
    return f"{header}.{payload}.{_b64encode(signature)}"


def decode_session_token(token: str, secret: str) -> dict:
    try:
        encoded_header, encoded_payload, encoded_signature = token.split(".")
        header = json.loads(_b64decode(encoded_header))
        payload = json.loads(_b64decode(encoded_payload))
        if header != {"alg": "HS256", "typ": "JWT"}:
            raise ValueError("Unsupported token header")
        signing_input = f"{encoded_header}.{encoded_payload}".encode()
        expected = hmac.new(secret.encode(), signing_input, hashlib.sha256).digest()
        if not hmac.compare_digest(_b64decode(encoded_signature), expected):
            raise ValueError("Invalid token signature")
        if (
            not isinstance(payload.get("exp"), int)
            or payload["exp"] <= int(time.time())
            or not isinstance(payload.get("sub"), str)
            or payload.get("role") != "administrador"
        ):
            raise ValueError("Invalid token claims")
        return payload
    except (ValueError, TypeError, KeyError, json.JSONDecodeError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Autenticação necessária",
            headers={"WWW-Authenticate": "Bearer"},
        )


def _csrf_signature(session_token: str, nonce: str, secret: str) -> str:
    return _b64encode(
        hmac.new(
            secret.encode(),
            f"{session_token}.{nonce}".encode(),
            hashlib.sha256,
        ).digest()
    )


def create_csrf_token(session_token: str, secret: str) -> str:
    nonce = secrets.token_urlsafe(32)
    return f"{nonce}.{_csrf_signature(session_token, nonce, secret)}"


def verify_csrf_token(token: str, session_token: str, secret: str) -> bool:
    try:
        nonce, signature = token.split(".", 1)
        return hmac.compare_digest(
            signature, _csrf_signature(session_token, nonce, secret)
        )
    except ValueError:
        return False


def current_admin(request: Request, db: Session = Depends(get_db)) -> models.Usuario:
    secret = request.app.state.jwt_secret
    if not secret:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Autenticação não configurada",
        )
    token = request.cookies.get(SESSION_COOKIE)
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Autenticação necessária",
            headers={"WWW-Authenticate": "Bearer"},
        )
    payload = decode_session_token(token, secret)
    user = (
        db.query(models.Usuario)
        .filter(models.Usuario.username == payload["sub"])
        .first()
    )
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Autenticação necessária",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user


def require_csrf(
    request: Request,
    _user: models.Usuario = Depends(current_admin),
) -> None:
    if request.method in {"GET", "HEAD", "OPTIONS"}:
        return
    secret = request.app.state.jwt_secret
    session_token = request.cookies.get(SESSION_COOKIE, "")
    cookie_token = request.cookies.get(CSRF_COOKIE, "")
    header_token = request.headers.get("X-CSRF-Token", "")
    if (
        not cookie_token
        or not hmac.compare_digest(cookie_token, header_token)
        or not verify_csrf_token(cookie_token, session_token, secret)
    ):
        raise HTTPException(status_code=403, detail="Verificação CSRF inválida")


@router.post("/login")
def login(
    credentials: LoginRequest,
    request: Request,
    response: Response,
    db: Session = Depends(get_db),
):
    secret = request.app.state.jwt_secret
    if not secret:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Autenticação não configurada",
        )

    user = (
        db.query(models.Usuario)
        .filter(models.Usuario.username == credentials.username)
        .first()
    )
    valid_password = verify_password(
        credentials.password,
        user.password_hash if user else request.app.state.dummy_password_hash,
    )
    if not user or not valid_password:
        raise HTTPException(status_code=401, detail="Credenciais inválidas")

    session_token = create_session_token(user.username, secret)
    csrf_token = create_csrf_token(session_token, secret)
    cookie_secure = request.app.state.cookie_secure or request.url.scheme == "https"
    response.set_cookie(
        SESSION_COOKIE,
        session_token,
        max_age=SESSION_SECONDS,
        httponly=True,
        secure=cookie_secure,
        samesite="lax",
        path="/",
    )
    response.set_cookie(
        CSRF_COOKIE,
        csrf_token,
        max_age=SESSION_SECONDS,
        httponly=False,
        secure=cookie_secure,
        samesite="lax",
        path="/",
    )
    return {
        "username": user.username,
        "role": "administrador",
        "csrf_token": csrf_token,
    }


@router.get("/me")
def get_session(
    request: Request,
    user: models.Usuario = Depends(current_admin),
):
    session_token = request.cookies.get(SESSION_COOKIE, "")
    csrf_token = request.cookies.get(CSRF_COOKIE, "")
    if not verify_csrf_token(csrf_token, session_token, request.app.state.jwt_secret):
        raise HTTPException(status_code=401, detail="Sessão inválida")
    return {
        "username": user.username,
        "role": "administrador",
        "csrf_token": csrf_token,
    }


@router.post(
    "/logout",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(current_admin), Depends(require_csrf)],
)
def logout(request: Request, response: Response):
    cookie_secure = request.app.state.cookie_secure or request.url.scheme == "https"
    response.delete_cookie(
        SESSION_COOKIE, path="/", secure=cookie_secure, httponly=True, samesite="lax"
    )
    response.delete_cookie(
        CSRF_COOKIE,
        path="/",
        secure=cookie_secure,
        httponly=False,
        samesite="lax",
    )
    response.status_code = status.HTTP_204_NO_CONTENT
    return response
