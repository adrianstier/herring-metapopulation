#!/usr/bin/env python3
"""Validate a research repo statistical-model inventory.

Intended use:
  python3 tools/check_model_inventory.py

The script is intentionally conservative and easy to patch. Copy it into a repo
when the repo should own the validation gate.
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

DEFAULT_REQUIRED = [
    "model_id",
    "status",
    "scope",
    "script",
    "instances",
    "model_family",
    "response",
    "predictors_or_structure",
    "outputs",
    "display_items",
    "question_ids",
    "caveat",
]

DEFAULT_STATUSES = {
    "primary",
    "support",
    "sensitivity",
    "diagnostic",
    "exploratory",
    "figure_only",
    "retired",
}

SPECIAL_OUTPUTS = {
    "none",
    "console_only",
    "not_committed",
    "large_gitignored",
    "external",
    "generated",
    "not_applicable",
}

MODEL_CALL = re.compile(
    r"\b("
    r"cmdstan_model|sampling|stan|glmmTMB|lmer|lme|gls|glm|lm|gam|bam|"
    r"adonis2|betadisper|permutest|metaMDS|simper|MARSS|CausalImpact|"
    r"VAR|grangertest|ccf|cor\.test|kruskal\.test|wilcox\.test|t\.test|"
    r"chisq\.test|fisher\.test|aov|dsem|varpart|segmented|breakpoints|"
    r"brm|ulam|jags|MCMCglmm|betareg|zeroinfl|hurdle|coxph|survreg|"
    r"MixedLM|GEE|Logit|OLS|GLM|pymc|bambi|lifelines|sklearn"
    r")\s*\("
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--inventory", type=Path, default=Path("docs/statistical_model_inventory.tsv"))
    parser.add_argument("--display", type=Path, default=Path("docs/display_items.tsv"))
    parser.add_argument("--questions", type=Path, default=Path("docs/question_answer_map.tsv"))
    parser.add_argument("--output", type=Path, default=Path("Output/diagnostics/statistical_model_inventory_check.csv"))
    parser.add_argument("--role-column", default="", help="Project-specific confound/attribution role column.")
    parser.add_argument("--scan-dir", action="append", default=[], help="Directory to scan for model calls. Repeatable.")
    parser.add_argument("--ignore-dir", action="append", default=[], help="Directory prefix to ignore while scanning. Repeatable.")
    parser.add_argument("--ignore-script", action="append", default=[], help="Relative script path to ignore. Repeatable.")
    parser.add_argument("--required-column", action="append", default=[], help="Additional required column. Repeatable.")
    parser.add_argument("--status", action="append", default=[], help="Allowed status value. Repeatable; defaults are used when omitted.")
    return parser.parse_args()


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def split_semicolon(value: str) -> list[str]:
    return [part.strip() for part in (value or "").split(";") if part.strip()]


def strip_comments(text: str, suffix: str) -> str:
    if suffix.lower() in {".r", ".py", ".stan"}:
        return "\n".join(line.split("#", 1)[0] for line in text.splitlines())
    return text


def rel(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def find_role_column(rows: list[dict[str, str]], requested: str) -> str | None:
    if requested:
        return requested
    if not rows:
        return None
    columns = set(rows[0].keys())
    for candidate in ("heatwave_sswd_role", "alternative_driver_role", "confound_role", "attribution_role"):
        if candidate in columns:
            return candidate
    for column in columns:
        if column.endswith("_role"):
            return column
    return None


def maybe_read_ids(path: Path, key: str) -> set[str] | None:
    if not path.exists():
        return None
    rows = read_tsv(path)
    if not rows or key not in rows[0]:
        return set()
    return {row[key] for row in rows if row.get(key)}


def output_exists(root: Path, value: str) -> tuple[bool, str]:
    if value in SPECIAL_OUTPUTS:
        return True, "special"
    if any(char in value for char in "*?["):
        matches = list(root.glob(value))
        if not matches:
            return False, "glob matched nothing"
        if any(path.is_file() and path.stat().st_size == 0 for path in matches):
            return False, "glob matched empty file"
        return True, "glob ok"
    path = root / value
    if not path.exists():
        return False, "missing"
    if path.is_file() and path.stat().st_size == 0:
        return False, "empty"
    return True, "ok"


def scripts_with_model_calls(root: Path, scan_dirs: list[str], ignored_dirs: set[str], ignored: set[str]) -> set[str]:
    if not scan_dirs:
        scan_dirs = [d for d in ("R", "scripts", "src", "analysis", "notebooks") if (root / d).exists()]
    suffixes = {".R", ".r", ".stan", ".py", ".qmd", ".Rmd", ".rmd"}
    found: set[str] = set()
    for scan_dir in scan_dirs:
        base = root / scan_dir
        if not base.exists():
            continue
        for path in base.rglob("*"):
            if not path.is_file() or path.suffix not in suffixes:
                continue
            relpath = rel(path, root)
            if relpath in ignored:
                continue
            if any(relpath == prefix or relpath.startswith(prefix + "/") for prefix in ignored_dirs):
                continue
            try:
                text = strip_comments(path.read_text(encoding="utf-8"), path.suffix)
            except UnicodeDecodeError:
                continue
            if MODEL_CALL.search(text):
                found.add(relpath)
    return found


def main() -> int:
    args = parse_args()
    root = args.root.resolve()
    inventory = args.inventory if args.inventory.is_absolute() else root / args.inventory
    display = args.display if args.display.is_absolute() else root / args.display
    questions = args.questions if args.questions.is_absolute() else root / args.questions
    output = args.output if args.output.is_absolute() else root / args.output

    rows = read_tsv(inventory)
    display_ids = maybe_read_ids(display, "item_id")
    question_ids = maybe_read_ids(questions, "question_id")
    statuses = set(args.status) if args.status else DEFAULT_STATUSES
    required = DEFAULT_REQUIRED + args.required_column
    role_column = find_role_column(rows, args.role_column)
    if role_column:
        required.append(role_column)

    failures: list[str] = []
    checks: list[dict[str, str]] = []
    seen_ids: set[str] = set()
    covered_scripts: set[str] = set()

    if not rows:
        failures.append("model inventory has no rows")
    missing_columns = [col for col in required if rows and col not in rows[0]]
    if missing_columns:
        failures.append("missing required columns: " + ", ".join(missing_columns))

    for row in rows:
        model_id = row.get("model_id", "")
        row_failures: list[str] = []

        for column in required:
            if not row.get(column, "").strip():
                row_failures.append(f"empty {column}")

        if model_id in seen_ids:
            row_failures.append("duplicate model_id")
        seen_ids.add(model_id)

        if row.get("status") not in statuses:
            row_failures.append(f"unknown status: {row.get('status', '')}")

        for script in split_semicolon(row.get("script", "")):
            covered_scripts.add(script)
            if not (root / script).exists():
                row_failures.append(f"missing script: {script}")

        for listed_output in split_semicolon(row.get("outputs", "")):
            ok, reason = output_exists(root, listed_output)
            if not ok:
                row_failures.append(f"{reason} output: {listed_output}")

        if display_ids is not None:
            for item_id in split_semicolon(row.get("display_items", "")):
                if item_id != "none" and item_id not in display_ids:
                    row_failures.append(f"unknown display item: {item_id}")

        if question_ids is not None:
            for qid in split_semicolon(row.get("question_ids", "")):
                if qid != "none" and qid not in question_ids:
                    row_failures.append(f"unknown question_id: {qid}")

        if role_column:
            role = row.get(role_column, "").strip()
            if len(role) < 12:
                row_failures.append(f"{role_column} is too terse")

        passed = not row_failures
        if row_failures:
            failures.append(f"{model_id}: {'; '.join(row_failures)}")
        checks.append({
            "model_id": model_id,
            "status": row.get("status", ""),
            "scope": row.get("scope", ""),
            "script": row.get("script", ""),
            "pass": str(passed),
            "failures": "; ".join(row_failures),
        })

    ignored = set(args.ignore_script)
    ignored_dirs = {prefix.rstrip("/") for prefix in args.ignore_dir}
    missing_scripts = sorted(scripts_with_model_calls(root, args.scan_dir, ignored_dirs, ignored) - covered_scripts)
    if missing_scripts:
        failures.append("scripts with statistical calls missing from model inventory: " + ", ".join(missing_scripts))

    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["model_id", "status", "scope", "script", "pass", "failures"])
        writer.writeheader()
        writer.writerows(checks)

    passed = sum(row["pass"] == "True" for row in checks)
    print(f"[models] {passed}/{len(checks)} model rows pass; wrote {output.relative_to(root)}")
    if failures:
        for failure in failures:
            print(f"  FAIL {failure}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
