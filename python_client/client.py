"""
MCP Meta-Analysis Python Client

A Python client for interacting with the MCP Meta-Analysis R server.
This addresses the consistency mentioned in the overall code review comments.
"""

import asyncio
import json
from typing import Dict, List, Optional, Any, Union
import aiohttp


class MetaAnalysisClient:
    """Python client for the MCP Meta-Analysis server."""
    
    def __init__(self, base_url: str = "http://localhost:8080"):
        """
        Initialize the client.
        
        Args:
            base_url: Base URL of the MCP Meta-Analysis server
        """
        self.base_url = base_url.rstrip('/')
        self.session: Optional[aiohttp.ClientSession] = None
    
    async def __aenter__(self):
        """Async context manager entry."""
        await self.connect()
        return self
    
    async def __aexit__(self, exc_type, exc, tb):
        """Async context manager exit."""
        await self.disconnect()
    
    async def connect(self) -> None:
        """Initialize the HTTP session."""
        if self.session is None:
            self.session = aiohttp.ClientSession()
    
    async def disconnect(self) -> None:
        """Close the HTTP session."""
        if self.session is not None:
            await self.session.close()
            self.session = None
    
    async def _call_tool(self, name: str, arguments: Dict[str, Any] | None = None) -> Dict[str, Any]:
        """
        Call a tool on the MCP server.
        
        Args:
            name: Tool name (endpoint path)
            arguments: Tool arguments
            
        Returns:
            Tool response as dictionary
            
        Raises:
            RuntimeError: If client not initialized
            aiohttp.ClientError: For HTTP errors
        """
        if self.session is None:
            raise RuntimeError("Client not initialized. Use async context manager or call connect() first.")
        
        url = f"{self.base_url}/{name}"
        data = arguments or {}
        
        async with self.session.post(url, json=data) as response:
            response.raise_for_status()
            result = await response.json()
            
            # Check for application-level errors
            if isinstance(result, dict) and result.get('status') == 'error':
                raise RuntimeError(f"Server error: {result.get('message', 'Unknown error')}")
            
            return result
    
    async def initialize_meta_analysis(
        self,
        study_type: Optional[str] = None,
        effect_measure: Optional[str] = None,
        analysis_model: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Initialize a new meta-analysis session.
        
        Args:
            study_type: Type of study (clinical_trial, observational, diagnostic)
            effect_measure: Effect measure (OR, RR, MD, SMD, HR)
            analysis_model: Model type (fixed, random, auto)
        """
        return await self._call_tool("initialize_meta_analysis", {
            "study_type": study_type,
            "effect_measure": effect_measure,
            "analysis_model": analysis_model
        })
    
    async def upload_study_data(
        self,
        data_content: str,
        data_format: str = "csv",
        validation_level: str = "basic"
    ) -> Dict[str, Any]:
        """
        Upload study data to the server.
        
        Args:
            data_content: Raw file content as string
            data_format: Data format (csv, excel, revman)
            validation_level: Validation level (basic, comprehensive)
        """
        # Convert string content to binary for compatibility with R server
        # The R server expects raw binary data in req$postBody
        return await self._call_tool("upload_study_data", {
            "data_format": data_format,
            "validation_level": validation_level,
            # Note: This would need special handling for binary data in actual implementation
            "data_content": data_content
        })
    
    async def perform_meta_analysis(
        self,
        heterogeneity_test: bool = True,
        publication_bias: bool = True,
        sensitivity_analysis: bool = False
    ) -> Dict[str, Any]:
        """
        Perform meta-analysis on uploaded data.
        
        Args:
            heterogeneity_test: Whether to perform heterogeneity test
            publication_bias: Whether to assess publication bias
            sensitivity_analysis: Whether to perform sensitivity analysis
        """
        return await self._call_tool("perform_meta_analysis", {
            "heterogeneity_test": heterogeneity_test,
            "publication_bias": publication_bias,
            "sensitivity_analysis": sensitivity_analysis
        })
    
    async def generate_forest_plot(
        self,
        te: Optional[List[float]] = None,
        se_te: Optional[List[float]] = None,
        plot_style: str = "classic",
        confidence_level: float = 0.95
    ) -> Dict[str, Any]:
        """
        Generate forest plot.
        
        Args:
            te: Effect sizes (optional - uses stored data if not provided)
            se_te: Standard errors (optional - uses stored data if not provided)
            plot_style: Plot style (classic, modern, journal_specific)
            confidence_level: Confidence level for intervals
        """
        params = {
            "plot_style": plot_style,
            "confidence_level": confidence_level
        }
        
        if te is not None:
            params["TE"] = te
        if se_te is not None:
            params["seTE"] = se_te
            
        return await self._call_tool("generate_forest_plot", params)
    
    async def assess_publication_bias(
        self,
        methods: List[str] = None
    ) -> Dict[str, Any]:
        """
        Assess publication bias.
        
        Args:
            methods: List of methods (funnel_plot, egger_test)
        """
        if methods is None:
            methods = ["funnel_plot", "egger_test"]
            
        return await self._call_tool("assess_publication_bias", {
            "methods": methods
        })
    
    async def generate_report(
        self,
        format: str = "html",
        include_code: bool = False
    ) -> Dict[str, Any]:
        """
        Generate analysis report.
        
        Args:
            format: Report format (html, pdf, word)
            include_code: Whether to include code in report
        """
        return await self._call_tool("generate_report", {
            "format": format,
            "include_code": include_code
        })


# Example usage
async def example_usage():
    """Example of how to use the Python client."""
    async with MetaAnalysisClient("http://localhost:8080") as client:
        # Initialize meta-analysis
        await client.initialize_meta_analysis(
            study_type="clinical_trial",
            effect_measure="OR",
            analysis_model="random"
        )
        
        # Upload study data (CSV format)
        csv_data = """study,effect_size,se
Study1,0.2,0.05
Study2,-0.1,0.06
Study3,0.3,0.04"""
        
        await client.upload_study_data(
            data_content=csv_data,
            data_format="csv"
        )
        
        # Perform meta-analysis
        await client.perform_meta_analysis(
            heterogeneity_test=True,
            publication_bias=True
        )
        
        # Generate forest plot with custom data
        await client.generate_forest_plot(
            te=[0.2, -0.1, 0.3],
            se_te=[0.05, 0.06, 0.04],
            plot_style="classic"
        )
        
        # Assess publication bias
        await client.assess_publication_bias(
            methods=["funnel_plot", "egger_test"]
        )
        
        # Generate report
        report = await client.generate_report(
            format="html",
            include_code=False
        )
        
        print("Analysis completed successfully!")
        return report


if __name__ == "__main__":
    # Run example
    asyncio.run(example_usage())