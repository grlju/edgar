#' Get HTML view of EDGAR filings
#'
#' \code{getFilingsHTML} retrieves complete EDGAR filings and store them in
#' HTML format for view.
#'
#' getFilingsHTML function takes CIK(s), form type(s), filing year(s), and quarter of the
#' filing as input. The function imports edgar filings downloaded
#' via \link[edgar]{getFilings} function; otherwise, it downloads the filings which are
#' not already been downloaded. It then reads the downloaded filings, scraps filing text
#' excluding exhibits, and saves the filing contents in 'edgar_FilingsHTML'
#' directory in HTML format. The new directory 'edgar_FilingsHTML' will be
#' automatically created by this function.
#' User must follow the US SEC's fair access policy, i.e. download only what you
#' need and limit your request rates, see www.sec.gov/os/accessing-edgar-data.
#'
#' @usage getFilingsHTML(cik.no, form.type, filing.year, quarter, useragent)
#'
#' @param cik.no vector of CIK number of firms in integer format. Suppress leading
#' zeroes from CIKs. Keep cik.no = 'ALL' if needs to download for all CIKs.
#'
#' @param form.type character vector containing form type to be downloaded.
#' form.type = 'ALL' if need to download all forms.
#'
#' @param filing.year vector of four digit numeric year
#'
#' @param quarter vector of one digit quarter integer number. By default, it is kept
#' as c(1 ,2, 3, 4).
#'
#' @param useragent Should be in the form of "YourName Contact@domain.com"
#'
#' @return Function saves EDGAR filings in HTML format and returns filing information
#' in dataframe format.
#'
#' @examples
#' \dontrun{
#'
#' output <- getFilingsHTML(cik.no = c(1000180, 38079), c('10-K','10-Q'),
#'                          2006, quarter = c(1, 2, 3), useragent)
#'
#' ## download '10-Q' and '10-K' filings filed by the firm with
#' ## CIK = 1000180 in quarters 1,2, and 3 of the year 2006. These filings
#' ## will be stored in the current working directory.
#'
#' }
#' @export
#' @import utils
#' @importFrom progressr progressor handlers
#' @importFrom future.apply future_lapply


getFilingsHTML <- function(cik.no = "ALL",
                           form.type = "ALL",
                           filing.year,
                           quarter = c(1, 2, 3, 4),
                           useragent = NULL) {
  options(warn = -1)
  
  ### Check for valid user agent
  if (is.null(useragent)) {
    stop(
      "You must provide a valid 'useragent' in the form of 'Your Name Contact@domain.com'.
       Visit https://www.sec.gov/os/accessing-edgar-data for more information"
    )
  }
  if (!is.numeric(filing.year)) {
    stop("Input year(s) is not numeric.")
  }
  
  ### Download filings
  output <- getFilings(
    cik.no = cik.no,
    form.type ,
    filing.year,
    quarter = c(1, 2, 3, 4),
    downl.permit = "y",
    useragent
  )
  
  if (is.null(output)) {
    stop(
      "No filing information found for given CIK(s) and Form Type in the mentioned year(s)/quarter(s).\n"
    )
  }
  
  cat("Scrapping full EDGAR and converting to HTML\n")
  
  p <- progressr::progressor(along = 1:nrow(output))
  
  dir.create("edgar_FilingsHTML")
  
  results <- future.apply::future_lapply(
    X = 1:nrow(output),
    FUN = function(i) {
      f.type <- gsub("/", "", output$form.type[i])
      year <- output$filing.year[i]
      cik <- output$cik[i]
      date.filed <- output$date.filed[i]
      accession.number <- output$accession.number[i]
      
      dest.filename <- paste0(
        "edgar_Filings/Form ",
        f.type,
        "/",
        cik,
        "/",
        cik,
        "_",
        f.type,
        "_",
        date.filed,
        "_",
        accession.number,
        ".txt"
      )
      # Read filing
      filing.text <- readLines(dest.filename)
      
      # Extract data from first <TEXT> to </TEXT> or <DOCUMENT> to </DOCUMENT>
      tryCatch({
        filing.text <- filing.text[(grep("<DOCUMENT>|<TEXT>", filing.text, ignore.case = TRUE)[1]):(grep("</DOCUMENT>|</TEXT>", filing.text, ignore.case = TRUE)[1])]
      }, error = function(e) {
        filing.text <- filing.text ## In case opening and closing TEXT TAG not found, consider full web page
      })
      
      
      if (any(!grepl(pattern = '<html|<!DOCTYPE html|<xml|<type>xml|10k.htm|<XBRL', filing.text, ignore.case =
                     TRUE))) {
        filing.text <- gsub("\t", " ", filing.text)
        filing.text <- gsub("<CAPTION>|<S>|<C>", "", filing.text, ignore.case = T)
        ## Append with PRE to keep the text format as it is
        filing.text <- c("<PRE style='font-size: 15px'>", filing.text, "</PRE>")
      }
      
      ## Form new dir and filename
      new.dir <- paste0("edgar_FilingsHTML/Form ", f.type)
      dir.create(new.dir)
      new.dir2 <- paste0(new.dir, "/", cik)
      dir.create(new.dir2)
      
      dest.filename2 <- paste0(
        new.dir2,
        "/",
        cik,
        "_",
        f.type,
        "_",
        output$date.filed[i],
        "_",
        output$accession.number[i],
        ".html"
      )
      
      ## Writing filing text to html file
      writeLines(filing.text, dest.filename2)
      
      p()
      
    }
  )
  
  ## convert dates into R dates
  output$date.filed <- as.Date(as.character(output$date.filed), "%Y-%m-%d")
  
  output$quarter <- NULL
  output$filing.year <- NULL

  cat("HTML filings are stored in 'edgar_FilingsHTML' directory.")
  
  return(output)
}
