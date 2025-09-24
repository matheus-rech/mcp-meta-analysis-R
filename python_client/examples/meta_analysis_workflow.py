"""Example workflow using the MetaAnalysisClient."""
import anyio
from httpx import BasicAuth
from python_client import MetaAnalysisClient

async def main():
    # Replace credentials and server URL with your deployment details
    auth = BasicAuth("user", "pass")
    async with MetaAnalysisClient("http://localhost:8000/sse", auth=auth) as client:
        await client.initialize_meta_analysis(
            study_type="clinical_trial",
            effect_measure="OR",
            analysis_model="random",
        )
        # TODO: Replace 'path/to/your/study_data.csv' with the path to your study data file
        with open("path/to/your/study_data.csv") as f:
            data_content = f.read()
        await client.upload_study_data(
            data_format="csv",
            data_content=data_content,
            validation_level="basic",
        )
        await client.perform_meta_analysis(
            heterogeneity_test=True,
            publication_bias=True,
            sensitivity_analysis=False,
        )
        await client.generate_forest_plot(plot_style="classic")
        await client.assess_publication_bias(methods=["funnel_plot"])
        await client.generate_report(format="html", include_code=False)

if __name__ == "__main__":
    anyio.run(main)
