import json
import os
import anthropic
from pathlib import Path
from dotenv import load_dotenv
import duckdb as ddb
from filing_to_yaml import filing_to_yaml
import pandas as pd

load_dotenv()
CLAUDE_API_KEY = os.getenv("CLAUDE_API_KEY")
def build_system_prompt(
    metrics_path: str = None,
    line_items_path: str = None,
) -> str:
    base_file_dir =Path(__file__).resolve().parent
    
    metrics_path = metrics_path or os.path.join(base_file_dir, "financial_metrics.json")
    line_items_path = line_items_path or os.path.join(base_file_dir, "standard_line_items.json")

    with open(metrics_path) as f:
        metrics = json.load(f)
    with open(line_items_path) as f:
        line_items = json.load(f)

    lines = [
        "You are a financial concept mapper. Given XBRL concepts from a SEC filing "
        "in YAML format, map each concept to a financial metric component and/or a "
        "standard line item label. Use only the definitions below — do not invent "
        "metrics or labels not listed here.",
        "",
        "## Metric Definitions",
    ]

    for m in metrics:
        lines.append(f"\n### {m['metric']}")
        lines.append(f"Formula: {m['formula']}")
        lines.append(f"Description: {m['semantic_description']}")
        lines.append("Components:")
        for c in m["components"]:
            lines.append(f"  - role: {c['role']} | statement: {c['statement']} | units: {c['units']}")
            lines.append(f"    {c['semantic_description']}")

    lines += ["", "## Standard Line Items"]
    for item in line_items:
        lines.append(f"\n- label: {item['standard_label']} | statement: {item['statement']}")
        lines.append(f"  {item['semantic_description']}")

    lines += [
        "",
        "## Output Format",
        "Return a JSON array. Each element maps one concept and must have exactly these fields:",
        "{",
        '  "concept": "exact concept name from the input",',
        '  "metric": "exact metric name from Metric Definitions, or null",',
        '  "component_role": "exact role from the metric component, or null",',
        '  "standard_label": "exact label from Standard Line Items, or null",',
        '  "confidence": "high" | "medium" | "low"',
        "}",
        "Only include concepts that map to at least one of metric or standard_label. "
        "Skip concepts that map to neither.",
    ]

    return "\n".join(lines)




client = anthropic.Anthropic(api_key=CLAUDE_API_KEY)


def extract_json(text: str) -> list[dict]:
    # Strip markdown code fences if present
    text = text.strip()
    if text.startswith("```"):
        text = text.split("```", 2)[1]
        if text.startswith("json"):
            text = text[4:]
        text = text.rsplit("```", 1)[0]
    return json.loads(text.strip())


def map_filing(yaml_str, system_prompt) -> list[dict]:
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=8192,
        system=[{
            "type": "text",
            "text": system_prompt,
            "cache_control": {"type": "ephemeral"},
        }],
        messages=[{
            "role": "user",
            "content": f"Map the following concepts:\n\n{yaml_str}",
        }]
    )

    return extract_json(response.content[0].text)

#for _, row in random_rows.iterrows():
        #cik = row["cik"]
        #accessionNumber = row["accessionNumber"]
        #prefix = row["prefix"]
        #form = row["form"]
        #endDate = row["endDate"]
        #print(prefix, cik, accessionNumber, form, endDate)
        #results = map_filing(filing_to_yaml(conn, prefix, cik, accessionNumber, form, endDate), system_prompt)
        #print(json.dumps(results, indent=2))

