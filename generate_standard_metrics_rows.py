import duckdb as ddb
from utilities import load_query
from dotenv import load_dotenv
from pathlib import Path
import os


def generate_standard_metrics_rows(conn, primary_submissions_query_name: str):
    conn.execute(load_query('CreateStandardMetricsTbl'))

    submission_group = ['prefix', 'cik', 'accessionNumber', 'form', 'endDate', 'units']
    signed_labels = {"Gross Profit", "Operating Income", "Pre-tax Income", "Net Income", "Retained Earnings", "Operating Cash Flow"}
    label_keys = ['standardLabel', 'standardLabelID', 'conceptsPerStandardLabel']
    _exempt_from_min_concepts = {
        'Intangible Assets', 'Total Debt', 'Cash and Cash Equivalents',
        'Interest Income', 'Interest Expense', 'Stock-based Compensation',
        'Operating Expenses', 'Research and Development Expenses', 'Total Current Assets',
        'Total Current Liabilities', 'Accounts Payable', 'Current Portion of Long-term Debt',
        'Depreciation and Amortization', 'Selling, General and Administrative Expenses', 'Long-term Debt',
        'Capital Expenditures', 'Accounts Receivable', 'Short-term Borrowings', 'Dividends Paid', 'Inventory',
        'Property, Plant and Equipment, Net'
    }

    def _jaccard(a: set, b: set) -> float:
        union = a | b
        return len(a & b) / len(union) if union else 0.0

    all_group_keys = submission_group + label_keys
    sub_lbl_keys = submission_group + ['standardLabel']

    print("Fetching all financial data...")
    df = conn.execute(load_query(primary_submissions_query_name)).df()
    if df.empty:
        conn.execute("checkpoint;")
        return

    # --- Step 1: Jaccard similarity — pick best standardLabelID per (submission + standardLabel) ---
    # Compute set of conceptNames for each unique (submission + label_keys) combo
    concept_sets = (
        df.groupby(all_group_keys)['conceptName']
        .agg(set)
        .reset_index(name='conceptName_set')
    )
    # Parse standardLabelID pipe-delimited strings once, deduplicated
    id_sets = (
        df[['standardLabelID']].drop_duplicates()
        .dropna(subset=['standardLabelID'])
        .assign(standardLabelID_set=lambda x: x['standardLabelID'].str.split('|').apply(set))
    )
    concept_sets = concept_sets.merge(id_sets, on='standardLabelID', how='left')
    concept_sets['standardLabelID_set'] = concept_sets['standardLabelID_set'].apply(
        lambda x: x if isinstance(x, set) else set()
    )
    concept_sets['similarity'] = concept_sets.apply(
        lambda r: _jaccard(r['conceptName_set'], r['standardLabelID_set']), axis=1
    )

    sim_max = concept_sets.groupby(sub_lbl_keys)['similarity'].transform('max')
    best_ids = concept_sets.loc[concept_sets['similarity'] == sim_max, all_group_keys].drop_duplicates()

    # --- Step 2: Filter to best IDs and sum values per (submission + label_keys) ---
    df = df.merge(best_ids, on=all_group_keys, how='inner')
    df = df.groupby(all_group_keys, as_index=False)['value'].sum()

    # --- Step 3: Filter by conceptsPerStandardLabel (max for exempt labels, min otherwise) ---
    exempt_mask = df['standardLabel'].isin(_exempt_from_min_concepts)
    max_cps = df.groupby(sub_lbl_keys)['conceptsPerStandardLabel'].transform('max')
    min_cps = df.groupby(sub_lbl_keys)['conceptsPerStandardLabel'].transform('min')
    df = df[
        (exempt_mask & (df['conceptsPerStandardLabel'] == max_cps)) |
        (~exempt_mask & (df['conceptsPerStandardLabel'] == min_cps))
    ].reset_index(drop=True)

    # --- Step 4: Keep the row with the largest absolute value per (submission + standardLabel) ---
    df['_abs_value'] = df['value'].abs()
    idx = df.groupby(sub_lbl_keys)['_abs_value'].idxmax()
    df = df.loc[idx].drop(columns=['_abs_value']).reset_index(drop=True)

    # --- Step 5: Apply sign rules ---
    not_signed = ~df['standardLabel'].isin(signed_labels)
    df.loc[not_signed, 'value'] = df.loc[not_signed, 'value'].abs()

    # --- Step 6: Pivot to wide format and write ---
    result = df.pivot_table(
        index=submission_group,
        columns='standardLabel',
        values='value',
        aggfunc='first'
    ).reset_index()
    result.columns.name = None

    conn.append("standardMetrics", result)
    conn.execute("checkpoint;")


if __name__ == "__main__":
    load_dotenv()
    PROJECT_ROOT_PARENT = Path(
        Path(__file__).resolve().parent.parent or
        Path(os.getenv("PROJECT_ROOT")).resolve().parent
    )

    db_path = os.path.join(PROJECT_ROOT_PARENT, "Data", "secFilingsDb.duckdb")

    conn = ddb.connect(db_path)
    
    generate_standard_metrics_rows(conn, 'FetchFinancialDataAndStandardLabels')
    conn.close()


