import httpx
from mcp.client.session import ClientSession
from mcp.client.sse import sse_client

class MetaAnalysisClient:
    """High level wrapper around MCP meta-analysis server."""

    def __init__(self, url: str, auth: httpx.Auth | None = None):
        self._url = url.rstrip('/')
        self._auth = auth
        self._transport = None
        self._streams = None
        self.session: ClientSession | None = None

    async def __aenter__(self) -> "MetaAnalysisClient":
        self._transport = sse_client(self._url, auth=self._auth)
        self._streams = await self._transport.__aenter__()
        read_stream, write_stream = self._streams
        self.session = ClientSession(read_stream, write_stream)
        await self.session.initialize()
        return self

    async def __aexit__(self, exc_type, exc, tb) -> None:
        if self.session:
            await self.session.aclose()
        if self._transport and self._streams:
            await self._transport.__aexit__(exc_type, exc, tb)

    async def _call_tool(self, name: str, arguments: dict | None = None):
        if self.session is None:
            raise RuntimeError("Client not initialized")
        result = await self.session.call_tool(name, arguments)
        if result.isError:
            raise RuntimeError(result.content[0].text if result.content else "Tool call failed")
        return result.structured_content if hasattr(result, 'structured_content') else result.structuredContent

    async def initialize_meta_analysis(self, **params):
        return await self._call_tool("initialize_meta_analysis", params)

    async def upload_study_data(self, **params):
        return await self._call_tool("upload_study_data", params)

    async def perform_meta_analysis(self, **params):
        return await self._call_tool("perform_meta_analysis", params)

    async def generate_forest_plot(self, **params):
        return await self._call_tool("generate_forest_plot", params)

    async def assess_publication_bias(self, **params):
        return await self._call_tool("assess_publication_bias", params)

    async def generate_report(self, **params):
        return await self._call_tool("generate_report", params)

