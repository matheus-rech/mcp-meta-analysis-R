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
function(study_type = NULL, effect_measure = NULL, analysis_model = NULL, res){
  # Input validation
  valid_study_types <- c("clinical_trial", "observational", "diagnostic")
  valid_effect_measures <- c("OR", "RR", "MD", "SMD", "HR")
  valid_analysis_models <- c("fixed", "random", "auto")
  
  # Validate study_type if provided
  if (!is.null(study_type) && !study_type %in% valid_study_types) {
    res$status <- 400
    return(list(
      status = "error",
      message = paste("Invalid study_type. Must be one of:", paste(valid_study_types, collapse = ", "))
    ))
  }
  
  # Validate effect_measure if provided
  if (!is.null(effect_measure) && !effect_measure %in% valid_effect_measures) {
    res$status <- 400
    return(list(
      status = "error",
      message = paste("Invalid effect_measure. Must be one of:", paste(valid_effect_measures, collapse = ", "))
    ))
  }
  
  # Validate analysis_model if provided
  if (!is.null(analysis_model) && !analysis_model %in% valid_analysis_models) {
    res$status <- 400
    return(list(
      status = "error",
      message = paste("Invalid analysis_model. Must be one of:", paste(valid_analysis_models, collapse = ", "))
    ))
  }
  
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
function(req, data_format = "csv", res){
  # Validate data_format parameter
  valid_formats <- c("csv", "excel", "revman")
  if (!data_format %in% valid_formats) {
    res$status <- 400
    return(list(
      status = "error",
      message = paste("Invalid data_format. Must be one of:", paste(valid_formats, collapse = ", "))
    ))
  }
  
  # Check if request body exists
  if (is.null(req$postBody) || length(req$postBody) == 0) {
    res$status <- 400
    return(list(
      status = "error",
      message = "No file data provided in request body."
    ))
  }
  
  # Set file size limit (e.g., 5 MB)
  max_file_size <- 5 * 1024 * 1024
  if (length(req$postBody) > max_file_size) {
    res$status <- 413  # Payload Too Large
    return(list(
      status = "error",
      message = "File size exceeds the 5 MB limit."
    ))
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
    res$status <- 400
    return(list(
      status = "error",
      message = "Invalid file type. Only CSV and Excel files are allowed."
    ))
  }
  
  # Validate the file content in memory
  validated <- tryCatch({
    validate_data(req$postBody, data_format)
  }, error = function(e) {
    res$status <- 400
    return(list(
      status = "error",
      message = paste("Data validation failed:", e$message)
    ))
  })
  
  # If validation failed with an error response, return it
  if (is.list(validated) && !is.null(validated$status) && validated$status == "error") {
    res$status <- 400
    return(validated)
  }
  
  # Write the validated content to a temporary file
  tmp <- tempfile(fileext = ifelse(data_format == "excel", ".xlsx", ".csv"))
  writeBin(req$postBody, tmp)
  list(status = "uploaded", rows = nrow(validated))
}

#* Perform meta-analysis
#* @param heterogeneity_test logical
#* @param publication_bias logical
#* @param sensitivity_analysis logical
#* @post /perform_meta_analysis
function(heterogeneity_test = TRUE, publication_bias = TRUE, sensitivity_analysis = FALSE, res){
  # Check if data has been uploaded
  if (!exists("meta_analysis_env", envir = .GlobalEnv) || 
      !exists('.current_data', envir = get("meta_analysis_env", envir = .GlobalEnv))) {
    res$status <- 400
    return(list(
      status = "error",
      message = "Data has not been uploaded. Please upload data before performing analysis."
    ))
  }
  
  # Validate logical parameters
  if (!is.logical(heterogeneity_test) || length(heterogeneity_test) != 1) {
    res$status <- 400
    return(list(
      status = "error",
      message = "heterogeneity_test must be a single logical value (TRUE or FALSE)"
    ))
  }
  
  if (!is.logical(publication_bias) || length(publication_bias) != 1) {
    res$status <- 400
    return(list(
      status = "error",
      message = "publication_bias must be a single logical value (TRUE or FALSE)"
    ))
  }
  
  if (!is.logical(sensitivity_analysis) || length(sensitivity_analysis) != 1) {
    res$status <- 400
    return(list(
      status = "error",
      message = "sensitivity_analysis must be a single logical value (TRUE or FALSE)"
    ))
  }
  
  # Perform analysis with error handling
  analysis_result <- tryCatch({
    perform_analysis(heterogeneity_test, publication_bias, sensitivity_analysis)
  }, error = function(e) {
    res$status <- 500
    return(list(
      status = "error",
      message = paste("Analysis failed:", e$message)
    ))
  })
  
  # If analysis failed with an error response, return it
  if (is.list(analysis_result) && !is.null(analysis_result$status) && analysis_result$status == "error") {
    return(analysis_result)
  }
  
  list(status = "analyzed", summary = analysis_result$summary)
}

#* Generate forest plot
#* @param TE Numeric vector of effect sizes (optional - uses stored data if not provided)
#* @param seTE Numeric vector of standard errors (optional - uses stored data if not provided)
#* @param plot_style Plot style: classic, modern, journal_specific
#* @param confidence_level Confidence level
#* @post /generate_forest_plot
function(TE = NULL, seTE = NULL, plot_style = "classic", confidence_level = 0.95){
  # Validate input parameters when provided
  if (!is.null(TE) || !is.null(seTE)) {
    if (is.null(TE) || is.null(seTE)) {
      res <- list(
        status = "error",
        message = "Both 'TE' (effect sizes) and 'seTE' (standard errors) must be provided together."
      )
      return(res)
    }
    
    # Convert to numeric and validate
    TE_num <- tryCatch(as.numeric(TE), error = function(e) NULL)
    seTE_num <- tryCatch(as.numeric(seTE), error = function(e) NULL)
    
    if (is.null(TE_num) || is.null(seTE_num)) {
      res <- list(
        status = "error",
        message = "'TE' and 'seTE' must be numeric values."
      )
      return(res)
    }
    
    if (length(TE_num) != length(seTE_num)) {
      res <- list(
        status = "error",
        message = "'TE' and 'seTE' must be vectors of the same length."
      )
      return(res)
    }
    
    if (length(TE_num) == 0) {
      res <- list(
        status = "error",
        message = "'TE' and 'seTE' cannot be empty."
      )
      return(res)
    }
    
    # Generate plot with provided data
    path <- generate_forest_plot_with_data(TE_num, seTE_num, plot_style, confidence_level)
  } else {
    # Use stored data from previous analysis
    path <- generate_forest_plot(plot_style, confidence_level)
  }

  # Ensure the file exists and is in a secure temp directory
  if (!file.exists(path) || !grepl(tempdir(), normalizePath(path), fixed = TRUE)) {
    res <- list(
      status = "error",
      message = "Invalid or missing plot file."
    )
    return(res)
  }

  # Read the file content
  file_content <- readBin(path, what = "raw", n = file.info(path)$size)

  # Securely delete the file after reading
  unlink(path)

  # Return the file content as a response with appropriate content type
  plumber::as_attachment(file_content, filename = basename(path), type = "image/png")
}

#* Assess publication bias
#* @param methods Vector of methods
#* @post /assess_publication_bias
function(methods = c("funnel_plot", "egger_test"), res){
  # Check if analysis has been performed
  if (!exists("meta_analysis_env", envir = .GlobalEnv) || 
      !exists('.current_result', envir = get("meta_analysis_env", envir = .GlobalEnv))) {
    res$status <- 400
    return(list(
      status = "error",
      message = "No analysis results available. Please perform meta-analysis first."
    ))
  }
  
  # Validate methods parameter
  valid_methods <- c("funnel_plot", "egger_test")
  if (!is.character(methods) || !all(methods %in% valid_methods)) {
    res$status <- 400
    return(list(
      status = "error",
      message = paste("Invalid methods. Must be one or more of:", paste(valid_methods, collapse = ", "))
    ))
  }
  
  # Perform bias assessment with error handling
  bias_result <- tryCatch({
    assess_publication_bias(methods)
  }, error = function(e) {
    res$status <- 500
    return(list(
      status = "error",
      message = paste("Publication bias assessment failed:", e$message)
    ))
  })
  
  # If bias assessment failed with an error response, return it
  if (is.list(bias_result) && !is.null(bias_result$status) && bias_result$status == "error") {
    return(bias_result)
  }
  
  list(status = "done", bias = bias_result)
}

#* Generate analysis report
#* @param format html, pdf or word
#* @param include_code logical
#* @post /generate_report
function(format = "html", include_code = FALSE, res){
  # Check if analysis has been performed
  if (!exists("meta_analysis_env", envir = .GlobalEnv) || 
      !exists('.current_result', envir = get("meta_analysis_env", envir = .GlobalEnv))) {
    res$status <- 400
    return(list(
      status = "error",
      message = "No analysis results available. Please perform meta-analysis first."
    ))
  }
  
  # Validate format parameter
  valid_formats <- c("html", "pdf", "word")
  if (!format %in% valid_formats) {
    res$status <- 400
    return(list(
      status = "error",
      message = paste("Invalid format. Must be one of:", paste(valid_formats, collapse = ", "))
    ))
  }
  
  # Validate include_code parameter
  if (!is.logical(include_code) || length(include_code) != 1) {
    res$status <- 400
    return(list(
      status = "error",
      message = "include_code must be a single logical value (TRUE or FALSE)"
    ))
  }
  
  # Generate report with error handling
  report_path <- tryCatch({
    generate_report(format, include_code)
  }, error = function(e) {
    res$status <- 500
    return(list(
      status = "error",
      message = paste("Report generation failed:", e$message)
    ))
  })
  
  # If report generation failed with an error response, return it
  if (is.list(report_path) && !is.null(report_path$status) && report_path$status == "error") {
    return(report_path)
  }
  
  plumber::include_file(report_path)
}

