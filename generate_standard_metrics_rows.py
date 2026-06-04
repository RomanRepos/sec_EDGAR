import pandas as pd
import duckdb as ddb
from utilities import load_query
from dotenv import load_dotenv
from pathlib import Path
import os
from tqdm import tqdm


def generate_standard_metrics_rows(conn, compute_query_name: str):
    conn.execute('''SET temp_directory = '/home/roman/temp_duckDB';
            SET threads = 1;
            SET memory_limit = '24GB';
            SET preserve_insertion_order = false;
            SET max_temp_directory_size = '280GB';
''')
    
    conn.execute(load_query('CreateStandardMetricsTbl'))

    submission_group = ['prefix', 'cik', 'accessionNumber', 'form', 'endDate', 'units']

    standard_labels = (
        conn.execute('''SELECT DISTINCT standardLabel FROM standardizedConcepts 
                     WHERE standardLabel NOT IN ('Gross Profit', 'Operating Expenses')
                     ORDER BY standardLabel DESC''')
        .df()['standardLabel']
        .tolist()
    )

    query = load_query(compute_query_name)
    long_results = []

    # Process one label at a time so each DuckDB query operates on ~1/N of the data,
    # keeping memory within bounds. All heavy computation (Jaccard, filtering,
    # aggregation, sign rules) stays inside DuckDB; Python only receives the final
    # one-row-per-submission result per label.
    for lbl in tqdm(standard_labels, desc="Computing metrics", unit="label"):
        df = conn.execute(query, [lbl]).df()
        if not df.empty:
            long_results.append(df)

    if not long_results:
        conn.execute("checkpoint;")
        return

    long_df = pd.concat(long_results, ignore_index=True)

    result = long_df.pivot_table(
        index=submission_group,
        columns='standardLabel',
        values='value',
        aggfunc='first'
    ).reset_index()
    result.columns.name = None

    conn.register("_metrics_result", result)
    conn.execute("INSERT INTO standardMetrics BY NAME SELECT * FROM _metrics_result")
    conn.unregister("_metrics_result")
    conn.execute("checkpoint;")


if __name__ == "__main__":
    load_dotenv()
    PROJECT_ROOT_PARENT = Path(
        Path(__file__).resolve().parent.parent or
        Path(os.getenv("PROJECT_ROOT")).resolve().parent
    )

    db_path = os.path.join(PROJECT_ROOT_PARENT, "Data", "secFilingsDb.duckdb")

    conn = ddb.connect(db_path)
    
    generate_standard_metrics_rows(conn, 'ComputeStandardMetrics')
    conn.execute(load_query('AddSharesColumnsToStandardMetrics'))
    conn.close()


