#' Search EDGAR filings for specific keywords
#'
#' \code{searchFilings} Search EDGAR filings for specific keywords
#'
#' searchFilings function takes search keyword vector, CIK(s), form type(s), and
#' year(s) as input parameters. The function first imports available
#' downloaded filings in the local woking directory
#' 'edgar_Filings' created by \link[edgar]{getFilings} function;
#' otherwise, it automatically downloads the filings which are not already been
#' downloaded. It then reads the filings and searches for the input keywords.
#' The function returns a dataframe with filing information and the number of
#' keyword hits. Additionally, it saves the search information with surrounding
#' content of search keywords in HTML format in the new directory
#' "edgar_searchFilings". These HTML view of search results would help the user
#' to analyze the search strategy and identify false positive hits.
#' User must follow the US SEC's fair access policy, i.e. download only what you
#' need and limit your request rates, see www.sec.gov/os/accessing-edgar-data.
#'
#' @usage searchFilings(cik.no, form.type, filing.year, word.list, useragent)
#'
#' @param cik.no vector of CIK number of firms in integer format. Suppress leading
#' zeroes from CIKs. Keep cik.no = 'ALL' if needs to download for all CIK's.
#'
#' @param form.type character vector containing form type to be downloaded.
#' form.type = 'ALL' if need to download all forms.
#'
#' @param filing.year vector of four digit numeric year
#'
#' @param word.list vector of words to search in the filing
#'
#' @param useragent Should be in the form of "Your Name Contact@domain.com"
#'
#' @return Function returns dataframe containing filing information and the
#' number of word hits based on the input phrases. Additionally, this
#' function saves search information with surrounding content of
#' search keywords in HTML file in directory "Keyword search results".
#' @examples
#' \dontrun{
#'
#' word.list = c('derivative','hedging','currency forwards','currency futures')
#' output <- searchFilings(cik.no = c('1000180', '38079'),
#'                      form.type = c("10-K", "10-K405","10KSB", "10KSB40"),
#'                      filing.year = c(2005, 2006), word.list, useragent)
#'}
#' @export
#' @importFrom XML htmlParse xpathSApply xmlValue
#' @importFrom progressr progressor handlers
#' @importFrom future.apply future_lapply

