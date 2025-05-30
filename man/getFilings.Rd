% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/getFilings.R
\name{getFilings}
\alias{getFilings}
\title{Retrieves EDGAR filings from SEC server}
\usage{
getFilings(cik.no, form.type, filing.year, quarter, downl.permit, useragent)
}
\arguments{
\item{cik.no}{vector of CIK number of firms in integer format. Suppress leading
zeroes from CIKs. Keep cik.no = 'ALL' if needs to download for all CIKs.}

\item{form.type}{character vector containing form type to be downloaded.
form.type = 'ALL' if need to download all forms.}

\item{filing.year}{vector of four digit numeric year}

\item{quarter}{vector of one digit quarter integer number. By deault, it is kept
as c(1, 2, 3, 4).}

\item{downl.permit}{"y" or "n". The default value of downl.permit is "n". It
asks a user permission to download fillings. This permission helps the user
to decide in case if number of filings are large. Setting downl.permit = "y"
will not ask for user permission to download filings.}

\item{useragent}{Should be in the form of "Your Name Contact@domain.com"}

\item{use_proxy}{Logical. If TRUE, HTTP requests will use a proxy connection.}

\item{proxy_url}{Character. URL of the proxy server. Required if \code{use_proxy = TRUE}.}

\item{proxy_user}{Character. Username for proxy authentication. Required if \code{use_proxy = TRUE}.}

\item{proxy_pass}{Character. Password for proxy authentication. Required if \code{use_proxy = TRUE}.}
}
\value{
Function downloads EDGAR filings and returns download status in dataframe
format with CIK, company name, form type, date filed, accession number, and
download status.
}
\description{
\code{getFilings} retrieves EDGAR filings for a specific CIKs, form-type,
filing year and quarter of the filing.
}
\details{
getFilings function takes CIKs, form type, filing year, and quarter of the
filing as input. It creates new directory "Edgar filings_full text" to
store all downloaded filings. All the filings will be stored in the
current working directory. Keep the same current working directory for
further process. According to SEC EDGAR's guidelines a user also needs to
declare user agent. The progress bar can be controlled with the
\link[progressr]{progressr} package. See in particular
\link[progressr:handlers]{handlers}
}
\examples{
\dontrun{
# if a progress update is desired
library(progressr)
handlers(global = TRUE)

output <- getFilings(cik.no = c(1000180, 38079), c('10-K','10-Q'),
                     2006, quarter = c(1, 2, 3), downl.permit = "n", useragent)

## download '10-Q' and '10-K' filings filed by the firm with
## CIK = 1000180 in quarters 1, 2, and 3 of the year 2006. These
## filings will be stored in the current working directory.

output <- getFilings(cik.no = 1000180, c('10-K','10-Q'),
                     2006, quarter = c(1, 2, 3), downl.permit = "y", useragent)
}
}
