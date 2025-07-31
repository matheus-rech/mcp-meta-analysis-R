FROM rocker/r-ver:4.3.0

RUN apt-get update && apt-get install -y \
    pandoc \
    texlive-latex-base \
    texlive-latex-recommended \
    texlive-latex-extra \
    imagemagick \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('plumber','meta','metafor','ggplot2','forestplot','knitr','rmarkdown','dplyr','readxl','jsonlite'), repos='https://cran.rstudio.com/')"

WORKDIR /meta_analysis

COPY scripts/ /meta_analysis/scripts/
COPY templates/ /meta_analysis/templates/

EXPOSE 8080

USER non-root
CMD ["Rscript", "/meta_analysis/scripts/mcp_server.R"]
