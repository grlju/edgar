#' Retrieves quarterly master index
#'
#' \code{getMasterIndex} retrieves the quarterly master indexes from the U.S. SEC EDGAR server.
#'
#' getMasterIndex function takes filing year as an input parameter from a user,  
#' downloads quarterly master indexes from the US SEC server.
#' www.sec.gov/Archives/edgar/full-index/. It then strips headers from the 
#' master index files, converts them into dataframe, and 
#' merges such quarterly dataframes into yearly dataframe, and stores them 
#' in Rda format. It has ability to download master indexes for multiple years 
#' based on the user input. This function creates a new directory 'edgar_MasterIndex' 
#' into current working directory to save these Rda Master Index. Please note, for 
#' all other functions in this package need to locate the same working 
#' directory to access these Rda master index files. 
#' User must follow the US SEC's fair access policy, i.e. download only what you 
#' need and limit your request rates, see www.sec.gov/os/accessing-edgar-data.
#'     
#' @usage getMasterIndex(filing.year, useragent)
#'
#' @param filing.year vector of integer containing filing years.
#' 
#' @param useragent Should be in the form of "YourName Contact@domain.com"
#' 
#' @return Function downloads quarterly master index files and stores them 
#' into the mentioned directory.
#'   
#' @examples
#' \dontrun{
#' 
#' useragent <- "YourName Contact@domain.com"
#' 
#' getMasterIndex(2006, useragent) 
#' ## Downloads quarterly master index files for 2006 and 
#' ## stores into yearly 2006master.Rda file.
#' 
#' getMasterIndex(c(2006, 2008), useragent) 
#' ## Downloads quarterly master index files for 2006 and 2008, and 
#' ## stores into 2006master.Rda and 2008master.Rda files.
#'}
#' @export
#' @import httr2
#' @importFrom R.utils gunzip

getMasterIndex <- function(filing.year, useragent = NULL) {
  
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
  
  UA <- paste0("Mozilla/5.0 (", useragent, ")")
  
  # function to download file and return FALSE if download error
  # Throttle to 10 request every 1 seconds, current rate limit is 10 requests per 1 second
  # https://www.sec.gov/search-filings/edgar-search-assistance/accessing-edgar-data
  # Retry 20 times on transient errors
  DownloadSECFile <- function(link, dfile, UA) {
    tryCatch({
      req <- request(link) |>
        req_headers(`User-Agent` = UA, Connection = "keep-alive") |>
        req_throttle(capacity = 10, fill_time_s = 1) |>  
        req_retry(max_tries = 20, retry_on_failure = TRUE, is_transient = \(resp) resp_status(resp) %in% c(429, 500, 503)) |>
        req_perform(path = dfile) 
      
      if (resp_status(req) == 200) {
        return(TRUE)
      } else {
        return(FALSE)
      }
    }, error = function(e) {
      return(FALSE)
    })
  }
  
    dir.create("edgar_MasterIndex")
    
    status.array <- data.frame()
    
    for (i in 1:length(filing.year)) {
        
        year <- filing.year[i]
        
        year.master <- data.frame()
        
        quarterloop <- 4
        
        # Find the number of quarters completed in input year
        if (year == format(Sys.Date(), "%Y")) {
            quarterloop <- ceiling(as.integer(format(Sys.Date(), "%m"))/3)
        }
        
        cat("Downloading Master Indexes from SEC server for",year,"\n")
        
        for (quarter in 1:quarterloop) {
          # Save downloaded file as specific name
          dfile <- paste0("edgar_MasterIndex/", year, "QTR", quarter, "master.gz")
          file <- paste0("edgar_MasterIndex/", year, "QTR", quarter, "master")
          
          # Form a link to download master file
          link <- paste0("https://www.sec.gov/Archives/edgar/full-index/", year, "/QTR", quarter, "/master.gz")
          
          ### Download the file
          res <- DownloadSECFile(link, dfile, UA)
          
          if (res) {
            # Unzip gz file
            R.utils::gunzip(dfile, destname = file, temporary = FALSE, skip = FALSE, overwrite = TRUE, remove = FALSE)
            
            # Removing ''' so that scan with '|' does not fail due to occurrence of ''' in company name
            raw.data <- readLines(file)
            raw.data <- iconv(raw.data, "latin1", "ASCII", sub = "")
            raw.data <- gsub("'", "", raw.data)
            
            # Find line number where header description ends
            header.end <- grep("--------------------------------------------------------", raw.data)
            
            # Write back to storage
            writeLines(raw.data, file)
            
            # Read the file into a data frame
            scraped.data <- scan(file, what = list("", "", "", "", ""), flush = FALSE, skip = header.end, sep = "|", quiet = TRUE)
            
            # Remove punctuation characters from company names
            company.name <- gsub("[[:punct:]]", " ", scraped.data[[2]], perl = TRUE)
            
            # Create final data frame
            final.data <- data.frame(
              cik = scraped.data[[1]],
              company.name = company.name,
              form.type = scraped.data[[3]],
              date.filed = scraped.data[[4]],
              edgar.link = scraped.data[[5]],
              quarter = quarter
            )
            
            # Append to year.master
            year.master <- rbind(year.master, final.data)
            
            # Remove the unzipped file
            file.remove(file)
            
            # Update status array
            status.array <- rbind(status.array, data.frame(
              Filename = paste0(year, ": quarter-", quarter),
              status = "Download success"
            ))
            
            cat("Master Index for quarter", quarter, "downloaded successfully\n")
          } else {
            # Update status array for server error
            status.array <- rbind(status.array, data.frame(
              Filename = paste0(year, ": quarter-", quarter),
              status = "Server Error"
            ))
            
            cat("Master Index for quarter", quarter, "failed to download\n")
          }
        }
        
        assign(paste0(year, "master"), year.master)
        save(year.master, file = paste0("edgar_MasterIndex/", year, "master.Rda"))
      }
}
