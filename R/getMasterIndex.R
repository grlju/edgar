#' Retrieves quarterly master index
#'
#' \code{getMasterIndex} retrieves the quarterly master indexes from the U.S. SEC EDGAR server.
#'
#' getMasterIndex function takes filing year as an input parameter from a user,  
#' downloads quarterly master indexes from the US SEC server.
#' www.sec.gov/Archives/edgar/full-index/. It then strips headers from the 
#' master index files, converts them into dataframe, and 
#' merges such quarterly dataframes into yearly dataframe, and stores them 
#' in rds format. It has ability to download master indexes for multiple years 
#' based on the user input. This function creates a new directory 'edgar_MasterIndex' 
#' into current working directory to save these rds Master Index. Please note, for 
#' all other functions in this package need to locate the same working 
#' directory to access these rds master index files. 
#' User must follow the US SEC's fair access policy, i.e. download only what you 
#' need and limit your request rates, see www.sec.gov/os/accessing-edgar-data.
#'     
#' @usage getMasterIndex(filing.year, useragent)
#'
#' @param filing.year vector of integer containing filing years.
#' 
#' @param useragent Should be in the form of "YourName Contact@domain.com"
#' 
#' @param use_proxy Logical. If TRUE, HTTP requests will use a proxy connection.
#' 
#' @param proxy_url Character. URL of the proxy server. Required if \code{use_proxy = TRUE}.
#' 
#' @param proxy_user Character. Username for proxy authentication. Required if \code{use_proxy = TRUE}.
#' 
#' @param proxy_pass Character. Password for proxy authentication. Required if \code{use_proxy = TRUE}.
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
#' ## stores into yearly 2006master.rds file.
#' 
#' getMasterIndex(c(2006, 2008), useragent) 
#' ## Downloads quarterly master index files for 2006 and 2008, and 
#' ## stores into 2006master.rds and 2008master.rds files.
#'}
#' @export
#' @import httr2
#' @importFrom R.utils gunzip

getMasterIndex <- function(filing.year, 
                           useragent = NULL, 
                           use_proxy = FALSE,
                           proxy_url = NULL,
                           proxy_user = NULL,
                           proxy_pass = NULL
                           ) 
  {
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
  
  # check if use proxy is provided
  if (use_proxy) {
    if (is.null(proxy_url) || is.null(proxy_user) || is.null(proxy_pass)) {
      stop("When 'use_proxy = TRUE', 'proxy_url', 'proxy_user', and 'proxy_pass' must all be provided.")
    }
  }
  
  # function to download file and return FALSE if download error
  # Throttle to 10 requests every 1 second (current SEC rate limit is 10 per second)
  # Retry 20 times on transient errors (429, 500, 503)
  DownloadSECFile <- function(link, dfile, UA, use_proxy, proxy_url, proxy_user, proxy_pass) {
    tryCatch({
      req <- httr2::request(link) |>
        httr2::req_headers(`User-Agent` = UA, Connection = "keep-alive") |>
        httr2::req_throttle(capacity = 10, fill_time_s = 1) |>
        httr2::req_retry(
          max_tries = 20,
          retry_on_failure = TRUE,
          is_transient = \(resp) resp_status(resp) %in% c(429, 500, 503),
          backoff = function(attempt) min(60, 2 ^ attempt), 
          failure_threshold = 10
        )
      # Apply proxy if requested
      if (use_proxy) {
        req <- req |> httr2::req_proxy(url = proxy_url, username = proxy_user, password = proxy_pass)
      }
      httr2::req_perform(req, path = dfile)
    }, error = function(e) {
      return(FALSE)
    })
    if (file.exists(dfile) && file.info(dfile)$size > 0) {
      return(TRUE)
    } else {
      return(FALSE)
    }
  }
  
    dir.create("edgar_MasterIndex", showWarnings = FALSE)

    status.array <- data.frame()
    
    for (year in filing.year) {
        
      rdsfile_year <- paste0("edgar_MasterIndex/", year, "master.rds")
      
      # Skip entire year if RDS already exists
      if (file.exists(rdsfile_year)) {
        cat("Master Index for year", year, "already exists (RDS file found)\n")
        next
      }
      
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
          
          # Skip download if the file already exists
          if (file.exists(dfile)) {
            cat("Master Index for quarter", quarter, "already exists\n")
            next
          }
          
          ### Download the file
          res <- DownloadSECFile(link, dfile, UA, use_proxy, proxy_url, proxy_user, proxy_pass)
          
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
        saveRDS(year.master, file = paste0("edgar_MasterIndex/", year, "master.rds"))
      }
}
