
from dotenv import load_dotenv
from pathlib import Path
import xml.etree.ElementTree as ET
import pandas as pd
import os

load_dotenv()
PROJECT_ROOT = Path(Path(__file__).resolve().parent.parent or Path(os.getenv("PROJECT_ROOT")).resolve().parent)
DATA_DIR = PROJECT_ROOT / "Data" / "Test"

xml_xsd_files = []

for file in DATA_DIR.iterdir():
    if file.is_file() and file.suffix.lower() in ['.xml', '.xsd']:
        xml_xsd_files.append(file)

print(xml_xsd_files)