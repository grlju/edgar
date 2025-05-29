#' Retrieves EDGAR filings from SEC server
#'
#' \code{getFilings} retrieves EDGAR filings for a specific CIKs, form-type,
#' filing year and quarter of the filing.
#'
#' getFilings function takes CIKs, form type, filing year, and quarter of the
#' filing as input. It creates new directory "Edgar filings_full text" to
#' store all downloaded filings. All the filings will be stored in the
#' current working directory. Keep the same current working directory for
#' further process. According to SEC EDGAR's guidelines a user also needs to
#' declare user agent. The progress bar can be controlled with the
#' \link[progressr]{progressr} package. See in particular
#' \link[progressr:handlers]{handlers}
#'
#' @usage getFilings(cik.no, form.type, filing.year, quarter, downl.permit, useragent)
#'
#' @param cik.no vector of CIK number of firms in integer format. Suppress leading
#' zeroes from CIKs. Keep cik.no = 'ALL' if needs to download for all CIKs.
#'
#' @param form.type character vector containing form type to be downloaded.
#' form.type = 'ALL' if need to download all forms.
#'
#' @param filing.year vector of four digit numeric year
#'
#' @param quarter vector of one digit quarter integer number. By deault, it is kept
#' as c(1, 2, 3, 4).
#'
#' @param downl.permit "y" or "n". The default value of downl.permit is "n". It
#' asks a user permission to download fillings. This permission helps the user
#' to decide in case if number of filings are large. Setting downl.permit = "y"
#' will not ask for user permission to download filings.
#'
#' @param useragent Should be in the form of "Your Name Contact@domain.com"
#'
#' @param use_proxy Logical. If TRUE, HTTP requests will use a proxy connection.
#' 
#' @param proxy_url Character. URL of the proxy server. Required if \code{use_proxy = TRUE}.
#' 
#' @param proxy_user Character. Username for proxy authentication. Required if \code{use_proxy = TRUE}.
#' 
#' @param proxy_pass Character. Password for proxy authentication. Required if \code{use_proxy = TRUE}.
#' 
#' @return Function downloads EDGAR filings and returns download status in dataframe
#' format with CIK, company name, form type, date filed, accession number, and
#' download status.
#'
#' @examples
#' \dontrun{
#' # if a progress update is desired
#' library(progressr)
#' handlers(global = TRUE)
#'
#' output <- getFilings(cik.no = c(1000180, 38079), c('10-K','10-Q'),
#'                      2006, quarter = c(1, 2, 3), downl.permit = "n", useragent)
#'
#' ## download '10-Q' and '10-K' filings filed by the firm with
#' ## CIK = 1000180 in quarters 1, 2, and 3 of the year 2006. These
#' ## filings will be stored in the current working directory.
#'
#' output <- getFilings(cik.no = 1000180, c('10-K','10-Q'),
#'                      2006, quarter = c(1, 2, 3), downl.permit = "y", useragent)
#'}
#' @export
#' @import httr2
#' @importFrom R.utils gunzip
#' @importFrom progressr progressor handlers

