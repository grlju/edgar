# edgar 2.1.0

Tool for the U.S. SEC EDGAR Retrieval and Parsing of Corporate Filings

# Overview

In the USA, companies file different forms with the U.S. Securities and
Exchange Commission (SEC) through EDGAR (Electronic Data Gathering,
Analysis, and Retrieval system). The EDGAR database automated system
collects all the different necessary filings and makes it publicly
available. This package facilitates retrieving, storing, searching, and
parsing of all the available filings on the EDGAR server. It downloads
filings from SEC server in bulk with a single query. Additionally, it
provides various useful functions: extracts 8-K triggering events,
extract “Business (Item 1)” and “Management’s Discussion and
Analysis(Item 7)” sections of annual statements, searches filings for
desired keywords, provides sentiment measures, parses filing header
information, and provides HTML view of SEC filings.

# Installation

The package is maintained on [github](https://github.com/grlju/edgar).

You can install the latest version of the edgar R package from
[github](https://github.com/grlju/edgar)

    library("edgar")

# Implementation of the edgar package

## SEC guidelines on downloading EDGAR files

Please download only what you need and moderate download requests to
minimize EDGAR server load. A user is required to declare user agent in
request headers. The following link explains these requirements in
details. <https://www.sec.gov/os/accessing-edgar-data>

Accordingly, `edgar` package requires user to pass user agent in every
function. It should be in the form of

    useragent = "Your_Name_Contact@domain.com"

## Download daily filing information

The `getDailyMaster` function takes date as an input parameter from a
user, and downloads master index for the date from the U.S. SEC EDGAR
server <https://www.sec.gov/Archives/edgar/daily-index/>. It strips
headers and converts this daily filing information into dataframe
format. Function creates new directory ‘Daily Indexes’ into working
directory to save these downloaded daily master index files in Rda
format.

    output <- getDailyMaster('08/09/2016', useragent)

    ## Downloading Master Indexes from SEC server for 2006 
    ## Master Index for quarter 1 downloaded successfully
    ## Master Index for quarter 2 downloaded successfully
    ## Master Index for quarter 3 downloaded successfully
    ## Master Index for quarter 4 downloaded successfully

    head(output)

    ##       cik             company.name form.type date.filed
    ## 1 1000045   NICHOLAS FINANCIAL INC      10-Q 2016-08-09
    ## 2 1000209 MEDALLION FINANCIAL CORP      10-Q 2016-08-09
    ## 3 1000275     ROYAL BANK OF CANADA     424B2 2016-08-09
    ## 4 1000275     ROYAL BANK OF CANADA     424B2 2016-08-09
    ## 5 1000275     ROYAL BANK OF CANADA     424B2 2016-08-09
    ## 6 1000275     ROYAL BANK OF CANADA       FWP 2016-08-09
    ##                                    edgar.link
    ## 1 edgar/data/1000045/0001193125-16-676314.txt
    ## 2 edgar/data/1000209/0001193125-16-676548.txt
    ## 3 edgar/data/1000275/0001140361-16-075316.txt
    ## 4 edgar/data/1000275/0001140361-16-075341.txt
    ## 5 edgar/data/1000275/0001140361-16-075356.txt
    ## 6 edgar/data/1000275/0001140361-16-075489.txt

## Download quarterly filing information

The `getMasterIndex` function takes filing year as an input parameter
from a user, downloads quarterly master indexes from the US SEC server
<https://www.sec.gov/Archives/edgar/full-index/>. It then strips headers
from the master index files, converts them into dataframe, and merges
such quarterly dataframes into yearly dataframe, and stores them in Rda
format. It has ability to download master indexes for multiple years
based on the user input. This function creates a new directory
`Master Indexes` into current working directory to save these Rda Master
Index. Please note, for all other functions in this package need to
locate the same working directory to access these Rda master index
files.

    getMasterIndex(2006, useragent)

    ## Downloading Master Indexes from SEC server for 2006 
    ## Master Index for quarter 1 downloaded successfully
    ## Master Index for quarter 2 downloaded successfully
    ## Master Index for quarter 3 downloaded successfully
    ## Master Index for quarter 4 downloaded successfully

    load("edgar_MasterIndex/2006master.Rda")  # Load the generated yearly filing information
    head(year.master)

    ##       cik           company.name form.type date.filed
    ## 1 1000045 NICHOLAS FINANCIAL INC      10-Q 2006-02-14
    ## 2 1000045 NICHOLAS FINANCIAL INC         4 2006-02-15
    ## 3 1000045 NICHOLAS FINANCIAL INC         4 2006-02-22
    ## 4 1000045 NICHOLAS FINANCIAL INC       5/A 2006-01-25
    ## 5 1000045 NICHOLAS FINANCIAL INC       5/A 2006-01-25
    ## 6 1000045 NICHOLAS FINANCIAL INC       5/A 2006-01-25
    ##                                    edgar.link quarter
    ## 1 edgar/data/1000045/0001144204-06-005708.txt       1
    ## 2 edgar/data/1000045/0001144204-06-006463.txt       1
    ## 3 edgar/data/1000045/0001144204-06-007252.txt       1
    ## 4 edgar/data/1000045/0000897069-06-000169.txt       1
    ## 5 edgar/data/1000045/0000897069-06-000171.txt       1
    ## 6 edgar/data/1000045/0000897069-06-000173.txt       1

## Search for filing information

The `getFilingInfo` function takes firm identifier (name or cik), filing
year(s), quarter(s), and form type as input parameters from a user and
provides filing information for the firm. The function automatically
downloads master index for the input year(s) and the quarter(s) using
`getMasterIndex` function if it is not already been downloaded in the
current working directory. By default, information of all the form types
filed in all the quarters of the input year by the firm will be provided
by this function.

    info <- getFilingInfo('United Technologies', c(2005, 2006), quarter = c(1,2), form.type = c('8-K','10-K'), useragent) 

    ## Downloading Master Indexes from SEC server for 2005 
    ## Master Index for quarter 1 downloaded successfully
    ## Master Index for quarter 2 downloaded successfully
    ## Master Index for quarter 3 downloaded successfully
    ## Master Index for quarter 4 downloaded successfully
    ## Searching master indexes for filing information

    head(info)

    ##      cik                  company.name form.type date.filed
    ## 1 101829 UNITED TECHNOLOGIES CORP  DE       10-K 2005-02-10
    ## 2 101829 UNITED TECHNOLOGIES CORP  DE        8-K 2005-01-21
    ## 3 101829 UNITED TECHNOLOGIES CORP  DE        8-K 2005-04-18
    ## 4 101829 UNITED TECHNOLOGIES CORP  DE        8-K 2005-04-20
    ## 5 101829 UNITED TECHNOLOGIES CORP  DE        8-K 2005-04-25
    ## 6 101829 UNITED TECHNOLOGIES CORP  DE        8-K 2005-05-06
    ##                                   edgar.link quarter filing.year
    ## 1 edgar/data/101829/0001193125-05-025271.txt       1        2005
    ## 2 edgar/data/101829/0001193125-05-009357.txt       1        2005
    ## 3 edgar/data/101829/0001193125-05-078658.txt       2        2005
    ## 4 edgar/data/101829/0001193125-05-079991.txt       2        2005
    ## 5 edgar/data/101829/0001193125-05-084015.txt       2        2005
    ## 6 edgar/data/101829/0001193125-05-099447.txt       2        2005

## Download filings

The `getFilings` function takes CIKs, form type, filing year, and
quarter of the filing as input. It creates new directory
`Edgar filings_full text` to store all downloaded filings. All the
filings will be stored in the current working directory. Keep the same
current working directory for further process.

    output <- getFilings(cik.no = c(1000180, 38079), c('10-K','10-Q'), 2006, quarter = c(1, 2, 3), downl.permit = "y", useragent)

    ## Downloading fillings

    output

    ##       cik    company.name form.type date.filed
    ## 1 1000180    SANDISK CORP      10-K 2006-03-15
    ## 2 1000180    SANDISK CORP      10-Q 2006-05-08
    ## 3 1000180    SANDISK CORP      10-Q 2006-08-10
    ## 4   38079 FOREST OIL CORP      10-K 2006-03-16
    ## 5   38079 FOREST OIL CORP      10-Q 2006-05-10
    ## 6   38079 FOREST OIL CORP      10-Q 2006-08-09
    ##                                    edgar.link quarter filing.year
    ## 1 edgar/data/1000180/0000891618-06-000116.txt       1        2006
    ## 2 edgar/data/1000180/0000891618-06-000190.txt       2        2006
    ## 3 edgar/data/1000180/0000950134-06-015727.txt       3        2006
    ## 4   edgar/data/38079/0001047469-06-003499.txt       1        2006
    ## 5   edgar/data/38079/0001104659-06-033149.txt       2        2006
    ## 6   edgar/data/38079/0001104659-06-053129.txt       3        2006
    ##       accession.number           status
    ## 1 0000891618-06-000116 Download success
    ## 2 0000891618-06-000190 Download success
    ## 3 0000950134-06-015727 Download success
    ## 4 0001047469-06-003499 Download success
    ## 5 0001104659-06-033149 Download success
    ## 6 0001104659-06-053129 Download success

## Get HTML view of filings

The `getFilingsHTML` function takes CIK(s), form type(s), filing
year(s), and quarter of the filing as input. The function imports edgar
filings downloaded via getFilings function; otherwise, it downloads the
filings which are not already been downloaded. It then reads the
downloaded filings, scraps filing text excluding exhibits, and saves the
filing contents in `Edgar filings_HTML view` directory in HTML format.

    output <- getFilingsHTML(cik.no = c(1000180, 38079), c('10-K','10-Q'), 2006, quarter = c(1, 2, 3), useragent)

    ## Downloading fillings
    ## Scrapping full EDGAR and converting to HTML
    ## HTML filings are stored in 'edgar_FilingsHTML' directory.

    head(output)

    ##       cik    company.name form.type date.filed
    ## 1 1000180    SANDISK CORP      10-K 2006-03-15
    ## 2 1000180    SANDISK CORP      10-Q 2006-05-08
    ## 3 1000180    SANDISK CORP      10-Q 2006-08-10
    ## 4 1000180    SANDISK CORP      10-Q 2006-11-08
    ## 5   38079 FOREST OIL CORP      10-K 2006-03-16
    ## 6   38079 FOREST OIL CORP      10-Q 2006-05-10
    ##                                    edgar.link     accession.number
    ## 1 edgar/data/1000180/0000891618-06-000116.txt 0000891618-06-000116
    ## 2 edgar/data/1000180/0000891618-06-000190.txt 0000891618-06-000190
    ## 3 edgar/data/1000180/0000950134-06-015727.txt 0000950134-06-015727
    ## 4 edgar/data/1000180/0000950134-06-020940.txt 0000950134-06-020940
    ## 5   edgar/data/38079/0001047469-06-003499.txt 0001047469-06-003499
    ## 6   edgar/data/38079/0001104659-06-033149.txt 0001104659-06-033149
    ##             status
    ## 1 Download success
    ## 2 Download success
    ## 3 Download success
    ## 4 Download success
    ## 5 Download success
    ## 6 Download success

## Extract filing header information

The `getFilingHeader` function takes CIK(s), form type(s), and year(s)
as input parameters. The function first imports available downloaded
filings in local woking directory `Edgar filings_full text` created by
getFilings function; otherwise, it automatically downloads the filings
which are not already been downloaded. It then parses all the important
header information from filings. The function returns a dataframe with
filing and header information.

    header.df <- getFilingHeader(cik.no = c('1000180', '38079'), form.type = '10-K', filing.year = 2006, useragent) 

    ## Downloading fillings
    ## Scraping filing header information

    header.df

    ##       cik    company.name form.type date.filed
    ## 1 1000180    SANDISK CORP      10-K 2006-03-15
    ## 2   38079 FOREST OIL CORP      10-K 2006-03-16
    ##                                    edgar.link     accession.number
    ## 1 edgar/data/1000180/0000891618-06-000116.txt 0000891618-06-000116
    ## 2   edgar/data/38079/0001047469-06-003499.txt 0001047469-06-003499
    ##   period.of.report fiscal.yr.end filer.no filer.company.name filer.cik  sic
    ## 1       2006-01-01          1231        1       SANDISK CORP   1000180 3572
    ## 2       2005-12-31          1231        1    FOREST OIL CORP     38079 1311
    ##         irs state.of.incorp       business.street1 business.street2
    ## 1 770191793              DE      140 CASPIAN COURT             <NA>
    ## 2 250484900              NY 707 SEVENTEENTH STREET       SUITE 3600
    ##   business.city business.state business.zip mail.street1 mail.street2 mail.city
    ## 1     SUNNYVALE             CA        94089         <NA>         <NA>      <NA>
    ## 2        DENVER             CO        80202         <NA>         <NA>      <NA>
    ##   mail.state mail.zip                     former.names  name.change.dates
    ## 1       <NA>     <NA>                               NA                 NA
    ## 2       <NA>     <NA> FOREST OIL CORP, FOREST OIL CORP 20040819, 19920703

## Search filings for input keywords

The `searchFilings` function takes search keyword vector, CIK(s), form
type(s), and year(s) as input parameters. The function first imports
available downloaded filings in the local woking directory
`Edgar filings_full text` created by `getFilings` function; otherwise,
it automatically downloads the filings which are not already been
downloaded. It then reads the filings and searches for the input
keywords. The function returns a dataframe with filing information and
the number of keyword hits. Additionally, it saves the search
information with surrounding content of search keywords in HTML format
in the new directory `Keyword search results`. These HTML view of search
results would help the user to analyze the search strategy and identify
false positive hits.

    word.list = c('derivative','hedging','currency forwards','currency futures')
    output <- searchFilings(cik.no = c('1000180', '38079'), form.type = c("10-K", "10-K405","10KSB", "10KSB40"), filing.year = c(2005, 2006), word.list, useragent) 

    ## Downloading fillings
    ## Searching filings for the input words
    ## Detailed search results are stored in 'edgar_searchFilings' directory.

    output

    ##       cik    company.name form.type date.filed
    ## 1 1000180    SANDISK CORP      10-K 2005-03-18
    ## 2 1000180    SANDISK CORP      10-K 2006-03-15
    ## 3   38079 FOREST OIL CORP      10-K 2005-03-15
    ## 4   38079 FOREST OIL CORP      10-K 2006-03-16
    ##                                    edgar.link quarter filing.year
    ## 1 edgar/data/1000180/0000950134-05-005462.txt       1        2005
    ## 2 edgar/data/1000180/0000891618-06-000116.txt       1        2006
    ## 3   edgar/data/38079/0001047469-05-006546.txt       1        2005
    ## 4   edgar/data/38079/0001047469-06-003499.txt       1        2006
    ##       accession.number           status nword.hits
    ## 1 0000950134-05-005462 Download success          1
    ## 2 0000891618-06-000116 Download success          5
    ## 3 0001047469-05-006546 Download success         81
    ## 4 0001047469-06-003499 Download success        105

## Extract business description section from annual statements

The `getBusinDescr` function takes firm CIK(s) and filing year(s) as
input parameters from a user and provides “Item 1” section extracted
from annual statements along with filing information. The function
imports annual filings (10-K statements) downloaded via `getFilings`
function; otherwise, it automates the downloading process if not already
been downloaded. It then reads the downloaded statements, cleans HTML
tags, and parse the contents. This function automatically creates a new
directory with the name `Business descriptions text` in the current
working directory and saves scrapped business description sections in
this directory. It considers “10-K”, “10-K405”, “10KSB”, and “10KSB40”
form types as annual statements.

    output <- getBusinDescr(cik.no = c(1000180, 38079), filing.year = c(2005, 2006), useragent)

    ## Downloading fillings
    ## Extracting 'Item 1' section
    ## Business descriptions are stored in 'edgar_BusinDescr' directory.

    output

    ##       cik    company.name form.type date.filed
    ## 1 1000180    SANDISK CORP      10-K 2005-03-18
    ## 2 1000180    SANDISK CORP      10-K 2006-03-15
    ## 3   38079 FOREST OIL CORP      10-K 2005-03-15
    ## 4   38079 FOREST OIL CORP      10-K 2006-03-16
    ##                                    edgar.link quarter filing.year
    ## 1 edgar/data/1000180/0000950134-05-005462.txt       1        2005
    ## 2 edgar/data/1000180/0000891618-06-000116.txt       1        2006
    ## 3   edgar/data/38079/0001047469-05-006546.txt       1        2005
    ## 4   edgar/data/38079/0001047469-06-003499.txt       1        2006
    ##       accession.number           status extract.status
    ## 1 0000950134-05-005462 Download success              1
    ## 2 0000891618-06-000116 Download success              1
    ## 3 0001047469-05-006546 Download success              1
    ## 4 0001047469-06-003499 Download success              1

## Extract MD&A section from annual statements

The `getMgmtDisc` function takes firm CIK(s) and filing year(s) as input
parameters from a user and provides “Item 7” section extracted from
annual statements along with filing information. The function imports
annual filings downloaded via `getFilings` function; otherwise, it
downloads the filings which are not already been downloaded. It then
reads, cleans, and parse the required section from the filings. It
creates a new directory with the name `MD&A section text` in the current
working directory to save scrapped “Item 7” sections in text format. It
considers “10-K”, “10-K405”, “10KSB”, and “10KSB40” form types as annual
statements.

    output <- getMgmtDisc(cik.no = c(1000180, 38079), filing.year = 2005, useragent)

    ## Downloading fillings
    ## Extracting 'Item 7' section
    ## MD&A section texts are stored in 'edgar_MgmtDisc' directory

    output

    ##       cik    company.name form.type date.filed
    ## 1 1000180    SANDISK CORP      10-K 2005-03-18
    ## 2   38079 FOREST OIL CORP      10-K 2005-03-15
    ##                                    edgar.link quarter filing.year
    ## 1 edgar/data/1000180/0000950134-05-005462.txt       1        2005
    ## 2   edgar/data/38079/0001047469-05-006546.txt       1        2005
    ##       accession.number           status extract.status
    ## 1 0000950134-05-005462 Download success              1
    ## 2 0001047469-05-006546 Download success              1

## Retrieve Form 8-K items information

The `get8KItems` function takes firm CIK(s) and filing year(s) as input
parameters from a user and provides information on the Form 8-K
triggering events along with the firm filing information. The function
searches and imports existing downloaded 8-K filings in the current
directory; otherwise it downloads them using `getFilings` function. It
then reads the 8-K filings and parses them to extract events
information.

    output <- get8KItems(cik.no = 38079, filing.year = 2005, useragent)

    ## Downloading fillings
    ## Scraping 8-K filings

    tail(output)

    ##      cik    company.name form.type date.filed
    ## 35 38079 FOREST OIL CORP       8-K 2005-10-24
    ## 36 38079 FOREST OIL CORP       8-K 2005-11-10
    ## 37 38079 FOREST OIL CORP       8-K 2005-11-10
    ## 38 38079 FOREST OIL CORP       8-K 2005-11-10
    ## 39 38079 FOREST OIL CORP       8-K 2005-12-22
    ## 40 38079 FOREST OIL CORP       8-K 2005-12-27
    ##                                       event.info
    ## 35    Entry into a Material Definitive Agreement
    ## 36 Results of Operations and Financial Condition
    ## 37                      Regulation FD Disclosure
    ## 38             Financial Statements and Exhibits
    ## 39                      Regulation FD Disclosure
    ## 40    Entry into a Material Definitive Agreement

## Generate sentiment measures of SEC filings

The `getSentiment` function takes CIK(s), form type(s), and year(s) as
input parameters. The function first imports available downloaded
filings in the local working directory `Edgar filings_full text` created
by getFilings function; otherwise, it automatically downloads the
filings which are not already been downloaded. It then reads, cleans,
and computes sentiment measures for these filings. The function returns
a dataframe with filing information and sentiment measures.

    senti.df <- getSentiment(cik.no = c('1000180', '38079'), form.type = '10-K', filing.year = 2006, useragent) 

    ## Downloading fillings
    ## Computing sentiment measures

    senti.df

    ##       cik    company.name form.type date.filed
    ## 1 1000180    SANDISK CORP      10-K 2006-03-15
    ## 2   38079 FOREST OIL CORP      10-K 2006-03-16
    ##                                    edgar.link quarter filing.year
    ## 1 edgar/data/1000180/0000891618-06-000116.txt       1        2006
    ## 2   edgar/data/38079/0001047469-06-003499.txt       1        2006
    ##       accession.number           status file.size word.count unique.word.count
    ## 1 0000891618-06-000116 Download success      1666      35843              3266
    ## 2 0001047469-06-003499 Download success      1436      36192              2931
    ##   stopword.count char.count complex.word.count lm.dictionary.count
    ## 1           9211     227147              16058               33533
    ## 2           8672     228638              16380               34512
    ##   lm.negative.count lm.positive.count lm.strong.modal.count
    ## 1              1123               240                   124
    ## 2               676               243                   118
    ##   lm.moderate.modal.count lm.weak.modal.count lm.uncertainty.count
    ## 1                     104                 320                  694
    ## 2                     111                 204                  688
    ##   lm.litigious.count hv.negative.count
    ## 1                581              1986
    ## 2                364              1987

Following are the definitions of the text characteristics and the
sentiment measures:

`file.size` = The filing size of a complete filing on the EDGAR server
in kilobyte (KB).

`word.count` = The total number of words in a filing text, excluding
HTML tags and exhibits text.

`unique.word.count` = The total number of unique words in a filing text,
excluding HTML tags and exhibits text.

`stopword.count` = The total number of stop words in a filing text,
excluding exhibits text.

`char.count` = The total number of characters in a filing text,
excluding HTML tags and exhibits text.

`complex.word.count` = The total number of complex words in the filing
text. When vowels (a, e, i, o, u) occur more than three times in a word,
then that word is identified as a complex word.

`lm.dictionary.count` = The number of words in the filing text that
occur in the Loughran-McDonald (LM) master dictionary.

`lm.negative.count` = The number of LM financial-negative words in the
document.

`lm.positive.count` = The number of LM financial-positive words in the
document.

`lm.strong.modal.count` = The number of LM financial-strong modal words
in the document.

`lm.moderate.modal.count` = The number of LM financial-moderate Modal
words in the document.

`lm.weak.modal.count` = The number of LM financial-weak modal words in
the document.

`lm.uncertainty.count` = The number of LM financial-uncertainty words in
the document.

`lm.litigious.count` = The number of LM financial-litigious words in the
document.

`hv.negative.count` = The number of words in the document that occur in
the ‘Harvard General Inquirer’ Negative word list, as defined by LM.