if __name__ == "__main__":
    load_dotenv()
    
    QUERY_FILINGS = """
    with topLevelParentsSum as (
SELECT fd.prefix, cth.cik, cth.accessionNumber, 
cth.linkRole, 
cth.keyStatementRole, s.form, fd.endDate, sum(fd.value) highestLevelParentsTotal 
from calculationTaxonomyHierarchy cth 
inner join financialData fd on
    fd.cik = cth.cik 
    --AND form ='10-K'
    AND fd.accessionNumber = cth.accessionNumber
    AND fd.name = cth.descendant
    AND cth.relativeDepth = 0
    AND cth.highestParent = TRUE
    and fd.prefix = ?
INNER JOIN submissions s 
        ON fd.cik = s.cik 
        --AND form ='10-K'
        AND fd.accessionNumber = s.accessionNumber
        AND s.reportDate = fd.endDate
GROUP BY
    fd.prefix, cth.cik, cth.accessionNumber, cth.linkRole, cth.keyStatementRole, s.form, fd.endDate
), 

firstLevelNodestSum as (
SELECT fd.prefix, cth.cik, cth.accessionNumber, cth.linkRole,  
cth.keyStatementRole, s.form, fd.endDate, sum(fd.value*cth.arcWeight) firstLevelNodesTotal 
from calculationTaxonomyHierarchy cth
inner join financialData fd on
    fd.cik = cth.cik 
    --AND form ='10-K'
    AND fd.accessionNumber = cth.accessionNumber
    AND fd.name = cth.descendant
    AND cth.relativeDepth = 1
    and fd.prefix = ?
INNER JOIN submissions s 
        ON fd.cik = s.cik 
        --AND form ='10-K'
        AND fd.accessionNumber = s.accessionNumber
        AND s.reportDate = fd.endDate
INNER JOIN calculationTaxonomyHierarchy ctht
        ON ctht.cik = cth.cik
        AND ctht."accessionNumber" = cth."accessionNumber"
        AND cth.ancestor = ctht.ancestor
        AND ctht."relativeDepth" = 0
        AND ctht.highestParent = TRUE
GROUP BY
    fd.prefix, cth.cik, cth.accessionNumber, cth.linkRole, cth.keyStatementRole, s.form, fd.endDate
)     


select tlp.prefix,tlp.cik, tlp.accessionNumber, tlp.form, tlp.endDate from topLevelParentsSum tlp
INNER JOIN firstLevelNodestSum fln 
on tlp.cik = fln.cik
and tlp.accessionNumber = fln.accessionNumber
and tlp.linkRole = fln.linkRole
and tlp.keyStatementRole = fln.keyStatementRole
and tlp.form = fln.form
and tlp.endDate = fln.endDate
and tlp.highestLevelParentsTotal = fln.firstLevelNodesTotal
WHERE tlp.keyStatementRole in ('BalanceSheet', 'IncomeStatement', 'StatementOfCashFlows')
GROUP BY tlp.prefix, tlp.cik, tlp.accessionNumber, tlp.form, tlp.endDate
HAVING count(*) = 3
ORDER BY tlp.prefix, tlp.cik, tlp.accessionNumber, tlp.form, tlp.endDate
;
""" 
    PROJECT_ROOT_PARENT = Path(
        Path(__file__).resolve().parent.parent or 
        Path(os.getenv("PROJECT_ROOT")).resolve().parent
    )

    db_path = os.path.join(PROJECT_ROOT_PARENT, "Data", "secFilingsDb.duckdb")
    conn = ddb.connect(db_path)
    system_prompt = build_system_prompt()
    filings_df = pd.DataFrame()
    for prefix in ["us-gaap", "ifrs-full"]:
        filings_df = pd.concat([filings_df, conn.execute(QUERY_FILINGS, [prefix, prefix]).fetchdf()], ignore_index=True)
    
    random_rows = filings_df.sample(2)

    for _, row in random_rows.iterrows():
        cik = row["cik"]
        accessionNumber = row["accessionNumber"]
        prefix = row["prefix"]
        form = row["form"]
        endDate = row["endDate"]
        print(prefix, cik, accessionNumber, form, endDate)
        results = map_filing(filing_to_yaml(conn, prefix, cik, accessionNumber, form, endDate), system_prompt)
        print(json.dumps(results, indent=2))
