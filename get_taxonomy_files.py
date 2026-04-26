import os
from curl_cffi import requests
import xml.etree.ElementTree as ET
import pandas as pd
from pathlib import Path
from bs4 import BeautifulSoup
from dotenv import load_dotenv
import duckdb as ddb
from dotenv import load_dotenv

def download_cal_xmls(conn):
    load_dotenv()
    
    for d in [DATA_DIR]:
        d.mkdir(parents=True, exist_ok=True)

    save_path = os.path.join(DATA_DIR, "calXMLs/")
    xml_taxonomy_folder = Path(save_path)
    xml_taxonomy_folder.mkdir(parents=True, exist_ok=True)

    records = set()
    for f in xml_taxonomy_folder.iterdir():
        if f.suffix in (".xml", ".xsd"):
            parts = f.stem.split("_")
            if len(parts) >= 2:
                cik, accession_number = parts[0], parts[1]
                records.add((cik, accession_number))


    df_db = conn.execute("""SELECT DISTINCT cik, accessionNumber from FinancialData
        """).fetch_df()
    conn.close()

    if records:
        df_folder = pd.DataFrame(records, columns=["cik", "accessionNumber"])
        df_folder['cik'] = df_folder['cik'].astype("int32")
        df = df_db.merge(df_folder, on=["cik", "accessionNumber"], how="left", indicator=True)
        df= df[df["_merge"] == "left_only"].drop(columns="_merge")
    else:
        df = df_db
    if not df.empty:
        df['url'] = df.apply(lambda row: f"https://www.sec.gov/Archives/edgar/data/{row['cik']}/{row['accessionNumber'].replace('-', '')}/FilingSummary.xml", axis=1)
        df['url_no_file'] = df.apply(lambda row: f"https://www.sec.gov/Archives/edgar/data/{row['cik']}/{row['accessionNumber'].replace('-', '')}/", axis=1)

        def download_cal_xmls(url, urlNoFile, cik, accessionNumber, savePath):
            cal_link = None
            cal_file = None
            os.makedirs(savePath, exist_ok=True)
            try:
                response = requests.get(url, impersonate="chrome101", stream=False,timeout=30)
                root = ET.fromstring(response.text)
                response.raise_for_status() 
                
            except Exception as e:
                response = requests.get(urlNoFile, impersonate="chrome101", stream=False,timeout=30)
                response.raise_for_status() 
                soup = BeautifulSoup(response.text, "html.parser")
                cal_link = soup.find("a", href=lambda h: h and h.endswith("_cal.xml"))
                if cal_link:
                    cal_file = cal_link["href"].split("/")[-1]
            
            if not cal_link:
                for file in root.findall("InputFiles/File"):
                    if file.text and file.text.endswith("_cal.xml"):
                        cal_file = file.text
                        break
            
            if not cal_file:
                for file in root.findall("InputFiles/File"):
                    if file.text and file.text.endswith("xsd"):
                        cal_file = file.text
                        break

            
            if cal_file:
                response = requests.get(urlNoFile+cal_file, impersonate="chrome101", stream=False,timeout=30)
                response.raise_for_status()               # Check for download errors
                saveFilePath = os.path.join(savePath, f"{cik}_{accessionNumber}_{cal_file}")
                Path(saveFilePath).write_bytes(response.content)
                return saveFilePath
            else:
                print(f"No _cal.xml file found {url}")

        print(f"Files to download: {len(df)}")
        count = 1

        for row in df.iterrows():
            try:
                file = download_cal_xmls(row['url'], row['url_no_file'], row['cik'], row['accessionNumber'], save_path)
                if file:
                    print(f"Downloaded: {file} (Count: {count})")
                    count += 1
            except Exception as e:
                continue

if __name__ == "__main__":
    load_dotenv()

    PROJECT_ROOT = Path(Path(__file__).resolve().parent.parent or Path(os.getenv("PROJECT_ROOT")).resolve().parent)
    DATA_DIR = PROJECT_ROOT / "Data"
    db_directory = DATA_DIR
    db_path = os.path.join(db_directory, "secFilingsDb.duckdb")

    conn = ddb.connect(db_path, read_only=True)
    download_cal_xmls(conn)