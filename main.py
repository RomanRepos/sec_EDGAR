from pathlib import Path
import duckdb as ddb
import os
import sys
from get_files import download_and_extract, sync_json_files
from flatten_json import flatten
from jinja2 import Template
from dotenv import load_dotenv
from utilities import load_query
from get_taxonomy_files import download_cal_xmls
from parse_taxonomy_files import write_calcs_to_db, get_xml_taxonomy_files, extract_calcs, extract_calcs_special_case
from classify_taxonomy_roles import classify_role
from generate_calc_tax_hierarchy import create_taxonomy_hierarchy
if __name__ == "__main__":

    load_dotenv()

    PROJECT_ROOT_PARENT = Path(Path(__file__).resolve().parent.parent or Path(os.getenv("PROJECT_ROOT")).resolve().parent)
    main_file_path = os.path.abspath(sys.argv[0])
    main_dir = os.path.dirname(main_file_path)
    DATA_DIR = os.path.join(PROJECT_ROOT_PARENT, "Data")
    db_path = os.path.join(DATA_DIR, "secFilingsDb.duckdb")
    xml_taxonomy_dir = os.path.join(PROJECT_ROOT_PARENT, DATA_DIR, "calXMLs")
    
    standard_line_items_path = os.path.join(main_dir, "standard_line_items.json")

    db_path = os.path.join(DATA_DIR, "secFilingsDb.duckdb")

    for d in [Path(DATA_DIR)]:
        d.mkdir(parents=True, exist_ok=True)


    conn = ddb.connect(db_path)
    inputs_dict = {'facts': {'link':'https://www.sec.gov/Archives/edgar/daily-index/xbrl/companyfacts.zip', 'savePath': os.path.join(DATA_DIR, "companyfacts")},
    'submissions': {'link':'https://www.sec.gov/Archives/edgar/daily-index/bulkdata/submissions.zip', 'savePath': os.path.join(DATA_DIR, "submissions")}}

    for i in inputs_dict.values():
        download_and_extract(i['link'], i['savePath'])

    sync_json_files(inputs_dict['facts']['savePath'],inputs_dict['submissions']['savePath'])

    load_sql_script = Template(load_query("LoadDataQueries"))

    final_sql = load_sql_script.render(facts_path_param=os.path.join(inputs_dict['facts']['savePath'], '*.json'), submissions_path_param=os.path.join(inputs_dict['submissions']['savePath'], '*.json'),
                                        standard_line_items_path_param=standard_line_items_path)
    
    print("Running Queries")
    for statement in final_sql.split(';'):
        if statement.strip():
            conn.execute(statement)
    print("Flattening facts")
    flatten(conn, 75) #flatten company facts
    conn.execute(load_query("AddColumnsToFinData"))

    download_cal_xmls(conn, DATA_DIR) #download calculation taxonomy files

    #write extracted calcs to db, first with general extraction logic, then with special case logic for files that don't follow typical calc patterns, then generate hierarchy and classify roles
    write_calcs_to_db(conn, get_xml_taxonomy_files(conn, xml_taxonomy_dir), extract_calcs)
    conn.execute('''delete from calculationTaxonomyRaw where arcXlinkFrom = 'src' or arcXlinkto = 'dest';
                checkpoint;''')
    write_calcs_to_db(conn, get_xml_taxonomy_files(conn, xml_taxonomy_dir), extract_calcs_special_case)
    
    #create clean taxonomies table and taxonomies classifed table.
    conn.execute(load_query("CreateCalculationTaxonomyTbl"))

    #classify roles into main statements and create table with classified roles
    roles_df = conn.execute('''select distinct linkRole from calculationTaxonomy''').fetch_df()
    roles_df['keyStatementRole'] = roles_df['linkRole'].apply(classify_role)
    roles_df = roles_df[roles_df['keyStatementRole'].notna()]
    conn.register('presentation_df', roles_df)
    conn.execute("CREATE OR REPLACE TABLE calcTaxRolesClassified AS SELECT * FROM roles_df; CHECKPOINT;")
    
    #Determine primary statements among roles classified as main statements.
    conn.execute(load_query("DeterminePrimaryStatements"))


    #Determine new taxonomy roles
    new_taxonomies_df = conn.execute(load_query("GenerateCalcHierarchy")).fetch_df()
    #generate hierarchy for new taxonomy files and insert into db
    create_taxonomy_hierarchy(new_taxonomies_df, conn)
    
    conn.execute(load_query("CreateKeyStatementsAndHierarchyTbl"))

    conn.close()