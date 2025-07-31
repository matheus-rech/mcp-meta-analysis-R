"""Authenticate with HTTP basic auth and call the server."""
import anyio
from httpx import BasicAuth
from python_client import MetaAnalysisClient

async def main():
    auth = BasicAuth("user", "pass")
    async with MetaAnalysisClient("http://localhost:8000/sse", auth=auth) as client:
        await client.initialize_meta_analysis(study_type="clinical_trial")
        print("Session initialized")

if __name__ == "__main__":
    anyio.run(main)
