import pandas as pd
import duckdb as ddb
from utilities import load_query
from dotenv import load_dotenv
from pathlib import Path
import os
from tqdm import tqdm

def populate_optimal_sample_table(conn, query:str, concept_top_pct:float=0.8, prefix:str="us-gaap"):
    print("Loading clean submissions from database...")
    df = conn.execute(query, [prefix, prefix]).fetch_df()
    concept_counts = df["descendant"].value_counts().sort_values(ascending=False)
    concept_counts.to_excel('/home/roman/Documents/EDGAR_Analytics/Analytics/ConceptCounts.xlsx')

   
    top_n = max(1, int(len(concept_counts) * concept_top_pct))
    top_concepts = set(concept_counts.iloc[:top_n].index)
    df = df[df["descendant"].isin(top_concepts)]

    company_concepts = df.groupby(['cik', 'accessionNumber'])["descendant"].agg(set).to_dict()

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

    result_df = pd.DataFrame(selected, columns=['cik', 'accessionNumber'])
    result_df['prefix'] = prefix
    conn.execute("""
        INSERT INTO highConceptCoverageSubmissionsSample SELECT prefix, cik, accessionNumber FROM result_df;
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
            accessionNumber VARCHAR
        ); CHECKPOINT;
    """)
    populate_optimal_sample_table(conn, load_query('AllSafeSubmissionsAndConcepts'), concept_top_pct=0.95, prefix="ifrs-full")
    populate_optimal_sample_table(conn, load_query('AllSafeSubmissionsAndConcepts'), concept_top_pct=0.8, prefix="us-gaap")

    conn.close()