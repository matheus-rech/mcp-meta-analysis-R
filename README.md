
# MCP Meta-Analysis

This repository contains a meta-analysis server implementation with multiple client options.

## Features
- Upload study data (CSV/Excel)
- Run a meta-analysis with the **meta** and **metafor** packages
- Generate forest and funnel plots with flexible input options
- Produce HTML/PDF/Word reports via R Markdown
- REST API implemented with **plumber**
- Comprehensive input validation and error handling
- Containerized using Docker

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

## Python Client

The `python_client` directory provides a Python async client for the MCP Meta-Analysis server with proper error handling and input validation.

### Installing Dependencies

```bash
cd python_client
pip install -r requirements.txt
```

### Example Usage

```python
import asyncio
from python_client import MetaAnalysisClient

async def example():
    async with MetaAnalysisClient("http://localhost:8080") as client:
        # Initialize meta-analysis
        await client.initialize_meta_analysis(
            study_type="clinical_trial",
            effect_measure="OR",
            analysis_model="random"
        )
        
        # Upload study data
        csv_data = """study,effect_size,se
Study1,0.2,0.05
Study2,-0.1,0.06
Study3,0.3,0.04"""
        
        await client.upload_study_data(data_content=csv_data, data_format="csv")
        
        # Perform meta-analysis
        await client.perform_meta_analysis()
        
        # Generate forest plot with custom data
        await client.generate_forest_plot(
            te=[0.2, -0.1, 0.3],
            se_te=[0.05, 0.06, 0.04]
        )
        
        # Generate report
        report = await client.generate_report(format="html")
        print("Analysis completed!")

asyncio.run(example())
```

## R Client

The `R` directory includes a small wrapper around the same MCP tools for R users.
Install the `httr`, `jsonlite`, and `R6` packages, then source the script and run the example:

```R
source("R/meta_analysis_client.R")
source("R/example_usage.R")
```

The example script connects to a running MCP server, uploads CSV study data,
performs the analysis, and prints the generated report.

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

## Enhanced Features

### Forest Plot Flexibility
The forest plot endpoint now supports both:
- Using stored analysis data: `POST /generate_forest_plot`
- Direct input of effect sizes: `POST /generate_forest_plot` with `TE` and `seTE` parameters

### Comprehensive Input Validation
All endpoints now include:
- Parameter validation with descriptive error messages
- Proper HTTP status codes (400 for bad requests, 413 for large files, 500 for server errors)
- Data type and value validation
- Required field checking

## Development

The server code resides in `scripts/`. Templates for reports are in `templates/`.

```bash
Rscript scripts/mcp_server.R
```

This will start the API on port 8080.

