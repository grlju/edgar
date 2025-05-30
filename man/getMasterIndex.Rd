% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/getMasterIndex.R
\name{getMasterIndex}
\alias{getMasterIndex}
\title{Retrieves quarterly master index}
\usage{
getMasterIndex(filing.year, useragent)
}
\arguments{
\item{filing.year}{vector of integer containing filing years.}

\item{useragent}{Should be in the form of "YourName Contact@domain.com"}

\item{use_proxy}{Logical. If TRUE, HTTP requests will use a proxy connection.}

\item{proxy_url}{Character. URL of the proxy server. Required if \code{use_proxy = TRUE}.}

\item{proxy_user}{Character. Username for proxy authentication. Required if \code{use_proxy = TRUE}.}

\item{proxy_pass}{Character. Password for proxy authentication. Required if \code{use_proxy = TRUE}.}
}
\value{
Function downloads quarterly master index files and stores them 
into the mentioned directory.
}
\description{
\code{getMasterIndex} retrieves the quarterly master indexes from the U.S. SEC EDGAR server.
}
\details{
getMasterIndex function takes filing year as an input parameter from a user,  
downloads quarterly master indexes from the US SEC server.
www.sec.gov/Archives/edgar/full-index/. It then strips headers from the 
master index files, converts them into dataframe, and 
merges such quarterly dataframes into yearly dataframe, and stores them 
in rds format. It has ability to download master indexes for multiple years 
based on the user input. This function creates a new directory 'edgar_MasterIndex' 
into current working directory to save these rds Master Index. Please note, for 
all other functions in this package need to locate the same working 
directory to access these rds master index files. 
User must follow the US SEC's fair access policy, i.e. download only what you 
need and limit your request rates, see www.sec.gov/os/accessing-edgar-data.
}
\examples{
\dontrun{

useragent <- "YourName Contact@domain.com"

getMasterIndex(2006, useragent) 
## Downloads quarterly master index files for 2006 and 
## stores into yearly 2006master.rds file.

getMasterIndex(c(2006, 2008), useragent) 
## Downloads quarterly master index files for 2006 and 2008, and 
## stores into 2006master.rds and 2008master.rds files.
}
}
