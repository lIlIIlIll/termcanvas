#!/usr/bin/env python3
"""Validate the machine-readable permanent architecture fitness manifest."""

from __future__ import annotations

import validate_architecture


def main() -> int:
    errors: list[str] = []
    validate_architecture.validate_fitness(errors)
    if errors:
        for error in errors:
            print(f"fitness validation failed: {error}")
        return 1
    print("architecture fitness manifest ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
