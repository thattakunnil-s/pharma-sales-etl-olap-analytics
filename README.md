# pharma-sales-etl-olap-analytics

A lightweight, end-to-end analytics workflow for a fictional pharmaceutical distributor.  
Raw XML feeds are ingested, normalized into a SQLite warehouse, aggregated for OLAP querying, and finally summarized in a polished PDF report.  
The project highlights pragmatic ETL design, relational modeling, and data-storytelling in R.

---

## 1. Data Flow & Assets  

* **Inputs**  
  * `txn-xml/pharmaReps*.xml` – sales-rep master data  
  * `txn-xml/pharmaSalesTxn*.xml` – transactional invoice feeds  
* **Intermediate store** – `pharmaDB.sqlite` (auto-created) holds a star schema with lookup tables and a fact table.  
* **Outputs**  
  * OLTP-level tables (`products`, `customers`, `reps`, `sales`)  
  * OLAP views produced by aggregation logic  
  * `AnalyzeData.ThattakunnilS.pdf` – self-contained report with tables and ggplot charts.  

---

## 2. Script Directory  

| File | Purpose | Key Steps | Output |
|------|---------|-----------|--------|
| **LoadXML2DB.R** | ETL pipeline for the transactional (OLTP) layer | Builds schema, parses XML via XPath, deduplicates entities, loads `sales` fact rows | Populated OLTP tables in `pharmaDB.sqlite` |
| **LoadOLAP.R** | Aggregation & OLAP prep | Recreates schema, reruns ETL, rolls up data into analytic views for faster querying | OLAP-ready tables/views inside the same SQLite file |
| **AnalyzeDataThattakunnil.Rmd** | Exploratory analysis & reporting | Connects to SQLite, executes summary SQL, visualizes results with ggplot2, renders PDF | `AnalyzeData.ThattakunnilS.pdf` (charts + insights) |

---

## 3. Pipeline Usage  

Clone the repository, ensure R ≥ 4.0, and install the listed CRAN packages (`XML`, `RSQLite`, `DBI`, `dplyr`, `ggplot2`, `rmarkdown`, `kableExtra`).  
Running `Rscript LoadXML2DB.R` loads the star schema with raw, row-level transactions.  
Running `Rscript LoadOLAP.R` refreshes the database and produces aggregated views.  
Render the analytical report via:

```bash
R -e "rmarkdown::render('AnalyzeDataThattakunnil.Rmd')"

