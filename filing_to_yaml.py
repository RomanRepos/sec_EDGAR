import duckdb as ddb
import os
from collections import defaultdict
from pathlib import Path
from dotenv import load_dotenv
from utilities import load_query

def rows_to_tree(rows):
    children_of = defaultdict(list)
    root_concepts = set()

    for stmt, ancestor, descendant, weight, depth in rows:
        if stmt is None:
            continue
        if depth == 0:
            root_concepts.add((stmt, ancestor))
        else:
            children_of[(stmt, ancestor)].append((descendant, weight))

    def build_node(stmt, concept, weight=1):
        name = f"- {concept}" if weight < 0 else f"+ {concept}"
        kids = children_of.get((stmt, concept), [])
        if not kids:
            return name
        return {name: [build_node(stmt, child, w) for child, w in kids]}

    result = {}
    for stmt, root in sorted(root_concepts):
        children_list = [build_node(stmt, child, w) for child, w in children_of.get((stmt, root), [])]
        result.setdefault(stmt, {})[root] = children_list
    return result


def _render(name, children, indent, lines):
    pad = "  " * indent
    lines.append(f"{pad}{name}:")
    for child in children:
        if isinstance(child, str):
            lines.append(f"{pad}  {child}")
        else:
            child_name, child_children = next(iter(child.items()))
            _render(child_name, child_children, indent + 1, lines)


def tree_to_text(tree):
    lines = []
    for stmt, roots in sorted(tree.items()):
        lines.append(f"{stmt}:")
        for root, children in roots.items():
            _render(root, children, 1, lines)
    return "\n".join(lines)


def filing_to_yaml(conn, query_name: str, prefix: str, cik: int, accession_number: str, form: str, end_date: str, units: str) -> str:
    
    query_var = load_query(query_name)
    rows = conn.execute(query_var, [prefix, cik, accession_number, form, end_date, units]).fetchall()
    

    tree = rows_to_tree(rows)
    return tree_to_text(tree)


if __name__ == "__main__":
#8063	0000008063-20-000042	10-Q	2020-06-27
    load_dotenv()
    PROJECT_ROOT_PARENT = Path(
        Path(__file__).resolve().parent.parent or 
        Path(os.getenv("PROJECT_ROOT")).resolve().parent
    )

    db_path = os.path.join(PROJECT_ROOT_PARENT, "Data", "secFilingsDb.duckdb")

    conn = ddb.connect(db_path)
    CIK = 8063
    ACCESSION = "0000008063-20-000042"
    FORM = "10-Q"
    END_DATE = "2020-06-27"
    PREFIX = "us-gaap"
    UNITS = "USD"
    yaml_str = filing_to_yaml(conn, 'FetchSubmissionsMainStatement', PREFIX, CIK, ACCESSION, FORM, END_DATE, UNITS)
    print(yaml_str)
