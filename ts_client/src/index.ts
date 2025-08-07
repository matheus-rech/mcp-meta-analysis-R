import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';

export class MetaAnalysisClient {
  private client: Client;
  private transport: StreamableHTTPClientTransport;

  constructor(serverUrl: string) {
    this.client = new Client({
      name: 'meta-analysis-client',
      version: '1.0.0'
    });
    this.transport = new StreamableHTTPClientTransport(new URL(serverUrl));
  }

  async connect(): Promise<void> {
    await this.client.connect(this.transport);
  }

  async disconnect(): Promise<void> {
    await this.transport.close();
  }

  async initializeMetaAnalysis(params: {
    study_type: string;
    effect_measure: string;
    analysis_model: string;
  }): Promise<unknown> {
  }

  async uploadStudyData(params: {
    data_format: string;
    data_content: string;
    validation_level: string;
  }) {
    return this.client.callTool({ name: 'upload_study_data', arguments: params });
  }

  async performMetaAnalysis(params: {
    heterogeneity_test?: boolean;
    publication_bias?: boolean;
    sensitivity_analysis?: boolean;
  }) {
    return this.client.callTool({ name: 'perform_meta_analysis', arguments: params });
  }

  async generateForestPlot(params: {
    plot_style?: string;
    confidence_level?: number;
    custom_labels?: Record<string, string>;
  }) {
    return this.client.callTool({ name: 'generate_forest_plot', arguments: params });
  }

  async assessPublicationBias(params: { methods: string[] }) {
    return this.client.callTool({ name: 'assess_publication_bias', arguments: params });
  }

  async generateReport(params: {
    format: string;
    include_code?: boolean;
    journal_template?: string;
  }) {
    return this.client.callTool({ name: 'generate_report', arguments: params });
  }
}