searchFilings <- function(cik.no,
                          form.type,
                          filing.year,
                          word.list,
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
  
  output <- getFilings(
    cik.no,
    form.type,
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
  
  cat("Searching filings for the input words\n")
  
  p <- progressr::progressor(along = 1:nrow(output))
  
  output$nword.hits <- NA
  
  ### Search for word list
  count_func <- function(word, text) {
    occur <- unlist(gregexpr(word, text, ignore.case = T))
    
    if (occur[1] != -1) {
      return(length(occur))
    } else {
      return(0)
    }
  }
  
  extract_text <- function (text, word.list) {
    extract.text.highl <- ""
    
    for (w in 1:length(word.list)) {
      word <- word.list[w]
      
      regex_word <- paste0(".{1,255}", word, ".{1,255}")
      extract.text <- regmatches(text, gregexpr(regex_word, text, ignore.case = T))
      extract.text <- unlist(extract.text)
      
      # regex_word <- paste0("(?:[^\\s]+\\s){5,50}", word,"[\\.\\-\\*\\(\\)]?(\\s{0,}[^\\s]+){5,50}")
      # extract.text <- stringr::str_extract_all(text,
      #                                          stringr::regex(regex_word, ignore_case = T))
      highlight.word <- paste0("<mark><b>", word, "</b></mark>")
      text.highl <- gsub(word, highlight.word, extract.text, ignore.case = T)
      extract.text.highl <- c(extract.text.highl, text.highl)
    }
    
    extract.text.highl <- extract.text.highl[-1]
    return(extract.text.highl)
  }
  
  new.dir <- "edgar_searchFilings"
  dir.create(new.dir)
  
  results <- future.apply::future_lapply(
    X = 1:nrow(output),
    FUN = function(i) {
      f.type <- gsub("/", "", output$form.type[i])
      year <- output$filing.year[i]
      cname <- gsub("\\s{2,}", " ", output$company.name[i])
      cik <- output$cik[i]
      date.filed <- output$date.filed[i]
      accession.number <- output$accession.number[i]
      
      dest.filename <- paste0(
        "edgar_Filings/Form ",
        f.type,
        "/",
        output$cik[i],
        "/",
        output$cik[i],
        "_",
        f.type,
        "_",
        output$date.filed[i],
        "_",
        output$accession.number[i],
        ".txt"
      )
      
      # Read filing
      filing.text <- readLines(dest.filename)
      
      # Extract data from first <DOCUMENT> to </DOCUMENT>
      tryCatch({
        filing.text <- filing.text[(grep("<DOCUMENT>|<TEXT>", filing.text, ignore.case = TRUE)[1]):(grep("</DOCUMENT>|</TEXT>", filing.text, ignore.case = TRUE)[1])]
      }, error = function(e) {
        filing.text <- filing.text ## In case opening and closing DOCUMENT TAG not found, cosnider full web page
      })
      
      # See if 10-K is in XLBR or old text format
      if (any(
        grepl(pattern = '<html|<!DOCTYPE html|<xml|<type>xml|10k.htm|<XBRL', filing.text, ignore.case = T)
      )) {
        doc <- XML::htmlParse(
          filing.text,
          asText = TRUE,
          useInternalNodes = TRUE,
          addFinalizer = TRUE
        )
        
        f.text <- XML::xpathSApply(
          doc,
          "//text()[not(ancestor::script)][not(ancestor::style)][not(ancestor::noscript)][not(ancestor::form)]",
          XML::xmlValue
        )
        f.text <- iconv(f.text, "latin1", "ASCII", sub = " ")
        
      } else {
        f.text <- filing.text
      }
      
      ## In case of XBRL filings, first few lines are with "...Member" need to be deleted.
      if (any(grepl(pattern = '<XBRL', filing.text, ignore.case = T))) {
        str_line <- grep("^\\s*ANNUAL REPORT.*", f.text)
        
        if (length(str_line) > 0) {
          f.text <- f.text[str_line[1]:length(f.text)]
        }
      }
      
      
      # Preprocessing the filing text
      #f.text <- gsub("'s ", "", f.text)
      f.text <- gsub("\\n|\\t|,", " ", f.text)
      f.text <- gsub("/s/", "", f.text, fixed = T)
      f.text <- paste(f.text, collapse = " ")
      #f.text <- gsub("(?:(?![\\%\\&\\$\\,\\'\\.\\-/()])[[:punct:]])+", "", f.text, perl=TRUE) ## remove punctuations except some
      # f.text <- gsub("[[:punct:]]", "", f.text, perl=T)
      # f.text <- gsub("[[:digit:]]", "", f.text, perl=T)
      f.text <- iconv(f.text, from = 'UTF-8', to = 'ASCII//TRANSLIT')
      #f.text <- tolower(f.text)
      
      f.text <- gsub("\\s{2,}", " ", f.text)
      f.text <- gsub(" s ", "'s ", f.text)
      f.text <- gsub("[$ ]{2,}", " $", f.text)
      f.text <- gsub("(\\d) (\\d{3,}) ", "\\1,\\2 " , f.text)
      f.text <- gsub("(\\d) \\)", "\\1)" , f.text)
      
      # ### Clean text and find number of total words
      # text_words <- unlist(strsplit(f.text, " "))
      # text_df <- data.frame(word = unlist(text_words), nchar = nchar(text_words))
      # text_df <- text_df[text_df$nchar >=3, ]
      # text_df <- text_df[!(text_df$word %in% tm::stopwords("en")), ]
      # file.size <- nrow(text_df)   # Total Word count
      
      # Count words mentioned in the word.list object
      # Count words as well as general derivatives words
      nword.hits <- sum(sapply(word.list, count_func, text = f.text))
      
      # # Assign all the varibles
      # output$file.size[i] <- file.size
      output$nword.hits[i] <- nword.hits
      
      # Create HTML output for extracted text and save HTML file
      if (nword.hits > 0) {
        ## Create header for HTML output
        html_head <- paste0(
          '<p style="color: blue"><b>CIK: ',
          cik,
          "</br>Company Name: ",
          cname,
          "</br>Form Type: ",
          f.type,
          "</br>Filing Date: ",
          date.filed,
          "</br>Accession Number: ",
          accession.number,
          '</b></p>'
        )
        
        html_result <- paste0(
          '<p style="color: red"><b>Keywords search: ',
          paste0("'", paste(word.list, collapse = "', '"), "'"),
          "</br>Number of word hits: ",
          nword.hits,
          "</b></p>"
        )
        
        # Get the extarcted text
        extract.text.highl <- extract_text(f.text, word.list)
        #extract.text.highl <- unique(extract.text.highl)
        
        extract.text.highl <- paste(".....", extract.text.highl, ".....")
        ## Add line break to each highlighted extracted text
        extract.text.highl <- paste0(extract.text.highl, "</br></br>")
        
        ## Create complete html file for output
        complete.html <- c(
          html_head,
          html_result,
          "<hr style='margin-bottom:-1em' />",
          '<p style="color:Blue;" align="center"><b>Detailed search result</b></p>',
          "<hr style='margin-top:-1em' />",
          extract.text.highl
        )
        
        html.filename <- paste0(new.dir,
                                '/',
                                cik,
                                "_",
                                f.type,
                                "_",
                                date.filed,
                                "_",
                                accession.number,
                                ".html")
        
        writeLines(complete.html, html.filename)
        
      }
      
      p()
      return(output[i,])
    }
  )
  output <- do.call(rbind, results)

  ## convert dates into R dates
  output$date.filed <- as.Date(as.character(output$date.filed), "%Y-%m-%d")
  
  cat("Detailed search results are stored in 'edgar_searchFilings' directory.")
  
  return(output)
}