#!/usr/bin/env python3
"""
Script de importação de dados do SUAP (CSV) para o banco SQLite
"""
import sys
import os
import argparse
import pandas as pd
from pathlib import Path

# Adicionar diretório pai ao path para importar módulos do app
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.database import SessionLocal, engine
from app.models import Base, Patrimonio


def validate_csv(df: pd.DataFrame) -> tuple[bool, str]:
    """
    Validar estrutura do CSV
    Retorna (válido, mensagem)
    """
    # Mapeamento de colunas do SUAP para nosso modelo
    # Aceita tanto o formato padronizado quanto o formato do SUAP
    suap_columns = ['NUMERO', 'DESCRICAO', 'SALA', 'CARGA ATUAL', 'STATUS']
    standard_columns = ['numero_patrimonio', 'descricao', 'sala', 'responsavel', 'situacao']
    
    # Verificar se é CSV do SUAP (colunas em maiúsculas)
    has_suap_format = all(col in df.columns for col in suap_columns)
    has_standard_format = all(col in df.columns for col in standard_columns)
    
    if not (has_suap_format or has_standard_format):
        missing = []
        if not has_suap_format:
            missing.append(f"Formato SUAP: {', '.join(suap_columns)}")
        if not has_standard_format:
            missing.append(f"Formato padrão: {', '.join(standard_columns)}")
        return False, f"Colunas obrigatórias ausentes. Formatos aceitos:\n{chr(10).join(missing)}"
    
    if df.empty:
        return False, "Arquivo CSV está vazio"
    
    return True, "Validação OK"


def clean_data(df: pd.DataFrame) -> pd.DataFrame:
    """Limpar e normalizar dados do DataFrame"""
    
    # Mapear colunas do SUAP para nosso formato padrão se necessário
    column_mapping = {
        'NUMERO': 'numero_patrimonio',
        'DESCRICAO': 'descricao',
        'SALA': 'sala',
        'CARGA ATUAL': 'responsavel',
        'STATUS': 'situacao',
        'ESTADO DE CONSERVAÇÃO': 'observacoes'
    }
    
    # Renomear colunas se estiver no formato SUAP
    if 'NUMERO' in df.columns:
        df = df.rename(columns=column_mapping)
        print("📋 Formato SUAP detectado - colunas mapeadas")
    
    # Remover espaços em branco extras
    for col in df.columns:
        if df[col].dtype == 'object':
            df[col] = df[col].str.strip()
    
    # Converter numero_patrimonio para string
    df['numero_patrimonio'] = df['numero_patrimonio'].astype(str)
    
    # Preencher valores nulos em colunas opcionais
    if 'observacoes' in df.columns:
        df['observacoes'] = df['observacoes'].fillna('')
    else:
        df['observacoes'] = ''
    
    if 'foto_url' not in df.columns:
        df['foto_url'] = None
    
    # Remover duplicados baseado em numero_patrimonio
    initial_count = len(df)
    df = df.drop_duplicates(subset=['numero_patrimonio'], keep='first')
    duplicates_removed = initial_count - len(df)
    
    if duplicates_removed > 0:
        print(f"⚠️  Removidos {duplicates_removed} registros duplicados no CSV")
    
    return df


def import_csv(file_path: str, clear_db: bool = False, dry_run: bool = False):
    """
    Importar dados do CSV para o banco de dados
    """
    print("=" * 50)
    print("=== Importação de Dados do SUAP ===")
    print("=" * 50)
    print(f"Arquivo: {file_path}")
    
    # Verificar se arquivo existe
    if not os.path.exists(file_path):
        print(f"❌ Erro: Arquivo '{file_path}' não encontrado")
        return False
    
    # Ler CSV
    try:
        df = pd.read_csv(file_path, encoding='utf-8')
        print(f"Linhas lidas: {len(df)}")
    except Exception as e:
        print(f"❌ Erro ao ler CSV: {e}")
        return False
    
    # Validar estrutura
    valid, message = validate_csv(df)
    print(f"Validação: {message}")
    if not valid:
        return False
    
    # Limpar dados
    df = clean_data(df)
    print(f"Após limpeza: {len(df)} registros únicos")
    
    if dry_run:
        print("\n🔍 Modo DRY-RUN - Nenhum dado será inserido")
        print("\nPrimeiras 5 linhas:")
        print(df.head().to_string())
        return True
    
    # Criar tabelas se necessário
    Base.metadata.create_all(bind=engine)
    
    # Limpar banco se solicitado
    db = SessionLocal()
    try:
        if clear_db:
            print("\n⚠️  Limpando banco de dados...")
            db.query(Patrimonio).delete()
            db.commit()
            print("✓ Banco limpo")
        
        print("\nInserindo dados...")
        
        inserted = 0
        duplicates = 0
        errors = 0
        
        for index, row in df.iterrows():
            try:
                # Verificar se já existe
                existing = db.query(Patrimonio).filter(
                    Patrimonio.numero_patrimonio == row['numero_patrimonio']
                ).first()
                
                if existing:
                    duplicates += 1
                    continue
                
                # Criar novo registro
                patrimonio = Patrimonio(
                    numero_patrimonio=row['numero_patrimonio'],
                    descricao=row['descricao'],
                    sala=row['sala'],
                    responsavel=row['responsavel'],
                    situacao=row['situacao'],
                    observacoes=row.get('observacoes', ''),
                    foto_url=row.get('foto_url', None)
                )
                
                db.add(patrimonio)
                inserted += 1
                
                # Commit a cada 100 registros
                if inserted % 100 == 0:
                    db.commit()
                    print(f"  Processados: {inserted}/{len(df)}", end='\r')
            
            except Exception as e:
                errors += 1
                print(f"\n⚠️  Erro na linha {index + 2}: {e}")
        
        # Commit final
        db.commit()
        
        # Resultado
        print("\n" + "=" * 50)
        print("Resultado:")
        print(f"✓ Inseridos: {inserted}")
        if duplicates > 0:
            print(f"⚠ Duplicados ignorados: {duplicates}")
        if errors > 0:
            print(f"✗ Erros: {errors}")
        print("=" * 50)
        
        if errors == 0:
            print("\n✅ Importação concluída com sucesso!")
        else:
            print(f"\n⚠️  Importação concluída com {errors} erro(s)")
        
        return True
        
    except Exception as e:
        db.rollback()
        print(f"\n❌ Erro durante importação: {e}")
        return False
    finally:
        db.close()


def main():
    parser = argparse.ArgumentParser(
        description='Importar dados do SUAP (CSV) para o banco de dados SQLite'
    )
    parser.add_argument(
        '--file',
        type=str,
        required=True,
        help='Caminho para o arquivo CSV'
    )
    parser.add_argument(
        '--clear',
        action='store_true',
        help='Limpar banco de dados antes de importar'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Executar validação sem inserir dados'
    )
    
    args = parser.parse_args()
    
    success = import_csv(args.file, args.clear, args.dry_run)
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
