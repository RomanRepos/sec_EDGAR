
from dotenv import load_dotenv
from pathlib import Path
import duckdb as ddb
from lxml import etree
import os
from tqdm import tqdm

def write_files_to_db(conn_arg, xml_taxonomy_dir, func_arg):
    xml_xsd_files = []
    for file in xml_taxonomy_dir.iterdir():
        if file.is_file() and file.suffix.lower() in ['.xml', '.xsd'] and not file.stem.startswith('.'):
            xml_xsd_files.append(file)
    result = []
    insert_tries = 0
 
    for file in tqdm(xml_xsd_files, desc="Processing files", unit="file"):
        try:    
            result.extend(func_arg(file))
        except Exception as e:
            continue
        if len(result) >= 10000:
            try:
                conn_arg.executemany("""
                    INSERT INTO calculation_arcs VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, [
                    (
                        d["cik"], d["accessionNumber"], d["linkXlinkType"], d["linkXlinkRole"],
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
                    INSERT INTO calculationTaxonomyRaw VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, [
                    (
                        d["cik"], d["accessionNumber"], d["linkXlinkType"], d["linkXlinkRole"],
                        d["arcXlinkType"], d["arcXlinkArcrole"], d["arcXlinkFrom"], d["arcXlinkTo"],
                        d["arcUse"], float(d["arcOrder"]), float(d["arcWeight"])
                    )
                    for d in result
                ])
                conn_arg.commit() 
            except Exception as e:
                print(f"Failed to insert final batch: {e}")


def extract_rows(xml_file):
    file_suffix = xml_file.suffix.lower()
    """Extract calculationLink and calculationArc data into DataFrame"""
    name_parts = xml_file.stem.split('_')
    cik = name_parts[0]
    accession_number = name_parts[1]
    tree = etree.parse(xml_file)
    root = tree.getroot()
    
    rows = []
    ns = root.nsmap if hasattr(root, 'nsmap') else {}
    xlink_ns = ns.get('xlink')
    if file_suffix == '.xml':
        try:
            calc_links = root.findall(".//{*}calculationLink")
        except Exception as e:
            calc_link = []
        if not calc_links:
            calc_links = root.findall("calculationLink", namespaces=ns)
    elif file_suffix == '.xsd':
        calc_links = root.xpath(".//link:calculationLink", namespaces=ns)
        if not calc_links:
            calc_links = root.xpath(".//calculationLink", namespaces=ns)

    for calc_link in calc_links:
        link_type = calc_link.get(f'{{{xlink_ns}}}type')
        link_role = calc_link.get(f'{{{xlink_ns}}}role')
        if file_suffix == '.xml':
            try:
                calc_arcs = calc_link.findall(".//{*}calculationArc")
            except Exception as e:
                calc_arcs = []
    
            if not calc_arcs:
                calc_arcs = calc_link.findall('calculationArc', ns)
        
        elif file_suffix == '.xsd':
            calc_arcs = calc_link.xpath("link:calculationArc", namespaces=ns) 
            if not calc_arcs:
                calc_arcs = calc_link.xpath("calculationArc", namespaces=ns)      
        
        for arc in calc_arcs:
            row = {
                'cik': cik,
                'accessionNumber': accession_number,
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
    conn.execute("""
        CREATE TABLE IF NOT EXISTS calculationTaxonomyRaw (
            cik             VARCHAR,
            accessionNumber VARCHAR,
            linkXlinkType   VARCHAR,
            linkXlinkRole   VARCHAR,
            arcXlinkType    VARCHAR,
            arcXlinkArcrole VARCHAR,
            arcXlinkFrom    VARCHAR,
            arcXlinkTo      VARCHAR,
            arcUse          VARCHAR,
            arcOrder        DOUBLE,
            arcWeight       DOUBLE
        )
    """)
    xml_taxonomy_dir = DATA_DIR / "calXmls"
    write_files_to_db(conn, xml_taxonomy_dir, extract_rows)
    conn.close()