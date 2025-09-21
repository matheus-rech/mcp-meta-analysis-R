# Advanced Plumber API for Meta-Analysis with comprehensive validation
library(plumber)
library(meta)
library(metafor)
source('meta_analysis_utils.R')

# Global data storage
.session_data <- new.env()

#* @apiTitle Meta-Analysis MCP Server
#* @apiDescription Comprehensive meta-analysis server with advanced validation

#* Initialize meta-analysis session with validation
#* @param study_type Type of study
#* @param effect_measure Effect measure to use
#* @param analysis_model Analysis model preference
#* @post /initialize_meta_analysis
function(req, res, study_type = "clinical_trial", effect_measure = "OR", analysis_model = "random") {
  # Validate parameters
  valid_study_types <- c("clinical_trial", "observational", "diagnostic")
  valid_effect_measures <- c("OR", "RR", "MD", "SMD", "HR") 
  valid_models <- c("fixed", "random", "auto")
  
  if (!study_type %in% valid_study_types) {
    res$status <- 400
    return(list(
      status = "error",
      message = paste("Invalid study_type. Must be one of:", paste(valid_study_types, collapse=", "))
    ))
  }
  
  if (!effect_measure %in% valid_effect_measures) {
    res$status <- 400
    return(list(
      status = "error", 
      message = paste("Invalid effect_measure. Must be one of:", paste(valid_effect_measures, collapse=", "))
    ))
  }
  
  if (!analysis_model %in% valid_models) {
    res$status <- 400
    return(list(
      status = "error",
      message = paste("Invalid analysis_model. Must be one of:", paste(valid_models, collapse=", "))
    ))
  }
  
  # Store session parameters
  .session_data$study_type <- study_type
  .session_data$effect_measure <- effect_measure  
  .session_data$analysis_model <- analysis_model
  
  list(
    status = "initialized",
    study_type = study_type,
    effect_measure = effect_measure,
    analysis_model = analysis_model,
    timestamp = Sys.time()
  )
}

#* Upload and validate study data
#* @param data_format Data format
#* @param data_content Raw data content
#* @param validation_level Level of validation
#* @post /upload_study_data
function(req, res, data_format = "csv", data_content, validation_level = "basic") {
  
  # Validate file content type
  content_type_valid <- grepl("text/csv|application/.*excel.*|application/.*spreadsheet.*", 
                             req$headers$`content-type` %||% "", ignore.case = TRUE)
  
  # Check file signatures
  is_csv <- function(raw_bytes) {
    # Simple ASCII check for CSV-like content
    ascii_check <- tryCatch({
      text_content <- rawToChar(raw_bytes[1:min(1000, length(raw_bytes))])
      all(grepl("^[[:print:]\\s]*$", text_content)) && 
        (grepl(",", text_content) || grepl(";", text_content))
    }, error = function(e) FALSE)
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
  
  if (inherits(validated, "list") && validated$status == "error") {
    return(validated)
  }
  
  .session_data$data_uploaded <- TRUE
  .session_data$data_format <- data_format
  .session_data$validation_level <- validation_level
  
  list(
    status = "uploaded",
    data_format = data_format,
    validation_level = validation_level,
    records_count = nrow(validated),
    timestamp = Sys.time()
  )
}

#* Perform meta-analysis with comprehensive parameter validation
#* @param heterogeneity_test Boolean for heterogeneity testing
#* @param publication_bias Boolean for publication bias assessment  
#* @param sensitivity_analysis Boolean for sensitivity analysis
#* @post /perform_meta_analysis
function(req, res, heterogeneity_test = TRUE, publication_bias = TRUE, sensitivity_analysis = FALSE) {
  
  # Check if data has been uploaded
  if (!isTRUE(.session_data$data_uploaded)) {
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
    perform_analysis(
      heterogeneity_test = heterogeneity_test,
      publication_bias = publication_bias, 
      sensitivity_analysis = sensitivity_analysis,
      effect_measure = .session_data$effect_measure
    )
  }, error = function(e) {
    res$status <- 500
    return(list(
      status = "error",
      message = paste("Analysis failed:", e$message)
    ))
  })
  
  if (inherits(analysis_result, "list") && analysis_result$status == "error") {
    return(analysis_result)
  }
  
  .session_data$analysis_complete <- TRUE
  .session_data$analysis_result <- analysis_result
  
  list(
    status = "analysis_complete",
    heterogeneity_test = heterogeneity_test,
    publication_bias = publication_bias,
    sensitivity_analysis = sensitivity_analysis,
    timestamp = Sys.time()
  )
}

#* Generate forest plot with enhanced validation
#* @param TE Numeric vector of effect sizes
#* @param seTE Numeric vector of standard errors  
#* @param plot_style Plot styling option
#* @param confidence_level Confidence level for intervals
#* @post /generate_forest_plot
function(req, res, TE, seTE, plot_style = "classic", confidence_level = 0.95) {
  
  # Validate required parameters
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
  
  if (any(seTE_num <= 0, na.rm = TRUE)) {
    res <- list(
      status = "error", 
      message = "'seTE' values must be positive."
    )
    return(res)
  }
  
  # Validate plot_style parameter
  valid_styles <- c("classic", "modern", "journal_specific")
  if (!plot_style %in% valid_styles) {
    res$status <- 400
    return(list(
      status = "error",
      message = paste("Invalid plot_style. Must be one of:", paste(valid_styles, collapse=", "))
    ))
  }
  
  # Validate confidence_level parameter
  if (!is.numeric(confidence_level) || length(confidence_level) != 1 || 
      confidence_level <= 0 || confidence_level >= 1) {
    res$status <- 400
    return(list(
      status = "error",
      message = "confidence_level must be a numeric value between 0 and 1"
    ))
  }
  
  # Generate plot
  plot_result <- tryCatch({
    if (!is.null(TE) && !is.null(seTE)) {
      # Use provided data
      temp_plot <- generate_forest_plot(plot_style, confidence_level)
    } else {
      # Use stored analysis result
      if (!isTRUE(.session_data$analysis_complete)) {
        res$status <- 400
        return(list(
          status = "error",
          message = "No analysis result available. Please run analysis first or provide TE and seTE parameters."
        ))
      }
      temp_plot <- generate_forest_plot(plot_style, confidence_level)
    }
    temp_plot
  }, error = function(e) {
    res$status <- 500
    return(list(
      status = "error",
      message = paste("Plot generation failed:", e$message)
    ))
  })
  
  if (inherits(plot_result, "list") && plot_result$status == "error") {
    return(plot_result)
  }
  
  list(
    status = "plot_generated",
    path = plot_result,
    plot_style = plot_style,
    confidence_level = confidence_level,
    timestamp = Sys.time()
  )
}