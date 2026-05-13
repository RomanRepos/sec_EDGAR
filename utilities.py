from pathlib import Path
def load_query(name: str) -> str:
    queries_dir = Path(__file__).resolve().parent / "queries"
    return (queries_dir / f"{name}.sql").read_text()