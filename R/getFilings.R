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
  
  ### Check for valid user agent
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
  
  # check if use proxy is provided
  if (use_proxy) {
    if (is.null(proxy_url) || is.null(proxy_user) || is.null(proxy_pass)) {
      stop("When 'use_proxy = TRUE', 'proxy_url', 'proxy_user', and 'proxy_pass' must all be provided.")
    }
  }
  
  # function to download file and return FALSE if download error
  # Throttle to 10 requests every 2 second (current SEC rate limit is 10 per second)
  # Retry 20 times on transient errors (429, 500, 503)
  DownloadSECFile <- function(link, dfile, UA, use_proxy, proxy_url, proxy_user, proxy_pass) {
    tryCatch({
      req <- httr2::request(link) |>
        httr2::req_headers(`User-Agent` = UA, Connection = "keep-alive") |>
        httr2::req_throttle(capacity = 10, fill_time_s = 2) |>
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
  
  # Initialize master index storage
  index.df <- data.frame()
  
  # Loop through each requested year
  for (year in filing.year) {
    yr.master <- paste0(year, "master.Rda")
    filepath <- file.path("edgar_MasterIndex", yr.master)
    
    if (!file.exists(filepath)) {
      getMasterIndex(year, useragent)
    }
    load(filepath)
    
    # Filter by form type and CIK
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
  
  # Prompt for download
  total.files <- nrow(index.df)
  msg3 <- sprintf(
    "Total filings to download = %d. Proceed? (y/n): ",
    total.files
  )
  if (tolower(downl.permit) == "n") {
    downl.permit <- readline(prompt = msg3)
  }
  
  if (tolower(downl.permit) == "y") {
    dir.create("edgar_Filings", showWarnings = FALSE)
    p <- progressr::progressor(along = seq_len(total.files))
    
    # Prepare file destinations
    index.df$edgar.link <- as.character(index.df$edgar.link)
    accessions <- sapply(strsplit(index.df$edgar.link, "/"), `[`, 4)
    index.df$accession.number <- sub("\\.txt$", "", accessions)
    index.df$status <- NA_character_
    
    cat("Downloading filings...")
    for (i in seq_len(total.files)) {
      edgar.link <- paste0("https://www.sec.gov/Archives/", index.df$edgar.link[i])
      ftype <- gsub("/", "", index.df$form.type[i])
      cik <- index.df$cik[i]
      date <- index.df$date.filed[i]
      acc <- index.df$accession.number[i]
      
      destdir <- file.path("edgar_Filings", paste0("Form ", ftype), cik)
      dir.create(destdir, recursive = TRUE, showWarnings = FALSE)
      destfile <- file.path(destdir, sprintf(
        "%s_%s_%s_%s.txt",
        cik, ftype, date, acc
      ))
      
      if (file.exists(destfile)) {
        index.df$status[i] <- "Download success"
      } else {
        res <- DownloadSECFile(edgar.link, destfile, UA, use_proxy, proxy_url, proxy_user, proxy_pass)
        if (res) {
          index.df$status[i] <- "Download success"
        } else {
          index.df$status[i] <- "Download Error"
        }
      }
      p()
    }
    return(index.df)
  }
}