import duckdb as ddb
import os
import sys
from get_files import download_and_extract, sync_json_files
from flatten_json import flatten
from jinja2 import Template

if __name__ == "__main__":


    db_directory = "/home/roman/hdd1/EDGAR_Analytics/Data"
    db_path = os.path.join(db_directory, "secFilingsDb.duckdb")

    conn = ddb.connect(db_path)
    main_file_path = os.path.abspath(sys.argv[0])
    main_dir = os.path.dirname(main_file_path)
    inputs_dict = {'facts': {'link':'https://www.sec.gov/Archives/edgar/daily-index/xbrl/companyfacts.zip', 'savePath': '/home/roman/hdd1/Documents/EDGAR_Analytics/Data/companyfacts'},
    'submissions': {'link':'https://www.sec.gov/Archives/edgar/daily-index/bulkdata/submissions.zip', 'savePath':'/home/roman/hdd1/Documents/EDGAR_Analytics/Data/submissions'}}

    for i in inputs_dict.values():
        download_and_extract(i['link'], i['savePath'])

    sync_json_files(inputs_dict['facts']['savePath'],inputs_dict['submissions']['savePath'])

    with open(os.path.join(main_dir,'LoadDataQueries.sql'), 'r') as f:
        load_sql_script = Template(f.read())

    final_sql = load_sql_script.render(facts_path_param=os.path.join(inputs_dict['facts']['savePath'], '*.json'), submissions_path_param=os.path.join(inputs_dict['submissions']['savePath'], '*.json'))
    
    for statement in final_sql.split(';'):
        if statement.strip():
            conn.execute(statement)

    flatten(conn, 220)
    conn.close()