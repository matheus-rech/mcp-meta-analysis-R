
# MCP Meta-Analysis

This repository contains design notes for a meta-analysis server and a simple TypeScript client.

## TypeScript Client

The `ts_client` directory provides a lightweight wrapper around the [modelcontextprotocol/typescript-sdk](https://github.com/modelcontextprotocol/typescript-sdk). It exposes convenience methods for each of the meta-analysis tools described in `meta_analysis_mcp_architecture.md`.

### Installing Dependencies

```
cd ts_client
npm install
```

### Example Usage

The `src/example.ts` script demonstrates how to connect to a running MCP server and perform a full analysis.

```ts
import { MetaAnalysisClient } from './index.js';
import { readFile } from 'fs/promises';

async function run() {
  const client = new MetaAnalysisClient('http://localhost:8080/mcp');
  await client.connect();

  await client.initializeMetaAnalysis({
    study_type: 'clinical_trial',
    effect_measure: 'OR',
    analysis_model: 'random'
  });

  const csv = await readFile('studies.csv', 'utf-8');
  await client.uploadStudyData({
    data_format: 'csv',
    data_content: csv,
    validation_level: 'basic'
  });

  await client.performMetaAnalysis({
    heterogeneity_test: true,
    publication_bias: true,
    sensitivity_analysis: false
  });

  await client.generateForestPlot({ plot_style: 'classic' });
  await client.assessPublicationBias({ methods: ['funnel_plot'] });
  const report = await client.generateReport({ format: 'html' });

  console.log('Report:', report);
  await client.disconnect();
}

run().catch(err => {
  console.error(err);
  process.exit(1);
});
```

Run the script with `npm run example` after installing the dependencies.

## R Client

The `R` directory includes a small wrapper around the same MCP tools for R users.
Install the `httr`, `jsonlite`, and `R6` packages, then source the script and run the example:

```R
source("R/meta_analysis_client.R")
source("R/example_usage.R")
```

The example script connects to a running MCP server, uploads CSV study data,
performs the analysis, and prints the generated report.
=======
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

