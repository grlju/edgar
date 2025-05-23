% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/getFilingHeader.R
\name{FilingHeaderSubFunc}
\alias{FilingHeaderSubFunc}
\title{Scrape the filer information filing text headers for standard documents}
\usage{
FilingHeaderSubFunc(text, filer.no, period.of.report, ...)
}
\arguments{
\item{text}{the filing text}

\item{filer.no}{the number of the filer, in some cases there are multiple filers
when run as part of the getFilingHeader function, it extracts information for all filers.}

\item{period.of.report}{the reporting period. When run as part of the getFilingHeader
function, it extracts this information from the text of the report}

\item{...}{for passing arguments between functions}
}
\value{
Returns a data.frame with the filing information extracted
}
\description{
Scrape the filer information filing text headers for standard documents
}
