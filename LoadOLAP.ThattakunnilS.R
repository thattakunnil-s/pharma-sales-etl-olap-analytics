# title: Load OLAP Database
# subtitle: Practicum II
# author: Steffi Thattakunnil
# date: Spring 2024

# Load the required libraries
library(DBI)
library(RMySQL)
library(RSQLite)

# Database connection details
db_server <- "sql5.freemysqlhosting.net"
db_name <- "sql5699914"
db_username <- "sql5699914"
db_password <- "NRLtz2sMsj"
db_port <- 3306


# Connect to the MySQL database
dbcon <- dbConnect(RMySQL::MySQL(), 
                   user=db_username, 
                   password=db_password, 
                   dbname=db_name, 
                   host=db_server, 
                   port=db_port)

# Establish connection to the local SQLite database
sqliteDB <- dbConnect(RSQLite::SQLite(),dbname = "pharmaDB.sqlite")


# Function to create the star schema
createStarSchema <- function() {
  
  # Disable foreign keys
  dbExecute(dbcon, "SET FOREIGN_KEY_CHECKS=0;")
  
  # Drop existing tables
  tablesToDrop <- c("product_facts", "rep_facts")
  for (table in tablesToDrop) {
    dbExecute(dbcon, paste("DROP TABLE IF EXISTS", table, ";"))
  }
  
  # Create product_facts table
  dbExecute(dbcon, "
      CREATE TABLE product_facts (
        pdtID INTEGER,
        productName VARCHAR(50),
        year YEAR,
        quarter VARCHAR(2),
        region VARCHAR(50),
        totalSales DECIMAL(10,2),
        totalUnits INT
      );")
  
  # Create rep_facts table
  dbExecute(dbcon, "
      CREATE TABLE rep_facts (
        repID INTEGER,
        repName VARCHAR(50),
        year YEAR,
        quarter VARCHAR(2),
        totalTransactions INTEGER,
        totalSoldAmount DECIMAL(10,2),
        averageSoldAmount DECIMAL(10,2)
      );")

  # Enable foreign key constraints
  dbExecute(dbcon, "SET FOREIGN_KEY_CHECKS=1;")
}


# Function to extract data from local SQLiteDB and load into MySQLDB
populateFacts <- function() {
  
  # Extract data for product_facts
  productQuery <- "
   SELECT p.pdtID AS pdtID,
          p.product AS productName,
          strftime('%Y', s.date) AS year,
          CASE
              WHEN CAST(strftime('%m', s.date) AS INTEGER) BETWEEN 1 AND 3 THEN 'Q1'
              WHEN CAST(strftime('%m', s.date) AS INTEGER) BETWEEN 4 AND 6 THEN 'Q2'
              WHEN CAST(strftime('%m', s.date) AS INTEGER) BETWEEN 7 AND 9 THEN 'Q3'
              WHEN CAST(strftime('%m', s.date) AS INTEGER) BETWEEN 10 AND 12 THEN 'Q4'
          END AS quarter,
          r.territory AS region,
          SUM(s.total) AS totalSales,
          SUM(s.quantity) AS totalUnits
      FROM
        sales s
      JOIN
        products p ON s.pdtID = p.pdtID
      JOIN
        reps r ON s.repID = r.repID
     GROUP BY
           p.pdtID,
           year,
           quarter,
           region; 
  "

  # Execute the product query on the SQLite database
  productDF <- dbGetQuery(sqliteDB, productQuery)
  
  # Load data into product_facts MySQL table
  dbWriteTable(dbcon, "product_facts", productDF, append = TRUE, row.names = FALSE)
  
  
  # Extract data for rep_facts
  repQuery <- "
   SELECT r.repID,
          (r.firstName || ' ' || r.lastName) AS repName,
          strftime('%Y', s.date) AS year,
          CASE 
              WHEN strftime('%m', s.date) BETWEEN '01' AND '03' THEN 'Q1'
              WHEN strftime('%m', s.date) BETWEEN '04' AND '06' THEN 'Q2'
              WHEN strftime('%m', s.date) BETWEEN '07' AND '09' THEN 'Q3'
              WHEN strftime('%m', s.date) BETWEEN '10' AND '12' THEN 'Q4'
          END AS quarter,
          SUM(s.total) AS totalSoldAmount,
          AVG(s.total) AS averageSoldAmount,
          COUNT(s.total) AS totalTransactions
      FROM
        sales s
      JOIN
        reps r ON s.repID = r.repID
     GROUP BY
           r.repID,
           year,
           quarter
     ORDER BY
           r.repID, 
           year,
           quarter;
   "

  # Execute the rep query on the SQLite database
  repDF <- dbGetQuery(sqliteDB, repQuery)
  
  # Load data into rep_facts MySQL table
  dbWriteTable(dbcon, "rep_facts", repDF, append = TRUE, row.names = FALSE)
  
  
  # Test Queries
  # Check number of rows in product_facts
  nrow_product_facts <- dbGetQuery(dbcon, "SELECT COUNT(*) AS count FROM product_facts")
  cat("Number of rows in product_facts table : ", nrow_product_facts$count, "\n")
  
  # Check number of rows in rep_facts
  nrow_rep_facts <- dbGetQuery(dbcon, "SELECT COUNT(*) AS count FROM rep_facts")
  cat("Number of rows in rep_facts table : ", nrow_rep_facts$count, "\n")

} 


# Function to perform analysis using query
analyticalQuery <- function() {
  
  # Query 1: Total sold for each quarter of 2021 for 'Alaraphosol'
  query1 <- "
   SELECT quarter,
          SUM(totalSales) AS totalSales
     FROM
       product_facts
      WHERE
       productName = 'Alaraphosol' AND
       year = '2021'
    GROUP BY
          quarter
    ORDER BY
          quarter;"
  suppressWarnings(result1 <- dbGetQuery(dbcon, query1))
  print("Total sales for each quarter of 2021 for 'Alaraphosol':")
  print(result1)
  
  
  # Query 2: Which sales rep sold the most in 2022?
  query2 <- "
   SELECT repName,
          SUM(totalSoldAmount) AS totalSoldAmount
     FROM
       rep_facts
      WHERE
       year = '2022'
    GROUP BY
          repID, 
          repName
    ORDER BY
          totalSoldAmount DESC
    LIMIT 1;"
  suppressWarnings(result2 <- dbGetQuery(dbcon, query2))
  print("Sales rep who sold the most in 2022:")
  print(result2)
  
  
  # Query 3: How many units were sold in EMEA in 2022 for 'Alaraphosol'?
  query3 <- "
   SELECT SUM(totalUnits) AS totalUnits
     FROM
       product_facts
      WHERE
       productName = 'Alaraphosol' AND
       region = 'EMEA' AND
       year = '2022';"
  suppressWarnings(result3 <- dbGetQuery(dbcon, query3))
  print("Units sold in EMEA in 2022 for 'Alaraphosol':")
  print(result3)
  
}


main <- function() {
  # Create the facts tables
  createStarSchema()
  
  # Extract and load the data from SQLite to MySQL
  populateFacts()
  
  # Perform analysis
  analyticalQuery()
  
  # Disconnect from the local SQLite DB
  dbDisconnect(sqliteDB)
  
  # Disconnect from the remote MySQL DB
  dbDisconnect(dbcon)
}

main()