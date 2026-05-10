import duckdb as ddb
import os
import yaml
from collections import defaultdict
from pathlib import Path
from dotenv import load_dotenv


def rows_to_tree(rows):
    concept_units = {}
    children_of = defaultdict(list)  # (statement, parent) -> [(child, weight)]
    root_concepts = set()            # (statement, concept) — depth=0, highestParent rows

    for stmt, ancestor, descendant, weight, depth, units in rows:
        if stmt is None:
            continue
        if units is not None:
            concept_units[descendant] = units
        if depth == 0:
            # ancestor == descendant here; marks the root of a subtree
            root_concepts.add((stmt, ancestor))
        else:
            children_of[(stmt, ancestor)].append((descendant, weight))

    def fmt_value(v):
        return int(v) if v is not None and v == int(v) else v

    def build_node(stmt, concept):
        node = {}
        unit = concept_units.get(concept)
        if unit is not None:
            node['units'] = unit
        kids = children_of.get((stmt, concept), [])
        if kids:
            components = []
            for child, w in kids:
                child_node = {
                    'concept': child,
                    'weight': '+1' if w > 0 else '-1',
                }
                child_unit = concept_units.get(child)
                if child_unit is not None:
                    child_node['units'] = child_unit
                # intermediate nodes: recurse to attach their children
                if children_of.get((stmt, child)):
                    child_node['components'] = build_node(stmt, child)['components']
                components.append(child_node)
            node['components'] = components
        return node

    result = {}
    for stmt, root in sorted(root_concepts):
        result.setdefault(stmt, {})[root] = build_node(stmt, root)
    return result


def filing_to_yaml(conn, prefix: str, cik: int, accession_number: str, form: str, end_date: str) -> str:
    
    query_var = """
SELECT  
    cth."keyStatementRole" AS financialStatement,
    cth."ancestor",
    cth.descendant,
    cth."arcWeight",
    cth.relativeDepth,
    fd.units
FROM
    financialData fd
    INNER JOIN submissions s
        ON fd.cik = s.cik
        AND fd.accessionNumber = s.accessionNumber
        AND s.reportDate = fd.endDate
    INNER JOIN calculationTaxonomyHierarchy cth
        ON cth.cik = fd.cik
        AND cth.accessionNumber = fd.accessionNumber
        AND fd.name = cth.descendant
    LEFT OUTER JOIN calculationTaxonomyHierarchy ctht
        ON ctht.cik = fd.cik
        AND ctht."accessionNumber" = fd."accessionNumber"
        AND cth.ancestor = ctht.ancestor
        AND ctht."relativeDepth" = 0
        AND ctht.highestParent = TRUE
WHERE
    fd.prefix = ?
    AND fd.cik = ?
    AND fd.accessionNumber = ?
    AND (cth."relativeDepth" = 1 OR (cth."relativeDepth" = 0 AND cth.highestParent = TRUE))
    AND s.form = ?
    AND fd.endDate = ?
    AND cth.relativeDepth <= 2
    and cth."keyStatementRole" IN ('BalanceSheet', 'IncomeStatement', 'StatementOfCashFlows')
    
ORDER BY
    cth.keyStatementRole,
    cth.ancestor,
    cth.arcWeight DESC
"""
    rows = conn.execute(query_var, [prefix, cik, accession_number, form, end_date]).fetchall()
    

    tree = rows_to_tree(rows)
    return yaml.dump(tree, default_flow_style=False, sort_keys=False, allow_unicode=True)


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

    yaml_str = filing_to_yaml(conn, PREFIX, CIK, ACCESSION, FORM, END_DATE)
    print(yaml_str)