getFilings <- function(
    cik.no = "ALL",
    form.type = "ALL",
    filing.year,
    quarter = c(1, 2, 3, 4),
    downl.permit = "n",
    useragent = NULL,
    use_proxy = FALSE,
    proxy_url = NULL,
    proxy_user = NULL,
    proxy_pass = NULL
) {
  options(warn = -1)
  
  # Validate user agent
  if (is.null(useragent)) {
    stop(
      "You must provide a valid 'useragent' in the form of 'Your Name Contact@domain.com'.\n",
      "Visit https://www.sec.gov/os/accessing-edgar-data for more information"
    )
  }
  if (!is.numeric(filing.year)) {
    stop("Input year(s) is not numeric.")
  }
  
  UA <- paste0("Mozilla/5.0 (", useragent, ")")
  
  if (use_proxy) {
    if (is.null(proxy_url) || is.null(proxy_user) || is.null(proxy_pass)) {
      stop("When 'use_proxy = TRUE', 'proxy_url', 'proxy_user', and 'proxy_pass' must all be provided.")
    }
  }
  
  # Define file download function
  DownloadSECFile <- function(link, dfile, UA, use_proxy, proxy_url, proxy_user, proxy_pass) {
    is_transient_custom <- function(resp) {
      status <- httr2::resp_status(resp)
      if (status %in% c(429, 500, 503)) return(TRUE)
      if (status == 200) {
        content <- tryCatch(httr2::resp_body_string(resp), error = function(e) "")
        return(grepl("Undeclared Automated Tool|Request Rate Threshold", content, ignore.case = TRUE))
      }
      return(FALSE)
    }
    
    req <- httr2::request(link) |>
      httr2::req_headers(`User-Agent` = UA, Connection = "keep-alive") |>
      httr2::req_timeout(seconds = 30) |>
      httr2::req_throttle(capacity = 10, fill_time_s = 1) |>
      httr2::req_retry(
        max_tries = 20,
        retry_on_failure = TRUE,
        is_transient = is_transient_custom,
        backoff = function(attempt) min(60, 2 ^ attempt),
        failure_threshold = 10
      )
    
    if (use_proxy) {
      req <- req |> httr2::req_proxy(url = proxy_url, username = proxy_user, password = proxy_pass)
    }
    
    result <- tryCatch({
      httr2::req_perform(req, path = dfile)
      TRUE
    }, error = function(e) FALSE)
    
    if (!result || !file.exists(dfile) || file.info(dfile)$size == 0) return(FALSE)
    
    first_lines <- tryCatch(readLines(dfile, n = 10, warn = FALSE), error = function(e) character(0))
    if (any(grepl("Your Request Originates from an Undeclared Automated Tool|Request Rate Threshold Exceeded", first_lines))) {
      file.remove(dfile)
      return(FALSE)
    }
    
    return(TRUE)
  }
  
  # Prepare master index
  index.df <- data.frame()
  for (year in filing.year) {
    yr.master <- paste0(year, "master.rds")
    filepath <- file.path("edgar_MasterIndex", yr.master)
    
    if (!file.exists(filepath)) {
      getMasterIndex(year, useragent)
    }
    
    year.master <- readRDS(filepath)
    types <- if (length(form.type) == 1 && form.type == "ALL") unique(year.master$form.type) else form.type
    
    subset <- year.master[
      year.master$form.type %in% types &
        year.master$quarter %in% quarter &
        (cik.no == "ALL" | year.master$cik %in% cik.no),
    ]
    if (nrow(subset) > 0) {
      subset$filing.year <- year
      index.df <- rbind(index.df, subset)
    }
  }
  
  if (nrow(index.df) == 0) {
    stop("No filing information found for given CIK(s)/Form Type in the specified year(s)/quarter(s).\n")
  }
  
  index.df <- index.df[order(index.df$cik, index.df$filing.year), ]
  
  # Generate accession number and destination file paths in parallel
  index.df$edgar.link <- as.character(index.df$edgar.link)
  accessions <- sapply(strsplit(index.df$edgar.link, "/"), `[`, 4)
  index.df$accession.number <- sub("\\.txt$", "", accessions)
  
  # Parallel path construction
  index.df$destfile <- future.apply::future_mapply(function(cik, ftype, date, acc) {
    ftype_clean <- gsub("/", "", ftype)
    destdir <- file.path("edgar_Filings", paste0("Form ", ftype_clean), cik)
    file.path(destdir, sprintf("%s_%s_%s_%s.txt", cik, ftype_clean, date, acc))
  }, cik = index.df$cik, ftype = index.df$form.type, date = index.df$date.filed, acc = index.df$accession.number,
  SIMPLIFY = TRUE, USE.NAMES = FALSE)
  
  # Identify which files already exist
  index.df$file_exists <- file.exists(index.df$destfile)
  missing.df <- index.df[!index.df$file_exists, ]
  
  # Prompt user only if new files need downloading
  if (nrow(missing.df) == 0) {
    message("All requested filings already exist. No download needed.")
    index.df$status <- "Already exists"
    return(index.df)
  } else {
    msg3 <- sprintf("Total filings to download = %d. Proceed? (y/n): ", nrow(missing.df))
    if (tolower(downl.permit) == "n") {
      downl.permit <- readline(prompt = msg3)
    }
    if (tolower(downl.permit) != "y") {
      message("Download cancelled by user.")
      index.df$status <- ifelse(index.df$file_exists, "Already exists", "Skipped")
      return(index.df)
    }
  }
  
  # Download only missing files
  progressr::with_progress({
    p <- progressr::progressor(along = seq_len(nrow(missing.df)))
    missing.df$status <- NA_character_
    
    for (i in seq_len(nrow(missing.df))) {
      row <- missing.df[i, ]
      destdir <- dirname(row$destfile)
      dir.create(destdir, recursive = TRUE, showWarnings = FALSE)
      
      edgar.link <- paste0("https://www.sec.gov/Archives/", row$edgar.link)
      res <- DownloadSECFile(edgar.link, row$destfile, UA, use_proxy, proxy_url, proxy_user, proxy_pass)
      missing.df$status[i] <- if (res) "Download success" else "Download error"
      p()
    }
  })
  
  # Update status in full data frame
  index.df$status <- ifelse(index.df$file_exists, "Already exists", NA_character_)
  index.df$status[match(missing.df$destfile, index.df$destfile)] <- missing.df$status
  
  return(index.df)
}