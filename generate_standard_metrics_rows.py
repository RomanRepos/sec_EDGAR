import pandas as pd
import duckdb as ddb
from utilities import load_query
from dotenv import load_dotenv
from pathlib import Path
import os
from tqdm import tqdm


def generate_standard_metrics_rows(conn, primary_submissions_query_name:str, standardized_concepts_query_name:str):
    conn.execute(load_query('CreateStandardMetricsTbl'))
    df = conn.execute(load_query(primary_submissions_query_name)).fetch_df()
    standard_labels = conn.execute("SELECT standard_label FROM standardLineItems").df()['standard_label'].tolist()

    standardized_concepts_df = conn.execute(load_query(standardized_concepts_query_name)).fetch_df()


    submission_group = ['prefix', 'cik', 'accessionNumber', 'form', 'endDate', 'units']
    #submissions_group_plus_lbl = submission_group + ['standardLabel']
    grouped = df.groupby(submission_group)
    signed_labels = {"Gross Profit", "Operating Income", "Pre-tax Income", "Net Income", "Retained Earnings", "Operating Cash Flow"}
    label_keys = ['standardLabel', 'standardLabelID', 'keyStatementRole']
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

    for (prefix, cik, accession_number, form, end_date, units), group in tqdm(grouped, desc="Processing Submissions", unit="submission",
                     bar_format='{desc}: {percentage:.2f}% |{bar}| {n_fmt}/{total_fmt} [{elapsed}<{remaining}]'):
        merged = pd.DataFrame()
        merged = group.merge(
            standardized_concepts_df,
            left_on=['descendant', 'keyStatementRole'],
            right_on=['conceptName', 'keyStatementRole'],
            how='inner'
        )

        #Next steps determine which concepts will be allocated to which standard metrics
        merged = merged[merged.groupby(label_keys)['absoluteDepth'].transform('nunique') == 1] # Available components per standardLabelID are at the same hierarchy depth.
        
        
        # Per standardLabel, keep the standardLabelID whose concept set most closely matches the actual descendants
        label_id_sets = (
            merged.groupby(label_keys)['descendant']
            .apply(set)
            .reset_index(name='descendant_set')
        )
        try:
            label_id_sets['standardLabelID_set'] = label_id_sets['standardLabelID'].apply(
                lambda s: set(s.split('|'))
            )
            label_id_sets['similarity'] = label_id_sets.apply(
                lambda r: _jaccard(r['descendant_set'], r['standardLabelID_set']), axis=1
            )
        except:
            continue
        
        best_ids = label_id_sets[
            label_id_sets['similarity'] == label_id_sets.groupby('standardLabel')['similarity'].transform('max')
        ][label_keys]
        merged = merged.merge(best_ids, on=label_keys, how='inner')
         
        merged = merged.groupby(
        label_keys + ['confidenceScore', 'conceptsPerStandardLabel', 'absoluteDepth'],
            as_index=False
        )['value'].sum()
       
        
        merged = merged[
            merged.groupby('standardLabel')['confidenceScore'].transform('max') ==
            merged['confidenceScore']
        ].reset_index(drop=True)  #select sample standard concepts with highest confidence score
       
        merged = merged[ #Assign concept to a standard label with max number of components for lower level concepts and min number of components for top level concepts.
            (merged['standardLabel'].isin(_exempt_from_min_concepts) &
             (merged.groupby(label_keys)['conceptsPerStandardLabel'].transform('max') ==
              merged['conceptsPerStandardLabel'])) |
            (~merged['standardLabel'].isin(_exempt_from_min_concepts) &
             (merged.groupby(label_keys)['conceptsPerStandardLabel'].transform('min') ==
              merged['conceptsPerStandardLabel']))
        ].reset_index(drop=True)
        
        #merged = merged[ #select standard concept with min hierarchy depth
            #merged.groupby('standardLabel')['absoluteDepth'].transform('min') ==
            #merged['absoluteDepth']
        #].reset_index(drop=True)
        merged = merged.loc[merged['value'].abs().groupby(merged['standardLabel']).idxmax()].copy()
        
        merged['value'] = merged.apply(
            lambda r: r['value'] if r['standardLabel'] in signed_labels else abs(r['value']),
            axis=1
        )

        label_to_value = merged.set_index('standardLabel')['value'].to_dict()

        row = {
            'prefix': prefix,
            'cik': cik,
            'accessionNumber': accession_number,
            'form': form,
            'endDate': end_date,
            'units': units,
            **{label: label_to_value.get(label) for label in standard_labels}
        }
        conn.append("standardMetrics", pd.DataFrame([row]))

    conn.execute("checkpoint;")


if __name__ == "__main__":
    load_dotenv()
    PROJECT_ROOT_PARENT = Path(
        Path(__file__).resolve().parent.parent or
        Path(os.getenv("PROJECT_ROOT")).resolve().parent
    )

    db_path = os.path.join(PROJECT_ROOT_PARENT, "Data", "secFilingsDb.duckdb")

    conn = ddb.connect(db_path)
    generate_standard_metrics_rows(conn, 'FetchPrimarySubmissions', 'FetchStandardizedConcepts')

    conn.close()


