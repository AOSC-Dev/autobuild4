#!/usr/bin/env python3

import os
import tomli
import sys

def get_build_backend(root_dir: str) -> str:
    with open(os.path.join(root_dir, "pyproject.toml"), "rb") as f:
        proj = tomli.load(f)
        build_sys = proj.get("build-system", {})
        return build_sys.get("build-backend", "unknown")

if __name__ == "__main__":
    print(get_build_backend(sys.argv[1]))
