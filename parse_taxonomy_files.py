
from dotenv import load_dotenv
from pathlib import Path
import duckdb as ddb
from lxml import etree
import os
from tqdm import tqdm

def get_xml_taxonomy_files(conn_arg, xml_taxonomy_dir):
    conn_arg.execute("""
            CREATE TABLE IF NOT EXISTS calculationTaxonomyRaw (
                cik             VARCHAR,
                accessionNumber VARCHAR,
                fileName        VARCHAR,
                linkXlinkType   VARCHAR,
                linkXlinkRole   VARCHAR,
                arcXlinkType    VARCHAR,
                arcXlinkArcrole VARCHAR,
                arcXlinkFrom    VARCHAR,
                arcXlinkTo      VARCHAR,
                arcUse          VARCHAR,
                arcOrder        DOUBLE,
                arcWeight       DOUBLE
            );
            CHECKPOINT;
        """)
    existing_files = {row[0] for row in conn_arg.execute("SELECT DISTINCT cik ||'_'|| accessionNumber ||'_'|| fileName FROM calculationTaxonomyRaw;").fetchall()}

    xml_xsd_files = []
    for file in xml_taxonomy_dir.iterdir():
        if not file.name in existing_files:
            if file.is_file() and (file.suffix.lower() in ['.xml', '.xsd']) and not file.stem.startswith('.'):
                xml_xsd_files.append(file)
    return xml_xsd_files

def write_calcs_to_db(conn_arg, xml_xsd_files, func_arg):
    result = []
    insert_tries = 0

    for file in tqdm(xml_xsd_files, desc="Processing files", unit="file", 
                 bar_format='{desc}: {percentage:.2f}% |{bar}| {n_fmt}/{total_fmt} [{elapsed}<{remaining}]'):
        try:    
            result.extend(func_arg(file))
        except Exception as e:
            continue
        if len(result) >= 25000:
            try:
                conn_arg.executemany("""
                    INSERT INTO calculationTaxonomyRaw VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, [
                    (
                        d["cik"], d["accessionNumber"], d["fileName"], d["linkXlinkType"], d["linkXlinkRole"],
                        d["arcXlinkType"], d["arcXlinkArcrole"], d["arcXlinkFrom"], d["arcXlinkTo"],
                        d["arcUse"], float(d["arcOrder"]), float(d["arcWeight"])
                    )
                    for d in result
                ])
                conn_arg.commit() 
                result = []
                insert_tries = 0
            except Exception as e:
                insert_tries += 1
                if insert_tries >= 5:
                    print(f"Failed to insert batch after 5 attempts: {e}")
                    result = []  # Clear the batch after 5 failed attempts
                    insert_tries = 0
                    print("Insert failed, aborting further attempts.")
                    break
                else:  # Exit the loop after 5 failed attempts
                    continue # Clear the batch
        if result:
            try:
                conn_arg.executemany("""
                    INSERT INTO calculationTaxonomyRaw VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, [
                    (
                        d["cik"], d["accessionNumber"], d["fileName"], d["linkXlinkType"], d["linkXlinkRole"],
                        d["arcXlinkType"], d["arcXlinkArcrole"], d["arcXlinkFrom"], d["arcXlinkTo"],
                        d["arcUse"], float(d["arcOrder"]), float(d["arcWeight"])
                    )
                    for d in result
                ])
                conn_arg.commit() 
            except Exception as e:
                print(f"Failed to insert final batch: {e}")


def extract_calcs(xml_file):
    file_suffix = xml_file.suffix.lower()
    """Extract calculationLink and calculationArc data into DataFrame"""
    name_parts = xml_file.stem.split('_')
    cik = name_parts[0]
    accession_number = name_parts[1]
    file_name = "_".join(xml_file.name.split("_")[2:])
    tree = etree.parse(xml_file)
    root = tree.getroot()
    
    rows = []
    ns = root.nsmap if hasattr(root, 'nsmap') else {}
    xlink_ns = ns.get('xlink')

    #IF XML
    if file_suffix == '.xml':
        try:
            calc_links = root.findall("link:calculationLink", namespaces=ns) 
        except Exception as e:
            calc_links = []
        if not calc_links:
            calc_links = root.findall("{*}calculationLink")
        for calc_link in calc_links:
            try:
                calc_arcs = calc_link.findall('link:calculationArc', namespaces=ns)   
            except Exception as e:
                calc_arcs = []
            if not calc_arcs:
                calc_arcs = calc_link.findall("{*}calculationArc")
    #IF XSD
    elif file_suffix == '.xsd':
        calc_links = root.xpath(".//link:calculationLink", namespaces=ns)
        if not calc_links:
            calc_links = root.xpath(".//{*}calculationLink", namespaces=ns)
        for calc_link in calc_links:
            calc_arcs = calc_link.xpath(".//link:calculationArc", namespaces=ns)
            if not calc_arcs:
                calc_arcs = calc_link.xpath(".//{*}calculationArc", namespaces=ns)

    for calc_link in calc_links:
        link_type = calc_link.get(f'{{{xlink_ns}}}type')
        link_role = calc_link.get(f'{{{xlink_ns}}}role')
        for arc in calc_arcs:
            row = {
                'cik': cik,
                'accessionNumber': accession_number,
                'fileName': file_name,
                'linkXlinkType': link_type,
                'linkXlinkRole': link_role,
                'arcXlinkType': arc.get(f'{{{xlink_ns}}}type'),
                'arcXlinkArcrole': arc.get(f'{{{xlink_ns}}}arcrole'),
                'arcXlinkFrom': arc.get(f'{{{xlink_ns}}}from'),
                'arcXlinkTo': arc.get(f'{{{xlink_ns}}}to'),
                'arcUse': arc.get('use'),
                'arcOrder': arc.get('order'),
                'arcWeight': arc.get('weight')
            }
            rows.append(row)
  
    return rows


if __name__ == "__main__":
    load_dotenv()
    PROJECT_ROOT_PARENT = Path(Path(__file__).resolve().parent.parent or Path(os.getenv("PROJECT_ROOT")).resolve().parent)
    DATA_DIR = PROJECT_ROOT_PARENT / "Data"
    db_path = os.path.join(DATA_DIR, "secFilingsDb.duckdb")

    conn = ddb.connect(db_path)

    #conn.execute("Truncate table calculationTaxonomyRaw; CHECKPOINT;")
    xml_taxonomy_dir = DATA_DIR / "Test"
    write_calcs_to_db(conn, get_xml_taxonomy_files(conn, xml_taxonomy_dir), extract_calcs)
    conn.close()