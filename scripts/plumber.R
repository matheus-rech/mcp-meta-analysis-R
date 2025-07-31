# Load required packages
library(plumber)
source('scripts/meta_analysis_utils.R')

#* @apiTitle MCP Meta-Analysis Server
#* @apiDescription Simple MCP server for running meta-analyses in R

#* Initialize a new meta-analysis session
#* @param study_type Type of study: clinical_trial, observational, diagnostic
#* @param effect_measure Effect measure: OR, RR, MD, SMD, HR
#* @param analysis_model Model type: fixed, random, auto
#* @post /initialize_meta_analysis
function(study_type = NULL, effect_measure = NULL, analysis_model = NULL){
  list(
    status = "initialized",
    study_type = study_type,
    effect_measure = effect_measure,
    analysis_model = analysis_model
  )
}

#* Upload and validate study data (CSV content in request body)
#* @param data_format Data format: csv, excel, revman
#* @post /upload_study_data
function(req, data_format = "csv"){
  # Set file size limit (e.g., 5 MB)
  max_file_size <- 5 * 1024 * 1024
  if (length(req$postBody) > max_file_size) {
    stop("File size exceeds the 5 MB limit.")
  }
  
  # Validate content type and file signature
  valid_content_types <- c(
    "text/csv",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "application/octet-stream"
  )
  content_type_valid <- req$HTTP_CONTENT_TYPE %in% valid_content_types

  # Check file signature (magic number)
  is_csv <- function(raw_bytes) {
    # CSV files are plain text, so we check if the first bytes are printable ASCII or UTF-8 BOM
    if (length(raw_bytes) >= 3 && all(raw_bytes[1:3] == as.raw(c(0xEF, 0xBB, 0xBF)))) {
      # UTF-8 BOM present, treat as CSV
      return(TRUE)
    }
    # Check if first 512 bytes are printable or whitespace
    ascii_check <- all(raw_bytes[1:min(512, length(raw_bytes))] %in% as.raw(c(9, 10, 13, 32:126)))
    return(ascii_check)
  }

  is_excel <- function(raw_bytes) {
    # XLSX files are ZIP archives: first 4 bytes are 50 4B 03 04
    if (length(raw_bytes) >= 4 && all(raw_bytes[1:4] == as.raw(c(0x50, 0x4B, 0x03, 0x04)))) {
      return(TRUE)
    }
    return(FALSE)
  }

  file_signature_valid <- is_csv(req$postBody) || is_excel(req$postBody)

  if (!content_type_valid && !file_signature_valid) {
    stop("Invalid file type. Only CSV and Excel files are allowed.")
  }
  
  tmp <- tempfile(fileext = ifelse(data_format == "excel", ".xlsx", ".csv"))
  writeBin(req$postBody, tmp)
  validated <- validate_data(tmp, data_format)
  list(status = "uploaded", rows = nrow(validated))
}

#* Perform meta-analysis
#* @param heterogeneity_test logical
#* @param publication_bias logical
#* @param sensitivity_analysis logical
#* @post /perform_meta_analysis
function(heterogeneity_test = TRUE, publication_bias = TRUE, sensitivity_analysis = FALSE){
  res <- perform_analysis(heterogeneity_test, publication_bias, sensitivity_analysis)
  list(status = "analyzed", summary = res$summary)
}

#* Generate forest plot
#* @param plot_style Plot style: classic, modern, journal_specific
#* @param confidence_level Confidence level
#* @post /generate_forest_plot
function(plot_style = "classic", confidence_level = 0.95){
  # Generate the plot and get the path to the temporary file
  path <- generate_forest_plot(plot_style, confidence_level)

  # Ensure the file exists and is in a secure temp directory
  if (!file.exists(path) || !grepl(tempdir(), normalizePath(path), fixed = TRUE)) {
    stop("Invalid or missing plot file.")
  }

  # Read the file content
  file_content <- readBin(path, what = "raw", n = file.info(path)$size)

  # Securely delete the file after reading
  unlink(path)

  # Return the file content as a response with appropriate content type
  plumber::as_attachment(file_content, filename = basename(path), type = "image/png")
}
  plumber::include_file(path)
}

#* Assess publication bias
#* @param methods Vector of methods
#* @post /assess_publication_bias
function(methods = c("funnel_plot", "egger_test")){
  bias <- assess_publication_bias(methods)
  list(status = "done", bias = bias)
}

#* Generate analysis report
#* @param format html, pdf or word
#* @param include_code logical
#* @post /generate_report
function(format = "html", include_code = FALSE){
  report <- generate_report(format, include_code)
  plumber::include_file(report)
}

