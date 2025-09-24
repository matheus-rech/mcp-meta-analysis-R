import { MetaAnalysisClient } from './index.js';
import { readFile, access } from 'fs/promises';

async function run() {
  const client = new MetaAnalysisClient('http://localhost:8080/mcp');
  await client.connect();

  await client.initializeMetaAnalysis({
    study_type: 'clinical_trial',
    effect_measure: 'OR',
    analysis_model: 'random'
  });

  try {
    await access('studies.csv');
  } catch (err) {
    throw new Error("The file 'studies.csv' does not exist. Please provide the file and try again.");
  }
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
