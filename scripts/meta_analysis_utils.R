library(meta)
library(metafor)
library(jsonlite)

# Global variable to store uploaded data
.current_data <- NULL

# Validate uploaded data
validate_data <- function(raw_data, format){
  # Write raw data to temporary file for reading
  temp_file <- tempfile(fileext = ifelse(format == "excel", ".xlsx", ".csv"))
  on.exit(unlink(temp_file))
  writeBin(raw_data, temp_file)
  
  # Read data based on format
  data <- tryCatch({
    if(format == 'excel'){
      readxl::read_excel(temp_file)
    } else {
      read.csv(temp_file)
    }
  }, error = function(e) {
    stop(paste("Failed to read", format, "file:", e$message))
  })
  
  # Validate required columns
  required <- c('study', 'effect_size', 'se')
  missing_cols <- setdiff(required, names(data))
  if(length(missing_cols) > 0){
    stop(paste('Missing required columns:', paste(missing_cols, collapse=', ')))
  }
  
  # Validate data types and values
  if (!is.numeric(data$effect_size)) {
    stop("Column 'effect_size' must contain numeric values")
  }
  if (!is.numeric(data$se)) {
    stop("Column 'se' must contain numeric values")
  }
  if (any(data$se <= 0, na.rm = TRUE)) {
    stop("Column 'se' must contain positive values only")
  }
  if (any(is.na(data$effect_size))) {
    stop("Column 'effect_size' cannot contain missing values")
  }
  if (any(is.na(data$se))) {
    stop("Column 'se' cannot contain missing values")
  }
  
  # Store validated data
  if (!exists("meta_analysis_env", envir = .GlobalEnv)) {
    assign("meta_analysis_env", new.env(parent = emptyenv()), envir = .GlobalEnv)
  }
  assign('.current_data', data, envir = get("meta_analysis_env", envir = .GlobalEnv))
  data
}

# Perform meta-analysis using random/fixed automatically
perform_analysis <- function(heterogeneity_test=TRUE, publication_bias=TRUE, sensitivity_analysis=FALSE, effect_measure='SMD'){
  data <- get('.current_data', envir=.GlobalEnv)
  m <- metagen(TE=data$effect_size, seTE=data$se, studlab=data$study, sm=effect_measure, method.tau='DL')
  if(heterogeneity_test){
    hetero <- list(Q = m$Q, df = m$df.Q, p = m$pval.Q, I2 = m$I2)
  } else {
    hetero <- NULL
  }
  if(publication_bias){
    pb <- tryCatch({
      metabias(m)
    }, error=function(e) NA)
  } else {
    pb <- NULL
  }
  assign('.current_result', m, envir=.GlobalEnv)
  list(summary=summary(m), heterogeneity=hetero, publication_bias=pb)
}

# Generate forest plot from stored analysis results
generate_forest_plot <- function(plot_style='classic', confidence_level=0.95, model='random'){
  res <- get('.current_result', envir=.GlobalEnv)
  temp_file <- tempfile(pattern = "forest_plot", fileext = ".png")
  png(temp_file, width=800, height=600)
  comb.fixed <- model %in% c('fixed', 'both')
  comb.random <- model %in% c('random', 'both')
  forest(res, comb.fixed=comb.fixed, comb.random=comb.random, digits=2)
  dev.off()
  temp_file
}

# Generate forest plot from provided effect sizes and standard errors
generate_forest_plot_with_data <- function(TE, seTE, plot_style='classic', confidence_level=0.95, model='random'){
  # Create a meta-analysis object with the provided data
  res <- metagen(TE = TE, seTE = seTE, level = confidence_level * 100, sm = "SMD")
  
  temp_file <- tempfile(pattern = "forest_plot", fileext = ".png")
  png(temp_file, width=800, height=600)
  comb.fixed <- model %in% c('fixed', 'both')
  comb.random <- model %in% c('random', 'both')
  forest(res, comb.fixed=comb.fixed, comb.random=comb.random, digits=2)
  dev.off()
  temp_file
}

# Assess publication bias with funnel plot
assess_publication_bias <- function(methods=c('funnel_plot','egger_test')){
  res <- get('.current_result', envir=.GlobalEnv)
  out <- list()
  if('funnel_plot' %in% methods){
    plot_file <- tempfile(pattern = "funnel_plot_", fileext = ".png")
    png(plot_file, width=800, height=600)
    funnel(res)
    dev.off()
    out$funnel_plot <- plot_file
  }
  if('egger_test' %in% methods){
    out$egger <- tryCatch(ranktest(res), error=function(e) NA)
  }
  out
}

# Generate report
generate_report <- function(format='html', include_code=FALSE){
  res <- get('.current_result', envir=.GlobalEnv)
  temp_file <- tempfile(fileext = paste0('.', format))
  rmarkdown::render('templates/meta_analysis_report.Rmd',
                    output_format = switch(format,
                      html = 'html_document',
                      pdf = 'pdf_document',
                      word = 'word_document'),
                    output_file = temp_file,
                    params = list(result=res, include_code=include_code))
  temp_file
}
