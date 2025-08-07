MetaAnalysisClient <- R6::R6Class(
  "MetaAnalysisClient",
  public = list(
    base_url = NULL,
    initialize = function(base_url) {
      self$base_url <- sub("/$", "", base_url)
    },
    call_endpoint = function(name, params) {
      url <- paste0(self$base_url, "/", name)
      resp <- httr::POST(url, body = jsonlite::toJSON(params, auto_unbox = TRUE), encode = "json")
      httr::stop_for_status(resp)
      httr::content(resp, as = "parsed", type = "application/json")
    },
    initialize_meta_analysis = function(params) {
      self$call_endpoint("initialize_meta_analysis", params)
    },
    upload_study_data = function(params) {
      self$call_endpoint("upload_study_data", params)
    },
    perform_meta_analysis = function(params) {
      self$call_endpoint("perform_meta_analysis", params)
    },
    generate_forest_plot = function(params) {
      self$call_endpoint("generate_forest_plot", params)
    },
    assess_publication_bias = function(params) {
      self$call_endpoint("assess_publication_bias", params)
    },
    generate_report = function(params) {
      self$call_endpoint("generate_report", params)
    }
  )
)
