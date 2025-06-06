# title: Load XML data to SQLite DB
# subtitle: Practicum II
# author: Steffi Thattakunnil
# date: Spring 2024


# Load the required libraries
library(XML)
library(RSQLite)
library(DBI)

# Connect to the SQLite database and define database name
dbcon <- dbConnect(RSQLite::SQLite(),dbname = "pharmaDB.sqlite")


# Function to create the tables
createSchema <- function(){
  
  # Disable foreign key constraints 
  dbExecute(dbcon, "PRAGMA foreign_keys = OFF")
  
  # Drop existing tables
  tableList <- c("products", "customers", "reps", "sales")
  for (table in tableList){
    dbExecute(dbcon, paste("DROP TABLE IF EXISTS", table, ";"))
  }
  
  # Ensure foreign key constraints are enforced
  dbExecute(dbcon, "PRAGMA foreign_keys = ON")
  
  # Create products table
  dbExecute(dbcon, "
  CREATE TABLE products (
    pdtID INTEGER PRIMARY KEY,
    product VARCHAR(50)
  );")
  
  # Create reps table
  dbExecute(dbcon, "
  CREATE TABLE reps (
    repID INTEGER PRIMARY KEY,
    firstName VARCHAR(25),
    lastName VARCHAR(25),
    territory VARCHAR(50),
    commission INTEGER
  );")
  
  # Create customers table
  dbExecute(dbcon, "
  CREATE TABLE customers (
    cusID INTEGER PRIMARY KEY,
    customer VARCHAR(50),
    country VARCHAR(20)
  );")
  
  # Create sales table
  dbExecute(dbcon, "
  CREATE TABLE sales (
    txnID INTEGER PRIMARY KEY,
    repID INTEGER,
    cusID INTEGER,
    pdtID INTEGER,
    date TEXT,
    quantity INTEGER,
    currency VARCHAR(10),
    total INTEGER,
    FOREIGN KEY (pdtID) REFERENCES products(pdtID),
    FOREIGN KEY (repID) REFERENCES reps(repID),
    FOREIGN KEY (cusID) REFERENCES customers(cusID)
  );")
}


# Function to load and extract the XML data
loadAndExtractXML <- function(){
  # Define the path for the files
  dir <- "txn-xml/"
  
  # Find the file for reps using wildcard
  repsFile <- list.files(path = dir, pattern = "pharmaReps.*\\.xml", full.names = T)
  
  # Parse reps xml without validation
  xmlReps <- xmlParse(file = repsFile[1], validate = FALSE)
  
  # Extract reps data into a dataframe
  repsDF <- data.frame(
    repID = xpathSApply(xmlReps, "//rep", xmlGetAttr, "rID"),
    firstName = xpathSApply(xmlReps, "//rep/name/first/text()", xmlValue),
    lastName = xpathSApply(xmlReps, "//rep/name/sur/text()", xmlValue),
    territory = xpathSApply(xmlReps, "//rep/territory/text()", xmlValue),
    commission = as.numeric(xpathSApply(xmlReps, "//rep/commission", xmlValue)),
    stringsAsFactors = FALSE
    )
  
  # Remove 'r' in the rID values and convert to integer
  repsDF$repID <- as.integer(gsub("r", "", repsDF$repID)) 

  # Insert reps data into database
  dbWriteTable(dbcon, "reps", repsDF, append = TRUE, row.names = FALSE)
  
  # Initialize lookup tables
  productLookup <- list()
  customerLookup <- list()
    
  # Find all sales transaction files using wildcard
  salesFiles <- list.files(path = dir, pattern = "pharmaSalesTxn.*\\.xml", full.names = T)
  
  # Iterate through each sales file
  for (file in salesFiles) {
    # Parse sales xml without validation
    xmlSales <- xmlParse(file = file, validate = FALSE)
 
    # Extract sales data into a dataframe
    salesDF <- data.frame(
      repID = as.integer(xpathSApply(xmlSales, "//txn", xmlGetAttr, "repID")),
      customer = xpathSApply(xmlSales, "//txn/customer/text()", xmlValue),
      country = xpathSApply(xmlSales, "//txn/country/text()", xmlValue),
      date = as.Date(xpathSApply(xmlSales, "//txn/sale/date", xmlValue), format = "%m/%d/%Y"),
      product = xpathSApply(xmlSales, "//txn/sale/product/text()", xmlValue),
      quantity = as.integer(xpathSApply(xmlSales, "//txn/sale/qty", xmlValue)),
      currency = xpathSApply(xmlSales, "//txn/sale/total", xmlGetAttr, "currency"),
      total = as.integer(xpathSApply(xmlSales, "//txn/sale/total", xmlValue)),
      stringsAsFactors = FALSE
    )
    
    # Process new products
    # Find unique products in the current sales batch that aren't already in the product lookup table
    newProducts <- unique(salesDF$product[!salesDF$product %in% names(productLookup)])
    
    # Check if there are any new products identified
    if (length(newProducts) > 0) {
      
      # Create a DataFrame to hold new products for database insertion
      newProductDF <- data.frame(product = newProducts, stringsAsFactors = FALSE)
      
      # Insert the new products into the 'products' table in the database
      dbWriteTable(dbcon, "products", newProductDF, append = TRUE, row.names = FALSE)
      
      # Retrieve the newly added product IDs and names from the database
      # This ensures we get the correct pdtID assigned by the database
      newlyAddedProducts <- dbGetQuery(dbcon, sprintf("SELECT pdtID, product 
                                                         FROM products 
                                                           WHERE product IN ('%s')", 
                                                      paste(newProducts, collapse="','")))
      
      # Update the productLookup table with new product IDs and names for future reference
      # This prevents re-insertion of the same product in subsequent batches
      productLookup <- c(productLookup, setNames(newlyAddedProducts$pdtID, 
                                                 newlyAddedProducts$product))
    }
    
    # Process new customers
    # Identify unique customers in the current sales batch by filtering out those already in the customer lookup table
    uniqueCustomers <- unique(data.frame(customer = salesDF$customer, 
                                         country = salesDF$country), 
                              by = "customer")
    newCustomers <- uniqueCustomers[!uniqueCustomers$customer %in% names(customerLookup),]
    
    # Check if there are any new customers identified
    if (nrow(newCustomers) > 0) {
      
      # Insert the new customers into the 'customers' table in the database
      dbWriteTable(dbcon, "customers", newCustomers, append = TRUE, row.names = FALSE)
      
      # Retrieve the newly added customer IDs and names from the database
      # This step is crucial to map the new customer data with their respective unique IDs in the database
      newlyAddedCustomers <- dbGetQuery(dbcon, sprintf("SELECT cusID, customer 
                                                          FROM customers 
                                                            WHERE customer IN ('%s')", 
                                                       paste(newCustomers$customer, collapse="','")))
      
      # Update the customerLookup table with new customer IDs and names
      # This update is essential to avoid duplicate entries in the subsequent processing of the sales files
      customerLookup <- c(customerLookup, setNames(newlyAddedCustomers$cusID, newlyAddedCustomers$customer))
    }
    
    # Map product and customer IDs for sales data
    salesDF$pdtID <- sapply(salesDF$product, function(p) productLookup[p])
    salesDF$cusID <- sapply(salesDF$customer, function(c) customerLookup[c])
    
    # Format date column
    salesDF$date <- format(salesDF$date, "%Y-%m-%d")
    
    # Flatten the product and customer IDs list and extract only the integer ID
    salesDF$pdtID <- sapply(salesDF$pdtID, `[`, 1)
    salesDF$cusID <- sapply(salesDF$cusID, `[`, 1)
    
    # Insert sales data into database
    dbWriteTable(dbcon, "sales", salesDF[c("pdtID", "repID", "cusID", 
                                           "date","quantity", "currency", 
                                           "total")], append = TRUE, row.names = FALSE)
  }
}


# Function to test whether the tables where populated correctly
testQueries <- function() {
  
  # Test reps table
  repstable <- dbGetQuery(dbcon, "SELECT * FROM reps")
  print("Reps Table")
  print(repstable)
  
  # Test products table
  productstable <- dbGetQuery(dbcon, "SELECT * FROM products")
  print("Products Table")
  print(productstable)
  
  # Test customers table
  customerstable <- dbGetQuery(dbcon, "SELECT * FROM customers")
  print("Customers Table")
  print(customerstable)
  
  # Test sales table
  salestable <- dbGetQuery(dbcon, "SELECT * FROM sales 
                                       WHERE repID = 887 AND cusID = 9 AND pdtID = 8 
                                       LIMIT 10")
  print("Sales Table")
  print(salestable)
  
}

main <- function(){
  # Create the schema
  createSchema()
  
  # Load and extract the data from the XML
  loadAndExtractXML()
  
  # Select test queries
  testQueries()
  
  # Close the database connection
  dbDisconnect(dbcon)
}

main()