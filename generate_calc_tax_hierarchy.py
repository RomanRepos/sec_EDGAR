from collections import defaultdict
import duckdb as ddb
from dotenv import load_dotenv
from pathlib import Path
import os
import pandas as pd
import gc

def get_subtree(node, children, rel_depth=1, visited=None):
    if visited is None:
        visited = set()
    if node in visited:
        return []
    visited.add(node)
    result = [(node, rel_depth)]
    if node in children:
        for child in children[node]:
            result.extend(get_subtree(child, children, rel_depth + 1, visited))
    return result

def create_taxonomy_hierarchy(df, conn):
    conn.execute("""
    CREATE TABLE IF NOT EXISTS calculationTaxonomyHierarchy (
        cik             INTEGER,
        accessionNumber VARCHAR,
        linkRole        VARCHAR,
        keyStatementRole VARCHAR,
        ancestor        VARCHAR,
        descendant      VARCHAR,
        relativeDepth   INTEGER,
        arcOrder        DOUBLE,
        arcWeight       DOUBLE,
        highestParent   BOOLEAN,
        lowestChild     BOOLEAN
    )
    """)
    conn.execute('ChECKPOINT;')
    normalized_data = []

    grouped = df.groupby(['cik', 'accessionNumber', 'linkRole'])
    del df
    gc.collect()
    for def_name, def_df in grouped:
        children = defaultdict(list)
        all_children = set()
        for _, row in def_df.iterrows():
    
            children[row['fromConcept']].append(row['toConcept'])
            all_children.add(row['toConcept'])

        has_children = set(children.keys())

        top_level_node_list = [
            row['fromConcept']
            for _, row in def_df.iterrows()
            if row['fromConcept'] not in all_children
        ]

        cik = def_df['cik'].iloc[0]
        accession_number = def_df['accessionNumber'].iloc[0]
        link_role = def_df['linkRole'].iloc[0]
        key_statement_role = def_df['keyStatementRole'].iloc[0]

        node_weights = {
            row['toConcept']: (row['arcWeight'], row['arcOrder'])
            for _, row in def_df.iterrows()
        }
        
        for child in all_children:  #self reference
            normalized_data.append({
                        'cik': cik,
                        'accessionNumber': accession_number,
                        'linkRole': link_role,
                        'ancestor': child,
                        'descendant': child,
                        'relativeDepth': 0,
                        'arcOrder': 0,
                        'arcWeight': 0,
                        'highestParent': False,
                        'lowestChild': child not in has_children,
                        'keyStatementRole': key_statement_role
                    })

        for top_level_node in set(top_level_node_list): 
            normalized_data.append({
                        'cik': cik,
                        'accessionNumber': accession_number,
                        'linkRole': link_role,
                        'ancestor': top_level_node,
                        'descendant': top_level_node,
                        'relativeDepth': 0,
                        'arcOrder': 0,
                        'arcWeight': 0,
                        'highestParent': True,
                        'lowestChild': False,
                        'keyStatementRole': key_statement_role
                    })
        
    
        
        for _, node in def_df.drop_duplicates().iterrows():
            subtree = get_subtree(node['toConcept'], children)
            deduplicated_subtree = list({s: i for s, i in sorted(subtree, key=lambda x: x[1])}.items())
            for desc, rel_dep in deduplicated_subtree:
                normalized_data.append({
                    'cik': cik,
                    'accessionNumber': accession_number,
                    'linkRole': link_role,
                    'ancestor': node['fromConcept'],
                    'descendant': desc,
                    'relativeDepth': rel_dep,
                    'arcOrder': node_weights.get(desc)[1],
                    'arcWeight': node_weights.get(desc)[0],
                    'highestParent': False,
                    'lowestChild': desc not in has_children,
                    'keyStatementRole': key_statement_role
                })
        insert_df = pd.DataFrame(normalized_data)
        conn.append('calculationTaxonomyHierarchy', insert_df)

        normalized_data.clear()
    conn.execute('CHECKPOINT;')
if __name__ == "__main__":
    load_dotenv()
    PROJECT_ROOT_PARENT = Path(Path(__file__).resolve().parent.parent or Path(os.getenv("PROJECT_ROOT")).resolve().parent)

    db_path = os.path.join(PROJECT_ROOT_PARENT, "Data", "secFilingsDb.duckdb")

    conn = ddb.connect(db_path)

    df = conn.execute('''SELECT ct.cik, ct.accessionNumber, ct.linkRole, crc.keyStatementRole as keyStatementRole, 
                        ct.fromConcept, ct.toConcept, ct.arcOrder,
    ct.arcWeight from calculationTaxonomy ct 
    inner join calcTaxRolesClassified crc on crc.linkRole = ct.linkRole
    anti join calculationTaxonomyHierarchy cth on cth.cik = ct.cik and cth.accessionNumber = ct.accessionNumber
        and ct.linkRole = cth.linkRole
    where ct.isPrimaryRole=TRUE
    and ct.fromConcept IS NOT NULL and ct.toConcept IS NOT NULL and ct.fromConcept<>ct.toConcept;''').fetch_df()

    create_taxonomy_hierarchy(df, conn)
    conn.close()