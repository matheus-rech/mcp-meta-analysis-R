library(meta)
library(metafor)
library(jsonlite)

# Global variable to store uploaded data
.current_data <- NULL

# Validate uploaded data
validate_data <- function(path, format){
  if(format == 'excel'){
    data <- readxl::read_excel(path)
  } else {
    data <- read.csv(path)
  }
  required <- c('study', 'effect_size', 'se')
  missing_cols <- setdiff(required, names(data))
  if(length(missing_cols) > 0){
    stop(paste('Missing columns:', paste(missing_cols, collapse=', ')))
  }
  if (!exists("meta_analysis_env", envir = .GlobalEnv)) {
    assign("meta_analysis_env", new.env(parent = emptyenv()), envir = .GlobalEnv)
  }
  assign('.current_data', data, envir = get("meta_analysis_env", envir = .GlobalEnv))
  data
}

# Perform meta-analysis using random/fixed automatically
perform_analysis <- function(heterogeneity_test=TRUE, publication_bias=TRUE, sensitivity_analysis=FALSE){
  data <- get('.current_data', envir=.GlobalEnv)
  m <- metagen(TE=data$effect_size, seTE=data$se, studlab=data$study, sm='SMD', method.tau='DL')
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

# Generate forest plot
generate_forest_plot <- function(plot_style='classic', confidence_level=0.95){
  res <- get('.current_result', envir=.GlobalEnv)
  temp_file <- tempfile(pattern = "forest_plot", fileext = ".png")
  png(temp_file, width=800, height=600)
  forest(res, comb.fixed=FALSE, comb.random=TRUE, digits=2)
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
  rmarkdown::render('templates/meta_analysis_report.Rmd',
                    output_format = switch(format,
                      html = 'html_document',
                      pdf = 'pdf_document',
                      word = 'word_document'),
                    output_file = { 
                      temp_file <- tempfile(fileext = paste0('.', format))
                      temp_file
                    },
                    params = list(result=res, include_code=include_code))
  temp_file
}
