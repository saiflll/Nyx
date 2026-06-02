import os
import inspect
import importlib.util
from typing import Callable, Dict, Any

SKILLS_DIR = "/app/skills"
if not os.path.exists(SKILLS_DIR):
    SKILLS_DIR = "skills"

class ToolScanner:
    def __init__(self):
        self.tools: Dict[str, Callable] = {}
        self.schemas = []
        self.load_skills()

    def load_skills(self):
        if not os.path.exists(SKILLS_DIR):
            return
            
        for filename in os.listdir(SKILLS_DIR):
            if filename.endswith(".py") and not filename.startswith("_"):
                filepath = os.path.join(SKILLS_DIR, filename)
                module_name = filename[:-3]
                
                spec = importlib.util.spec_from_file_location(module_name, filepath)
                if spec and spec.loader:
                    module = importlib.util.module_from_spec(spec)
                    spec.loader.exec_module(module)
                    
                    for name, obj in inspect.getmembers(module):
                        if inspect.isfunction(obj) and obj.__module__ == module_name:
                            self._register_tool(name, obj)

    def _register_tool(self, name: str, func: Callable):
        self.tools[name] = func
        
        # Simple schema generation from docstring
        doc = inspect.getdoc(func) or "No description available."
        desc = doc.split("\n\n")[0].strip()
        
        # Extract params
        sig = inspect.signature(func)
        properties = {}
        required = []
        
        for param_name, param in sig.parameters.items():
            param_type = "string" # Default
            if param.annotation == int: param_type = "integer"
            elif param.annotation == bool: param_type = "boolean"
            
            properties[param_name] = {"type": param_type, "description": ""}
            if param.default == inspect.Parameter.empty:
                required.append(param_name)
                
        schema = {
            "type": "function",
            "function": {
                "name": name,
                "description": desc,
                "parameters": {
                    "type": "object",
                    "properties": properties,
                    "required": required
                }
            }
        }
        self.schemas.append(schema)

    def execute_tool(self, name: str, kwargs: dict) -> Any:
        if name not in self.tools:
            return {"error": f"Tool {name} not found"}
        try:
            return self.tools[name](**kwargs)
        except Exception as e:
            return {"error": str(e)}

scanner = ToolScanner()
