# MCP Meta-Analysis Server

This repository provides a minimal implementation of an MCP (Model Context Protocol) server for performing meta-analysis in R.

## Features
- Upload study data (CSV/Excel)
- Run a meta-analysis with the **meta** and **metafor** packages
- Generate forest and funnel plots
- Produce a simple HTML/PDF/Word report via R Markdown
- REST API implemented with **plumber**
- Containerized using Docker

## Usage

1. Build the Docker image

```bash
docker build -t mcp-meta .
```

2. Run the container

```bash
docker run -p 8080:8080 mcp-meta
```

3. Interact with the API using any HTTP client. Example endpoints:
   - `POST /initialize_meta_analysis`
   - `POST /upload_study_data`
   - `POST /perform_meta_analysis`
   - `POST /generate_forest_plot`
   - `POST /assess_publication_bias`
   - `POST /generate_report`

Upload data should contain columns `study`, `effect_size`, and `se`.

## Development

The server code resides in `scripts/`. Templates for reports are in `templates/`.

```bash
Rscript scripts/mcp_server.R
```

This will start the API on port 8080.
