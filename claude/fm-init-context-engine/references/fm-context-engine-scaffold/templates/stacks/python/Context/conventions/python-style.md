---
last_verified: {{TODAY}}
---

# Python Style

Seeded by the context-engine `python` adapter. This is a starting point — tighten as the project develops, and record contested choices as ADRs.

Statements here are platform facts, guardrails, or **Default:** choices; the conventions README explains the difference and how to deviate.

## Project shape

- **Default:** `pyproject.toml` is the single project definition (metadata, dependencies, tool config) — no `setup.py`/`setup.cfg` remnants.
- **Default:** `src/` layout (`src/<package>/`) over flat layout — it catches "works only because cwd is the repo" import bugs.
- **Default:** the package's public surface is what `src/<package>/__init__.py` exports (`__all__`); everything else is internal and may change freely.

## Tooling

- **Default:** `ruff` for linting AND formatting (one tool, one config block in `pyproject.toml`); run it before considering work done.
- **Default:** `pytest` for tests, under `tests/`, mirroring the package structure.
- One virtual environment per project (`uv`/`venv`); never install into the system interpreter.

## Typing

- **Default:** type hints on every public function/method signature; run a checker (`mypy`/`pyright`) if the project adopts one — record the choice as an ADR.
- **Default:** modern syntax: `X | None` over `Optional[X]`, builtin generics (`list[str]`) over `typing.List`.
- **Default:** `dataclass` (or `pydantic` where validation matters) for structured data over bare dicts crossing function boundaries.

## Idioms

- **Default:** `pathlib.Path` over `os.path` string juggling.
- Context managers for every resource (`with open(...)`, sessions, locks).
- Raise specific exceptions; never bare `except:` — catch narrowly, add context, re-raise.
- **Default:** f-strings for formatting; logging via the `logging` module (lazy `%` args in log calls, not f-strings, when the message is hot).

## Docstrings

- **Default:** every public function/class gets a docstring — one summary line, then params/returns for non-obvious signatures. Pick one style (Google/NumPy) and stay with it.
