#' Retrieves daily master index
#'
#' \code{getDailyMaster} retrieves daily master index from the U.S. SEC EDGAR server.
#'
#' getDailyMaster function takes date as an input parameter from a user,
#' and downloads master index for the date from the U.S. SEC EDGAR server
#' www.sec.gov/Archives/edgar/daily-index/. It strips headers
#' and converts this daily filing information into dataframe format.
#' Function creates new directory 'edgar_DailyMaster' into working directory
#' to save these downloaded daily master index files in Rda format.
#' User must follow the US SEC's fair access policy, i.e. download only what you
#' need and limit your request rates, see www.sec.gov/os/accessing-edgar-data.
#'
#' @usage getDailyMaster(input.date, useragent)
#'
#' @param input.date in character format 'mm/dd/YYYY'.
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

#' @return Function returns filings information in a dataframe format.
#'
#' @examples
#' \dontrun{
#'
#' output <- getDailyMaster('08/09/2016', useragent)
#'}
#' @export
#' @import httr2

getDailyMaster <- function(input.date, 
                           useragent = NULL,
                           use_proxy = FALSE,
                           proxy_url = NULL,
                           proxy_user = NULL,
                           proxy_pass = NULL) {
  
  dir.create("edgar_DailyMaster")
  
  input.date <- as.Date(input.date, "%m/%d/%Y")
  
  if (is.na(input.date)) {
    stop("Malformed input date. The input date format must be '%m/%d/%Y'")
  }
  
  if (Sys.Date() < input.date) {
    stop("Check the input date, it cannot be after todays date")
  }
  
  year <- format(input.date, "%Y")
  month <- format(input.date, "%m")
  day <- format(input.date, "%d")
  
  options(warn = -1)  # remove warnings
  
  ### Check for valid user agent
  if (is.null(useragent)) {
    stop(
      "You must provide a valid 'useragent' in the form of 'Your Name Contact@domain.com'.
       Visit https://www.sec.gov/os/accessing-edgar-data for more information"
    )
  }
  
  UA <- paste0("Mozilla/5.0 (", useragent, ")")
  
  # function to download file and return FALSE if download error
  # Throttle to 10 requests every 2 second (current SEC rate limit is 10 per second)
  # Retry 20 times on transient errors (429, 500, 503)
  DownloadSECFile <- function(link, dfile, UA, use_proxy, proxy_url, proxy_user, proxy_pass) {
    tryCatch({
      
      # Set throttle parameters based on proxy usage
      if (use_proxy) {
        # Faster throttle when using proxy (since each proxy is isolated) but still keeping it reasonable
        throttle_capacity <- 20   # higher burst capacity
        throttle_fill_time <- 1   # faster refill rate
      } else {
        # Slower throttle for single-IP use
        throttle_capacity <- 10
        throttle_fill_time <- 2
      }
      
      req <- httr2::request(link) |>
        httr2::req_headers(`User-Agent` = UA, Connection = "keep-alive") |>
        httr2::req_throttle(capacity = throttle_capacity, fill_time_s = throttle_fill_time) |>
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
  
  # function for downloading daily Index
  GetDailyInfo <- function(day, month, year) {
    link1 <- paste0(
      "https://www.sec.gov/Archives/edgar/daily-index/",
      year,
      "/QTR",
      ceiling(as.integer(month) / 3),
      "/master.",
      date,
      ".idx"
    )
    
    link2 <- paste0(
      "https://www.sec.gov/Archives/edgar/daily-index/",
      year,
      "/QTR",
      ceiling(as.integer(month) / 3),
      "/master.",
      date,
      ".idx"
    )
    
    link3 <- paste0(
      "https://www.sec.gov/Archives/edgar/daily-index/",
      year,
      "/QTR",
      ceiling(as.integer(month) / 3),
      "/master.",
      substr(as.character(year), 3, 4),
      month,
      day,
      ".idx"
    )
    
    link4 <- paste0(
      "https://www.sec.gov/Archives/edgar/daily-index/",
      year,
      "/QTR",
      ceiling(as.integer(month) / 3),
      "/master.",
      date,
      ".idx"
    )
    
    if (year < 1999) {
      res <- DownloadSECFile(link3, filename, UA, use_proxy, proxy_url, proxy_user, proxy_pass)
    }
    
    if (year > 1998 && year < 2012) {
      res <- DownloadSECFile(link4, filename, UA, use_proxy, proxy_url, proxy_user, proxy_pass)
    }
    
    if (year > 2011) {
      res <- DownloadSECFile(link1, filename, UA, use_proxy, proxy_url, proxy_user, proxy_pass)
      if (!isTRUE(res)) {
        res <- DownloadSECFile(link2, filename, UA, use_proxy, proxy_url, proxy_user, proxy_pass)
      }
    }
    
    if (res) {
      # Removing ''' so that scan with '|' not fail due to occurrence of ''' in company name
      temp.data <- gsub("'", "", readLines(filename))
      temp.data <- iconv(temp.data, "latin1", "ASCII", sub = "")
      
      # writting back to storage
      writeLines(temp.data, filename)
      
      # Find line number where header description ends
      header.end <- grep("--------------------------------------------------------",
                         temp.data)
      
      scrapped.data <- scan(
        filename,
        what = list("", "", "", "", ""),
        flush = F,
        skip = header.end,
        sep = "|",
        quiet = T
      )
      
      final.data <- data.frame(
        cik = scrapped.data[[1]],
        company.name = scrapped.data[[2]],
        form.type = scrapped.data[[3]],
        date.filed = as.Date(scrapped.data[[4]], "%Y%m%d"),
        edgar.link = scrapped.data[[5]]
      )
      
      ## Save daily master index in Rda format
      file.remove(filename)
      saveRDS(final.data, file = paste0(filename, ".rds"))
      
      return(final.data)
    } else{
      stop(" Daily master index is not availbale for this date.")
    }
  }
  
  date <- paste0(year, month, day)
  
  filename <- paste0("edgar_DailyMaster/daily_idx_", date)
  
  if(file.exists(paste0(filename, ".rds"))) {
    final.data <- readRDS(paste0(filename, ".rds"))
    return(final.data)
  } else {
    ## Call above GetDailyInfo function
    final.data <- GetDailyInfo(day, month, year)
    return(final.data)
  }
}
globalVariables("final.data")