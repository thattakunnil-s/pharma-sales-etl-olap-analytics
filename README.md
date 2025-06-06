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
```

---
## 4. Results

Running the full pipeline creates two deliverables:

1. **pharmaDB.sqlite** – a star-schema database with both raw transactions and OLAP summary views, ready for SQL queries, BI dashboards, or ML workflows.  
2. **AnalyzeData.ThattakunnilS.pdf** – a shareable report with ranking tables and ggplot charts that spotlight top reps, seasonal product demand, regional sales patterns, and average deal sizes.

These artefacts demonstrate the journey from raw XML to decision-ready insight and can be regenerated anytime with one ETL run plus an RMarkdown render.

---

## 5. Analysis

The PDF report is generated with **AnalyzeDataThattakunnil.Rmd**, an RMarkdown notebook that blends SQL, R, and visualization libraries:

* **SQL layer** – parameterised queries via `DBI::dbGetQuery()` pull data from the OLAP views (e.g., yearly revenue by rep, quarterly volume by product, units by country).  
* **Transformation layer** – `dplyr` pipelines reshape and summarise the result sets, adding calculated KPIs such as average deal size and YoY growth.  
* **Visualization layer** – `ggplot2` produces ranking bar charts, line plots for seasonality, and faceted heat-maps for regional trends; tables are rendered with `kableExtra` for a clean, PDF-ready layout.  
* Each code chunk is cached, so re-running the notebook after fresh ETL finishes in seconds.  
* Analysts can swap in new queries or tweak visual themes without touching the ETL scripts—simply edit the `.Rmd`, hit **Knit**, and a new PDF drops out.

This modular approach keeps data extraction, transformation, and presentation loosely coupled while showcasing the full analytics stack in a single, reproducible document.
