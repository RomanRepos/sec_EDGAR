import pandas as pd
import duckdb as ddb
from utilities import load_query
from dotenv import load_dotenv
from pathlib import Path
import os
from tqdm import tqdm

def populate_optimal_sample_table(conn, query_name:str, concept_top_pct:float=0.8):
    print("Loading clean submissions from database...")
    df = conn.execute(load_query(query_name)).fetch_df()
    concept_counts = df["conceptName"].value_counts().sort_values(ascending=False)
    concept_counts.to_excel('/home/roman/Documents/EDGAR_Analytics/Analytics/ConceptCounts.xlsx')

   
    top_n = max(1, int(len(concept_counts) * concept_top_pct))
    top_concepts = set(concept_counts.iloc[:top_n].index)
    df = df[df["conceptName"].isin(top_concepts)]

    company_concepts = df.groupby(['prefix', 'cik', 'accessionNumber', 'form', 'endDate', 'units'])["conceptName"].agg(set).to_dict()

    covered = set()
    selected = []
    pbar = tqdm(total=len(top_concepts), desc="Generating Optimal Sample of Submissions", unit="concept",
                bar_format='{desc}: {percentage:.2f}% |{bar}| {n_fmt}/{total_fmt} [{elapsed}<{remaining}]')

    while covered < top_concepts:
        best = max(company_concepts, key=lambda c: len(company_concepts[c] - covered))
        new_concepts = company_concepts.pop(best) - covered
        covered |= new_concepts
        selected.append(best)
        pbar.update(len(new_concepts))

    pbar.close()

    result_df = pd.DataFrame(selected, columns=['prefix', 'cik', 'accessionNumber', 'form', 'endDate', 'units'])
    cols = ", ".join(result_df.columns)
    conn.execute(f"""
        INSERT INTO highConceptCoverageSubmissionsSample ({cols}) SELECT {cols} FROM result_df;
        CHECKPOINT;
    """)


if __name__ == "__main__":
    load_dotenv()
    PROJECT_ROOT_PARENT = Path(
        Path(__file__).resolve().parent.parent or
        Path(os.getenv("PROJECT_ROOT")).resolve().parent
    )

    db_path = os.path.join(PROJECT_ROOT_PARENT, "Data", "secFilingsDb.duckdb")

    conn = ddb.connect(db_path)
    conn.execute("""
        CREATE OR REPLACE TABLE highConceptCoverageSubmissionsSample (
            prefix VARCHAR,
            cik VARCHAR,
            accessionNumber VARCHAR,
            form VARCHAR,
            endDate DATE,
            units VARCHAR
        ); CHECKPOINT;
    """)
    populate_optimal_sample_table(conn, 'AllSafeSubmissionsAndConcepts', concept_top_pct=0.90)
    conn.close()