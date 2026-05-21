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
    submissions_group_plus_lbl = submission_group + ['standardLabel']
    grouped = df.groupby(submission_group)
    signed_labels = {"Gross Profit", "Operating Income", "Pre-tax Income", "Net Income", "Retained Earnings", "Operating Cash Flow"}
    label_keys = ['standardLabel', 'standardLabelID']
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
        merged = merged[(
            merged.groupby(label_keys)['descendant'].transform('count') ==
            merged['conceptsPerStandardLabel']) & 
            (merged.groupby(label_keys)['absoluteDepth'].transform('nunique') == 1)
        ] #count of available components is the same as count of componets in the sample and they are at the same hierarchy depth.
        merged = merged.groupby(
        label_keys + ['confidenceScore', 'conceptsPerStandardLabel', 'absoluteDepth'],
            as_index=False
        )['value'].sum()
        merged = merged[
            merged.groupby('standardLabel')['confidenceScore'].transform('max') ==
            merged['confidenceScore']
        ].reset_index(drop=True)  #select sample standard concepts with highest confidence score
        merged = merged[ #select sample standard concepts with highest number of componentes available.
            merged.groupby('standardLabel')['conceptsPerStandardLabel'].transform('max') ==
            merged['conceptsPerStandardLabel']
        ].reset_index(drop=True)
        
        merged = merged[ #select standard concept with min hierarchy depth
            merged.groupby('standardLabel')['absoluteDepth'].transform('min') ==
            merged['absoluteDepth']
        ].reset_index(drop=True)
        merged = merged.loc[merged.groupby('standardLabel')['value'].idxmax()].copy()
        
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


