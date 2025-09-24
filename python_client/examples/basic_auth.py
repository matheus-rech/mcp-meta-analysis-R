"""Basic example of connecting to the server."""
import asyncio
from python_client import MetaAnalysisClient

async def main():
    async with MetaAnalysisClient("http://localhost:8080") as client:
        result = await client.initialize_meta_analysis(study_type="clinical_trial")
        print("Session initialized:", result)

if __name__ == "__main__":
    asyncio.run(main)
