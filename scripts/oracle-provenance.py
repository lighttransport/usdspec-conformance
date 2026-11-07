#!/usr/bin/env python3
"""Print the selected oracle's checked runtime provenance as JSON."""
import json
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tests/next'))
from oracle_runtime import oracle_provenance
print(json.dumps(oracle_provenance(), indent=2))
