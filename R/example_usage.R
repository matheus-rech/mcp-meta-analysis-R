# Example usage of the MetaAnalysisClient R wrapper
library(jsonlite)

client <- MetaAnalysisClient$new("http://localhost:8080/mcp")

# Initialize analysis
client$initialize_meta_analysis(list(
  study_type = "clinical_trial",
  effect_measure = "OR",
  analysis_model = "random"
))

# Upload study CSV data
csv <- readLines("studies.csv")
client$upload_study_data(list(
  data_format = "csv",
  data_content = paste(csv, collapse = "\n"),
  validation_level = "basic"
))

client$perform_meta_analysis(list(
  heterogeneity_test = TRUE,
  publication_bias = TRUE,
  sensitivity_analysis = FALSE
))

client$generate_forest_plot(list(plot_style = "classic"))
client$assess_publication_bias(list(methods = c("funnel_plot")))
report <- client$generate_report(list(format = "html"))

print(report)
