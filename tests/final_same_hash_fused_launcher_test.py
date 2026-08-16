#!/usr/bin/env python3
"""Focused contract for the packaged macOS launcher and identity surface."""

from __future__ import annotations

import ast
import importlib.util
from pathlib import Path
import tempfile


ROOT = Path(__file__).resolve().parents[1]
ORCHESTRATOR = (
    ROOT
    / "qa/blitz_real_save_forensic_20260812/package_candidate"
    / "final_same_hash_orchestrator.py"
)

spec = importlib.util.spec_from_file_location(
    "final_same_hash_fused_launcher_orchestrator", ORCHESTRATOR,
)
assert spec and spec.loader
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


tree = ast.parse(ORCHESTRATOR.read_text("utf-8"), filename=str(ORCHESTRATOR))
run_cell = next(
    node for node in tree.body
    if isinstance(node, ast.FunctionDef) and node.name == "run_cell"
)
process_calls = [
    node for node in ast.walk(run_cell)
    if isinstance(node, ast.Call)
    and isinstance(node.func, ast.Name)
    and node.func.id == "run_managed_process"
]
assert len(process_calls) == 1
argv = process_calls[0].args[0]
assert isinstance(argv, ast.List) and len(argv.elts) == 3
assert isinstance(argv.elts[1], ast.Constant) and argv.elts[1].value == "--game"
assert (
    isinstance(argv.elts[2], ast.Call)
    and isinstance(argv.elts[2].func, ast.Name)
    and argv.elts[2].func.id == "str"
    and isinstance(argv.elts[2].args[0], ast.Name)
    and argv.elts[2].args[0].id == "closure"
)


with tempfile.TemporaryDirectory(
    prefix="ka-final-fused-launcher.", dir="/private/tmp",
) as temp_text:
    temp = Path(temp_text)
    original_user_home = gate.user_home
    gate.user_home = lambda: temp / "home"
    try:
        fused, conventional = gate.identity_paths("test-identity")
        assert fused == temp / "home/Library/Application Support/test-identity"
        assert conventional == (
            temp / "home/Library/Application Support/LOVE/test-identity"
        )

        runtime = temp / "runtime"
        source = runtime / "imported_data/red"
        pokemon = source / "data/generated/pokemon.lua"
        pokemon.parent.mkdir(parents=True)
        pokemon.write_text("return { edition = 'red' }\n", "utf-8")
        expected_sha256 = gate.tree_sha256(source)

        target = gate.seed_identity_cache(
            runtime, "test-identity", "red",
        )
        assert target == fused / "red"
        assert not conventional.exists() and not conventional.is_symlink()
        gate.verify_identity_cache(
            runtime, "test-identity", "red", target, expected_sha256,
        )

        conventional.mkdir(parents=True)
        try:
            gate.verify_identity_cache(
                runtime, "test-identity", "red", target, expected_sha256,
            )
        except gate.GateError as exc:
            assert "conventional LOVE identity fallback is present" in str(exc)
        else:
            raise AssertionError("conventional LOVE identity fallback passed")

        second_fused, second_conventional = gate.identity_paths(
            "preexisting-conventional",
        )
        second_conventional.mkdir(parents=True)
        try:
            gate.seed_identity_cache(
                runtime, "preexisting-conventional", "red",
            )
        except gate.GateError as exc:
            assert "identity is not fresh" in str(exc)
        else:
            raise AssertionError("non-fresh conventional identity was overwritten")
        assert not second_fused.exists() and not second_fused.is_symlink()
    finally:
        gate.user_home = original_user_home


print("PASS fused macOS --game launcher and single identity surface")
