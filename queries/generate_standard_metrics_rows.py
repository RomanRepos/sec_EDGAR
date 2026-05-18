import pandas as pd
import duckdb as ddb
from utilities import load_query
from dotenv import load_dotenv
from pathlib import Path
import os

if __name__ == "__main__":
    load_dotenv()
    PROJECT_ROOT_PARENT = Path(
        Path(__file__).resolve().parent.parent or
        Path(os.getenv("PROJECT_ROOT")).resolve().parent
    )

    db_path = os.path.join(PROJECT_ROOT_PARENT, "Data", "secFilingsDb.duckdb")

    conn = ddb.connect(db_path)

    df = conn.execute(load_query('etchSubmissionsMainStatement')).fetch_df()

    grouped = df.groupby(['cik', 'accessionNumber', 'form', 'endDate'])

    for (cik, accession_number, form, end_date), group in grouped:
        standard_labels_in_group = set(group['standardLabel'])

        for standard_label in standard_labels_in_group:
            standard_lable_rows = group[group['standardLabel'] == standard_label]
            min_depth = standard_lable_rows['absoluteDepth'].min()
            value = standard_label_rows_top = standard_lable_rows[standard_lable_rows['absoluteDepth']==min_depth]['value'].abs().sum()
            print(standard_label, value)


