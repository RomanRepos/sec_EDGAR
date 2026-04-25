import pandas as pd
import json
from datetime import datetime
import gc


def parse_json_object(rowVar):
    try:         
        df_flat = pd.DataFrame()
        df_flat = pd.json_normalize(rowVar['facts'],  max_level=1).T
        df_flat.reset_index(inplace=True)
        df_flat.columns = ['path', 'json']
        df_flat['units'] = df_flat['json'].apply(lambda x: list(x['units'].keys()))
        df_flat['label'] = df_flat['json'].apply(lambda x: x['label'])
        df_flat['description'] = df_flat['json'].apply(lambda x: x['description'])
        df_flat = df_flat.explode('units').reset_index(drop=True)
        df_flat['prefix'] = df_flat['path'].apply(lambda x: x.split('.')[0])
        df_flat['name'] = df_flat['path'].apply(lambda x: x.split('.')[1])
        df_flat.drop(columns=['path'], inplace=True)
        df_flat['records'] = df_flat.apply(lambda row: row['json']['units'][row['units']], axis=1)
        df_flat.drop(columns=['json'], inplace=True)
        df_flat = df_flat.explode('records').reset_index(drop=True)
        new_cols = pd.json_normalize(df_flat['records'])
        new_cols = new_cols.reindex(columns=['fy', 'fp', 'start', 'end', 'accn', 'val', 'frame'])
        df_flat.drop(columns=['records'], inplace=True)
        df_flat = df_flat.join(new_cols)
        df_flat['cik'] = rowVar['cik']
        df_flat.rename(columns = {'fy':'financialYear', 'fp':'financialPeriod', 'end':'endDate', 'val':'value', 'accn':'accessionNumber', 'start':'startDate'}, inplace=True)
        return df_flat.to_dict(orient='records')
    except:
        return []

def flatten(conn_arg, batch_size_arg):

    conn_arg.execute("""CREATE OR REPLACE TABLE financialData (
        cik INTEGER,
        prefix VARCHAR,
        name VARCHAR,
        label VARCHAR,
        description VARCHAR,
        units VARCHAR,
        financialYear INTEGER,
        financialPeriod VARCHAR,
        startDate DATE,
        endDate DATE, 
        frame VARCHAR,
        accessionNumber VARCHAR,
        value DOUBLE         -- Matches pandas float64
    );
    CHECKPOINT;""")

    count=0
    # 2. Iterate until all chunks are pulled
    
    allCiks = [str(j) for j in list(conn_arg.execute("SELECT distinct cik FROM raw_data").fetch_df()['cik'])]
    print(count, datetime.now())
    for i in range(0, len(allCiks), batch_size_arg):
        batch = '('+','.join(allCiks[i:i + batch_size_arg])+')'
        df_chunk = conn_arg.execute(f"SELECT * FROM raw_data where cik in {batch}").fetch_df()
        df_chunk['facts'] = df_chunk['facts'].apply(json.loads)
        df_chunk['outPutListDict'] = df_chunk.apply(parse_json_object, axis=1)
        df_chunk.drop(columns='facts', inplace=True)
        df_exploded = df_chunk.explode('outPutListDict').dropna(subset=['outPutListDict'])
        expanded_cols = pd.DataFrame(df_exploded['outPutListDict'].tolist())
        del df_exploded
        del df_chunk
        gc.collect()
        conn_arg.execute("""
                    INSERT INTO financialData 
                    SELECT 
                        cik,
                        prefix,
                        name,
                        label,
                        description,
                        units,
                        financialYear,
                        financialPeriod,
                        CAST(startDate AS DATE) AS startDate,
                        CAST(endDate AS DATE) AS endDate,
                        frame,
                        accessionNumber,
                        value
                    FROM expanded_cols; 
                    CHECKPOINT;
                    """)
        
        del expanded_cols
        gc.collect()
        count+=1
        print(count, datetime.now())


    conn_arg.execute('DROP TABLE raw_data;')
    conn_arg.execute('CHECKPOINT;')