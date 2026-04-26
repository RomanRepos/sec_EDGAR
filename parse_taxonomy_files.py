
from dotenv import load_dotenv
from pathlib import Path
from lxml import etree
import os

load_dotenv()
PROJECT_ROOT = Path(Path(__file__).resolve().parent.parent or Path(os.getenv("PROJECT_ROOT")).resolve().parent)
DATA_DIR = PROJECT_ROOT / "Data" / "Test"

xml_xsd_files = []

for file in DATA_DIR.iterdir():
    if file.is_file() and file.suffix.lower() in ['.xml', '.xsd'] and not file.stem.startswith('.'):
        xml_xsd_files.append(file)

def extract_rows(xml_file, file_suffix):
    """Extract calculationLink and calculationArc data into DataFrame"""
    name_parts = xml_file.stem.split('_')
    cik = name_parts[0]
    accession_number = name_parts[1]
    tree = etree.parse(xml_file)
    #schema_doc = etree.parse(xml_file)
    #tree = etree.XMLSchema(schema_doc)
    root = tree.getroot()
    
    rows = []
    ns = root.nsmap if hasattr(root, 'nsmap') else {}
    xlink_ns = ns.get('xlink')
    if file_suffix == '.xml':
        calc_links = root.findall('calculationLink', ns)
    elif file_suffix == '.xsd':
        calc_links = root.xpath(".//link:linkbase/link:calculationLink", namespaces=ns)

    for calc_link in calc_links:
        link_type = calc_link.get(f'{{{xlink_ns}}}type')
        link_role = calc_link.get(f'{{{xlink_ns}}}role')
        if file_suffix == '.xml':
            calc_arcs = calc_link.findall('calculationArc', ns)
        elif file_suffix == '.xsd':
            calc_arcs = calc_link.xpath("link:calculationArc", namespaces=ns)       
        
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

output_rows = []
for file in xml_xsd_files:
    output_rows.extend(extract_rows(file, file.suffix.lower()))

print(output_rows)