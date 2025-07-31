library(plumber)
pr <- plumb('scripts/plumber.R')
pr$run(host='0.0.0.0', port=8080)
