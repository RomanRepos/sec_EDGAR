import pandas as pd
import duckdb as ddb
from utilities import load_query
from dotenv import load_dotenv
from pathlib import Path
import os
from tqdm import tqdm


def fill_in_missing_concepts(conn, primary_submissions_query_name:str):
    conn.execute(load_query('CreateStandardMetricsTbl'))
    df = conn.execute(load_query(primary_submissions_query_name)).fetch_df()

    submission_group = ['rowid']
    #submissions_group_plus_lbl = submission_group + ['standardLabel']
    grouped = df.groupby(submission_group)
    signed_labels = {"Gross Profit", "Operating Income", "Pre-tax Income", "Net Income", "Retained Earnings", "Operating Cash Flow"}
    label_keys = ['standardLabel', 'standardLabelID', 'conceptsPerStandardLabel', 'confidenceScore', 'keyStatementRole']
    _exempt_from_min_concepts = {
            'Intangible Assets', 'Total Debt', 'Cash and Cash Equivalents',
            'Interest Income', 'Interest Expense', 'Stock-based Compensation',
            'Operating Expenses', 'Research and Development Expenses', 'Total Current Assets',
            'Total Current Liabilities', 'Accounts Payable', 'Current Portion of Long-term Debt',
            'Depreciation and Amortization', 'Selling, General and Administrative Expenses', 'Long-term Debt',
            'Capital Expenditures', 'Accounts Receivable', 'Short-term Borrowings', 'Dividends Paid', 'Inventory',
            'Property, Plant and Equipment, Net'
        }

    def _jaccard(a, b):
        union = a | b
        return len(a & b) / len(union) if union else 0.0

    for (rowid), group in tqdm(grouped, desc="Processing Submissions", unit="submission",
                     bar_format='{desc}: {percentage:.2f}% |{bar}| {n_fmt}/{total_fmt} [{elapsed}<{remaining}]'):

        
        # Per standardLabel, keep the standardLabelID whose concept set most closely matches the actual descendants
        label_id_sets = (
            group.groupby(label_keys)['conceptName']
            .apply(set)
            .reset_index(name='conceptName_set')
        )
        try:
            label_id_sets['standardLabelID_set'] = label_id_sets['standardLabelID'].apply(
                lambda s: set(s.split('|'))
            )
            label_id_sets['similarity'] = label_id_sets.apply(
                lambda r: _jaccard(r['conceptName_set'], r['standardLabelID_set']), axis=1
            )
        except:
            continue
        
        best_ids = label_id_sets[
            label_id_sets['similarity'] == label_id_sets.groupby('standardLabel')['similarity'].transform('max')
        ][label_keys]
        group = group.merge(best_ids, on=label_keys, how='inner')
        
        group = group.groupby(
        label_keys,
            as_index=False
        )['value'].sum()


        group = group[
            group.groupby('standardLabel')['confidenceScore'].transform('max') ==
            group['confidenceScore']
        ].reset_index(drop=True)

        group = group[ #Assign concept to a standard label with max number of components for lower level concepts and min number of components for top level concepts.
            (group['standardLabel'].isin(_exempt_from_min_concepts) &
             (group.groupby(label_keys)['conceptsPerStandardLabel'].transform('max') ==
              group['conceptsPerStandardLabel'])) |
            (~group['standardLabel'].isin(_exempt_from_min_concepts) &
             (group.groupby(label_keys)['conceptsPerStandardLabel'].transform('min') ==
              group['conceptsPerStandardLabel']))
        ].reset_index(drop=True)
        
        group = group.loc[group['value'].abs().groupby(group['standardLabel']).idxmax()].copy()
        
        group['value'] = group.apply(
            lambda r: r['value'] if r['standardLabel'] in signed_labels else abs(r['value']),
            axis=1
        )

        label_to_value = group.set_index('standardLabel')['value'].to_dict()

        conn.execute(f'''UPDATE standardMetrics SET "Depreciation and Amortization" = {label_to_value['Depreciation and Amortization']}
                    where rowid = {rowid[0]};''')

    conn.execute("checkpoint;")


if __name__ == "__main__":
    load_dotenv()
    PROJECT_ROOT_PARENT = Path(
        Path(__file__).resolve().parent.parent or
        Path(os.getenv("PROJECT_ROOT")).resolve().parent
    )

    db_path = os.path.join(PROJECT_ROOT_PARENT, "Data", "secFilingsDb.duckdb")

    conn = ddb.connect(db_path)
 
    fill_in_missing_concepts(conn, 'FetchMissingMetrics')

    conn.close()


