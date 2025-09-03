#' MCP Meta-Analysis Server
#'
#' This Plumber API exposes endpoints for performing meta-analyses using the
#' `meta` and `metafor` packages. The implementation is intentionally minimal
#' and intended for demonstration.
#'
#' @apiTitle MCP Meta-Analysis Server
#' @apiDescription Minimal example implementation of the endpoints described in
#' the architecture document.

library(plumber)
library(meta)
library(metafor)

#* Initialize a new meta-analysis session
#* @param study_type Type of study (e.g. clinical_trial)
#* @param effect_measure Effect measure (OR, RR, MD, SMD, HR)
#* @param analysis_model Analysis model (fixed, random, auto)
#* @post /initialize_meta_analysis
function(study_type = "clinical_trial", effect_measure = "OR", analysis_model = "random") {
  list(
    status = "initialized",
    study_type = study_type,
    effect_measure = effect_measure,
    analysis_model = analysis_model
  )
}

#* Upload study data
#* @param data_format Data format (csv, excel, revman)
#* @param validation_level Validation level (basic, comprehensive)
#* @param file:file Uploaded data file
#* @post /upload_study_data
function(data_format = "csv", validation_level = "basic", file) {
  tmp <- tempfile(fileext = switch(data_format, csv = ".csv", excel = ".xlsx", revman = ".rm5", ".dat"))
  on.exit(unlink(tmp))
  file.copy(file$datapath, tmp)
  list(status = "uploaded", path = tmp, validation = validation_level)
}

#* Perform meta-analysis
#* @param heterogeneity_test Run heterogeneity tests
#* @param publication_bias Check publication bias
#* @param sensitivity_analysis Run sensitivity analysis
#* @post /perform_meta_analysis
function(heterogeneity_test = TRUE, publication_bias = TRUE, sensitivity_analysis = FALSE) {
  # Placeholder returning the parameters. Actual analysis would load the data
  # and call meta or metafor functions.
  list(
    status = "analysis_complete",
    heterogeneity_test = as.logical(heterogeneity_test),
    publication_bias = as.logical(publication_bias),
    sensitivity_analysis = as.logical(sensitivity_analysis)
  )
}

#* Generate forest plot
#* @param TE Numeric vector of effect sizes
#* @param seTE Numeric vector of standard errors
#* @param plot_style Style of plot (classic, modern, journal_specific)
#* @param confidence_level Confidence level for intervals
#* @post /generate_forest_plot
function(TE, seTE, plot_style = "classic", confidence_level = 0.95) {
  if (missing(TE) || missing(seTE)) {
    return(list(
      status = "error",
      message = "Both 'TE' (effect sizes) and 'seTE' (standard errors) must be provided."
    ))
  }
  if (length(TE) != length(seTE)) {
    return(list(
      status = "error",
      message = "'TE' and 'seTE' must be vectors of the same length."
    ))
  }
  plot_path <- tempfile(fileext = ".png")
  png(plot_path)
  forest(meta::metagen(TE = as.numeric(TE), seTE = as.numeric(seTE), level = confidence_level * 100))
  dev.off()
  list(status = "plot_generated", path = plot_path, style = plot_style, conf_level = confidence_level)
}

#* Assess publication bias
#* @param methods List of methods to run
#* @post /assess_publication_bias
function(methods = c("funnel_plot")) {
  list(status = "bias_assessed", methods = methods)
}

#* Generate report
#* @param format Report format (html, pdf, word)
#* @param include_code Include R code in the report
#* @post /generate_report
function(format = "html", include_code = FALSE) {
  list(status = "report_generated", format = format, include_code = as.logical(include_code))
}

# Start the server if this script is run directly
if (identical(environment(), globalenv())) {
  pr() %>%
    pr_run(host = "0.0.0.0", port = 8080)
}
