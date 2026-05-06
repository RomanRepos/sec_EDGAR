from dotenv import load_dotenv
from pathlib import Path
import duckdb as ddb
from lxml import etree
import os
from tqdm import tqdm

BATCH_SIZE = 20_000
INSERT_SQL = """
    INSERT INTO calculationTaxonomyRaw VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
"""

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

    # Build set of already-parsed full filenames e.g. "1750_0001047469_air-20140531_cal.xml"
    existing_files = {
        row[0] for row in conn_arg.execute(
            "SELECT DISTINCT cik ||'_'|| accessionNumber ||'_'|| fileName FROM calculationTaxonomyRaw;"
        ).fetchall()
    }

    return [
        file for file in xml_taxonomy_dir.iterdir()
        if file.is_file()
        and file.suffix.lower() in ('.xml', '.xsd')
        and not file.name.startswith('.')
        and file.name not in existing_files
    ]


def extract_calcs(xml_file):
    name_parts = xml_file.stem.split('_')
    cik              = name_parts[0]
    accession_number = name_parts[1]
    file_name        = "_".join(xml_file.name.split("_")[2:])

    tree = etree.parse(xml_file)
    root = tree.getroot()

    # Dynamically resolve namespace URIs from root nsmap
    ns = root.nsmap
    linkbase_uri = ns.get('link', 'http://www.xbrl.org/2003/linkbase')
    xlink_uri    = ns.get('xlink', 'http://www.w3.org/1999/xlink')

    calc_link_tag = f"{{{linkbase_uri}}}calculationLink"
    calc_arc_tag  = f"{{{linkbase_uri}}}calculationArc"
    xlink_type    = f"{{{xlink_uri}}}type"
    xlink_role    = f"{{{xlink_uri}}}role"
    xlink_arcrole = f"{{{xlink_uri}}}arcrole"
    xlink_from    = f"{{{xlink_uri}}}from"
    xlink_to      = f"{{{xlink_uri}}}to"

    if root.tag == calc_link_tag:
        calc_links = [root]
    else:
        calc_links = root.findall(f".//{calc_link_tag}")

    rows = []

    for calc_link in calc_links:
        link_type = calc_link.get(xlink_type)
        link_role = calc_link.get(xlink_role)
        for arc in calc_link.findall(calc_arc_tag):
            rows.append((
                cik,
                accession_number,
                file_name,
                link_type,
                link_role,
                arc.get(xlink_type),
                arc.get(xlink_arcrole),
                arc.get(xlink_from),
                arc.get(xlink_to),
                arc.get('use'),
                float(arc.get('order', 0)),
                float(arc.get('weight', 0)),
            ))
    

    return rows


def extract_calcs_special_case(xml_file):
    name_parts = xml_file.stem.split('_')
    cik              = name_parts[0]
    accession_number = name_parts[1]
    file_name        = "_".join(xml_file.name.split("_")[2:])

    tree = etree.parse(xml_file)
    root = tree.getroot()

    # Dynamically resolve namespace URIs from root nsmap
    ns = root.nsmap
    linkbase_uri = ns.get('link', 'http://www.xbrl.org/2003/linkbase')
    xlink_uri    = ns.get('xlink', 'http://www.w3.org/1999/xlink')

    calc_link_tag = f"{{{linkbase_uri}}}calculationLink"
    calc_arc_tag  = f"{{{linkbase_uri}}}calculationArc"
    calc_loc_tag  = f"{{{linkbase_uri}}}loc"
    xlink_type    = f"{{{xlink_uri}}}type"
    xlink_role    = f"{{{xlink_uri}}}role"
    xlink_arcrole = f"{{{xlink_uri}}}arcrole"
    xlink_label   = f"{{{xlink_uri}}}label"
    xlink_href    = f"{{{xlink_uri}}}href"

    if root.tag == calc_link_tag:
        calc_links = [root]
    else:
        calc_links = root.findall(f".//{calc_link_tag}")

    rows = []


    for calc_link in calc_links:
        fromLink = None
        toLink = None
        link_type = calc_link.get(xlink_type)
        link_role = calc_link.get(xlink_role)
        for arc in calc_link.findall(calc_arc_tag):
            if len(calc_link.findall(calc_loc_tag))==2:
                if calc_link.findall(calc_loc_tag)[0].get(xlink_label) == 'src':
                    fromLink = calc_link.findall(calc_loc_tag)[0].get(xlink_href).split('#')[-1]
                    toLink = calc_link.findall(calc_loc_tag)[1].get(xlink_href).split('#')[-1]
                elif calc_link.findall(calc_loc_tag)[0].get(xlink_label) == 'dest':
                    toLink = calc_link.findall(calc_loc_tag)[0].get(xlink_href).split('#')[-1]
                    fromLink = calc_link.findall(calc_loc_tag)[1].get(xlink_href).split('#')[-1]

            rows.append((
                cik,
                accession_number,
                file_name,
                link_type,
                link_role,
                arc.get(xlink_type),
                arc.get(xlink_arcrole),
                fromLink,
                toLink,
                arc.get('use'),
                float(arc.get('order', 0)),
                float(arc.get('weight', 0)),
            ))
    

    return rows


def flush_batch(conn_arg, batch):
    conn_arg.executemany(INSERT_SQL, batch)
    conn_arg.execute("CHECKPOINT;")


def write_calcs_to_db(conn_arg, xml_xsd_files, func_arg):
    batch = []

    for file in tqdm(xml_xsd_files, desc="Processing files", unit="file",
                     bar_format='{desc}: {percentage:.2f}% |{bar}| {n_fmt}/{total_fmt} [{elapsed}<{remaining}]'):
        try:
            batch.extend(func_arg(file))
        except Exception as e:
            print(f"Failed to parse {file.name}: {e}")
            continue

        if len(batch) >= BATCH_SIZE:
            try:
                flush_batch(conn_arg, batch)
                batch.clear()
            except Exception as e:
                print(f"Failed to insert batch: {e}")
                batch.clear()

    # Insert remaining rows
    if batch:
        try:
            flush_batch(conn_arg, batch)
        except Exception as e:
            print(f"Failed to insert final batch: {e}")


if __name__ == "__main__":
    load_dotenv()
    PROJECT_ROOT_PARENT = Path(
        Path(__file__).resolve().parent.parent or 
        Path(os.getenv("PROJECT_ROOT")).resolve().parent
    )

    db_path    = os.path.join(PROJECT_ROOT_PARENT, "Data", "secFilingsDb.duckdb")

    conn = ddb.connect(db_path)
    xml_taxonomy_dir = os.path.join(PROJECT_ROOT_PARENT, "Data", "calXMLs")
    write_calcs_to_db(conn, get_xml_taxonomy_files(conn, xml_taxonomy_dir), extract_calcs)

    conn.execute('''delete from calculationTaxonomyRaw where arcXlinkFrom = 'src' or arcXlinkto = 'dest';
                checkpoint;''')

    write_calcs_to_db(conn, get_xml_taxonomy_files(conn, xml_taxonomy_dir), extract_calcs_special_case)
    conn.close()