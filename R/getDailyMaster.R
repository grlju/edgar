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
#' @return Function returns filings information in a dataframe format.
#'
#' @examples
#' \dontrun{
#'
#' output <- getDailyMaster('08/09/2016', useragent)
#'}
#' @export
#' @import httr2

getDailyMaster <- function(input.date, useragent = NULL) {
  
  getMasterIndex(2006, useragent)
  
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
  # function to download file and return FALSE if download error
  # Throttle to 10 request every 1 seconds, current rate limit is 10 requests per 1 second
  # https://www.sec.gov/search-filings/edgar-search-assistance/accessing-edgar-data
  # Retry 20 times on transient errors
  DownloadSECFile <- function(link, dfile, UA) {
    tryCatch({
      req <- request(link) |>
        req_headers(`User-Agent` = UA, Connection = "keep-alive") |>
        req_throttle(capacity = 10, fill_time_s = 1) |>
        req_retry(
          max_tries = 20,
          retry_on_failure = TRUE,
          is_transient = \(resp) resp_status(resp) %in% c(429, 500, 503)
        ) |>
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
  date <- paste0(year, month, day)
  
  filename <- paste0("edgar_DailyMaster/daily_idx_", date)
  
  if(file.exists(paste0(filename, ".Rda"))) {
    load(paste0(filename, ".Rda"))
    return(final.data)
  } else {
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
      
      down.success = FALSE
      if (year < 1999) {
        down.success <- DownloadSECFile(link3, filename, UA)
      }
      
      if (year > 1998 && year < 2012) {
        down.success <- DownloadSECFile(link4, filename, UA)
      }
      
      if (year > 2011) {
        fun.return1 <- DownloadSECFile(link1, filename, UA)
        if (fun.return1 && file.size(filename) > 500) {
          down.success = TRUE
          
        } else {
          fun.return2 <- DownloadSECFile(link2, filename, UA)
          if (fun.return2) {
            down.success = TRUE
          }
        }
      }
      
      if (down.success) {
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
        save(final.data, file = paste0(filename, ".Rda"))
        
        return(final.data)
      } else{
        stop(" Daily master index is not availbale for this date.")
      }
    }
    ## Call above GetDailyInfo function
    return(GetDailyInfo(day, month, year))
  }
}
globalVariables("final.data")