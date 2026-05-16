import json
import os
import time
import anthropic
from pathlib import Path
from dotenv import load_dotenv
import duckdb as ddb
from filing_to_yaml import filing_to_yaml
import pandas as pd
from utilities import load_query

load_dotenv()
CLAUDE_API_KEY = os.getenv("CLAUDE_API_KEY")


def build_system_prompt(line_items_path: str = None) -> str:
    base_file_dir = Path(__file__).resolve().parent
    line_items_path = line_items_path or os.path.join(base_file_dir, "standard_line_items.json")

    with open(line_items_path) as f:
        line_items = json.load(f)

    lines = [
        "You are a financial concept mapper. Given a financial statement hierarchy from an SEC "
        "filing in plain-text format, identify which XBRL concepts correspond to standard "
        "financial line items listed below.",
        "",
        "The hierarchy uses indentation to show parent-child relationships. A `+` prefix on a "
        "concept means it adds to its parent; a `-` prefix means it subtracts from its parent.",
        "",
        "## Standard Line Items",
    ]

    for item in line_items:
        stmt_str = "/".join(item["statement"]) if isinstance(item["statement"], list) else item["statement"]
        lines.append(f"\n- label: {item['standard_label']} | statement: {stmt_str}")
        lines.append(f"  {item['semantic_description']}")

    lines += [
        "",
        "## Output Format",
        "Return a JSON array. Each element maps one standard label and must have exactly these fields:",
        "{",
        '  "standard_label": "exact label from Standard Line Items",',
        '  "statement": "IncomeStatement" | "BalanceSheet" | "StatementOfCashFlows",',
        '  "concepts": [{"concept": "exact concept name from the filing", "sign": "+" | "-"}],',
        '  "confidence": "high" | "medium" | "low"',
        "}",
        "",
        "Mapping rules:",
        "- If a single concept directly represents the label, map it with sign \"+\".",
        "- If multiple concepts together make up the label (e.g. D&A split into separate "
        "depreciation and amortization lines, or operating expenses broken into R&D and SG&A), "
        "list all concepts with the sign to sum them to the label total (almost always \"+\"; "
        "use \"-\" only if a concept reduces the total).",
        "- Use the `+`/`-` prefixes in the hierarchy to understand how concepts relate to their "
        "parents, then determine the correct combining sign for the standard label.",
        "- Only include labels that can be identified in the filing. Skip the rest."
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
        max_tokens=50000,
        system=[{
            "type": "text",
            "text": system_prompt,
            "cache_control": {"type": "ephemeral"},
        }],
        messages=[{
            "role": "user",
            "content": f"Map the following filing:\n\n{yaml_str}",
        }]
    )

    return extract_json(response.content[0].text)


def build_batch_requests(filings_df, conn, system_prompt) -> tuple[list, dict]:
    requests = []
    metadata = {}  # custom_id -> (cik, accessionNumber, prefix)

    group_cols = ["prefix", "cik", "accessionNumber", "form", "endDate", "units"]
    for i, (group_key, _) in enumerate(filings_df.groupby(group_cols)):
        prefix, cik, accessionNumber, form, endDate, units = group_key
        yaml_str = filing_to_yaml(conn, 'FetchSubmissionsMainStatement', prefix, cik, accessionNumber, form, endDate, units)
        custom_id = str(i)
        metadata[custom_id] = (cik, accessionNumber, prefix, form, endDate, units)

        requests.append({
            "custom_id": custom_id,
            "params": {
                "model": "claude-sonnet-4-6",
                "max_tokens": 50000,
                "system": [{
                    "type": "text",
                    "text": system_prompt,
                    "cache_control": {"type": "ephemeral"},
                }],
                "messages": [{
                    "role": "user",
                    "content": f"Map the following filing:\n\n{yaml_str}",
                }],
            },
        })

    return requests, metadata


def poll_batch(batch):
    while batch.processing_status == "in_progress":
        time.sleep(60)
        batch = client.messages.batches.retrieve(batch.id)
        print(f"Batch {batch.id}: {batch.processing_status} "
              f"({batch.request_counts.succeeded} succeeded, "
              f"{batch.request_counts.errored} errored, "
              f"{batch.request_counts.processing} processing)")
    return batch


def batch_results_to_df(batch, metadata) -> pd.DataFrame:
    rows = []
    for result in client.messages.batches.results(batch.id):
        if result.result.type != "succeeded":
            print(f"Request {result.custom_id} failed: {result.result.type}")
            continue

        cik, accessionNumber, prefix, form, endDate, units = metadata[result.custom_id]
        try:
            mappings = extract_json(result.result.message.content[0].text)
        except Exception as e:
            print(f"Failed to parse response for {result.custom_id}: {e}")
            continue

        for item in mappings:
            for concept_entry in item.get("concepts", []):
                rows.append({
                    "cik": cik,
                    "accessionNumber": accessionNumber,
                    "prefix": prefix,
                    "form": form,
                    "endDate": endDate,
                    "units": units,
                    "standardLabel": item["standard_label"],
                    "keyStatementRole": item["statement"],
                    "conceptName": concept_entry["concept"],
                    "sign": concept_entry["sign"],
                    "confidenceLevel": item["confidence"],
                })

    return pd.DataFrame(rows)


if __name__ == "__main__":
    load_dotenv()

    PROJECT_ROOT_PARENT = Path(
        Path(__file__).resolve().parent.parent or
        Path(os.getenv("PROJECT_ROOT")).resolve().parent
    )

    db_path = os.path.join(PROJECT_ROOT_PARENT, "Data", "secFilingsDb.duckdb")
    conn = ddb.connect(db_path)
    system_prompt = build_system_prompt()
    filings_df = conn.execute(load_query('FilingsForClaude')).fetch_df()  # limit for testing; remove slicing for full run

    if filings_df.empty:
        print("No new filings to process.")
    else:
        print(f"Building batch for {len(filings_df)} filings...")
        requests, metadata = build_batch_requests(filings_df, conn, system_prompt)

        batch = client.messages.batches.create(requests=requests)
        print(f"Batch submitted: {batch.id}")
        batch = poll_batch(batch)

        df = batch_results_to_df(batch, metadata)
        if df.empty:
            print("No results to insert.")
        else:
            conn.register("results_df", df)
            cols = ", ".join(df.columns)                                                                  
            conn.execute(f"INSERT INTO standardizedConcepts ({cols}) SELECT {cols} FROM results_df") 
            print(f"Inserted {len(df)} rows into standardizedConcepts")
