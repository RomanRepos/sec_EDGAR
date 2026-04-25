
from dotenv import load_dotenv
from pathlib import Path
from lxml import etree
import os

load_dotenv()
PROJECT_ROOT = Path(Path(__file__).resolve().parent.parent or Path(os.getenv("PROJECT_ROOT")).resolve().parent)
DATA_DIR = PROJECT_ROOT / "Data" / "Test"

xml_xsd_files = []

for file in DATA_DIR.iterdir():
    if file.is_file() and file.suffix.lower() in ['.xml']:
        xml_xsd_files.append(file)

def extract_to_dataframe(xml_file):
    """Extract calculationLink and calculationArc data into DataFrame"""
    
    tree = etree.parse(xml_file)
    root = tree.getroot()
    
    rows = []
    ns = root.nsmap if hasattr(root, 'nsmap') else {}
    xlink_ns = ns.get('xlink')

    for calc_link in root.findall('calculationLink', ns):
        link_type = calc_link.get(f'{{{xlink_ns}}}type')
        link_role = calc_link.get(f'{{{xlink_ns}}}role')
        for arc in calc_link.findall('calculationArc', ns):
            row = {
                'link_xlink_type': link_type,
                'link_xlink_role': link_role,
                'arc_xlink_type': arc.get(f'{{{xlink_ns}}}type'),
                'arc_xlink_arcrole': arc.get(f'{{{xlink_ns}}}arcrole'),
                'arc_xlink_from': arc.get(f'{{{xlink_ns}}}from'),
                'arc_xlink_to': arc.get(f'{{{xlink_ns}}}to'),
                'arc_use': arc.get('use'),
                'arc_order': arc.get('order'),
                'arc_weight': arc.get('weight')
            }
            rows.append(row)
    
   
    return rows

output_rows = []
for file in xml_xsd_files:
    output_rows.extend(extract_to_dataframe(file))

print(output_rows)