# Microdots AI Coding Agent Instructions

This guide enables AI coding agents to be immediately productive in the Microdots codebase. It distills essential architecture, workflows, and conventions unique to this project.

## Big Picture Architecture
- **Microdots** applies distributed systems principles to dotfiles: each topic (microdot) is a self-contained microservice.
- **Zero Coupling:** Add/remove any topic without breaking others. No cross-topic dependencies except for shared infrastructure (see below).
- **Automatic Discovery:** The filesystem is the registry. Topics are discovered by directory and file naming conventions—no manifests or hardcoded lists.
- **Loading Order:**
  1. `path.zsh` (PATH/env setup)
  2. `*.zsh` (aliases, functions, configs)
  3. `compinit` (completion system)
  4. `completion.zsh` (tab completions)
- **Symlink Management:** Files ending in `.symlink` are linked to `$HOME` without the extension. Use only `core/lib/symlink.sh` functions for symlinks—never call `ln -s` directly.

## Developer Workflows
- **Bootstrap & Install:**
  - `dots bootstrap --install` — Complete setup (symlinks + installation)
  - `dots install` — Run all topic installers
- **Maintenance:**
  - `dots maintenance` — Update packages, clean system
  - `dots relink` — Rebuild symlinks
  - `dots status -v` — Verbose system health
- **Testing:**
  - `tests/run_integration_tests.sh` — 80+ integration tests for topic independence
  - `tests/unit/test_portability.sh` — Detect hardcoded paths
- **Debugging:**
  - `ZSH=~/.dotfiles zsh -x -c 'source ~/.zshrc'` — Trace shell loading
  - `dots repair-infrastructure` — Fix infrastructure symlinks

## Project-Specific Conventions
- **Self-Containment:** All functionality for a topic lives in its directory. No references to other topics.
- **Defensive Programming:** Always check for tool existence before configuring. Graceful failure is required.
- **Command Substitution Safety:** Debug output in functions used with command substitution must go to stderr (>&2), not stdout.
- **Dotlocal System:** Private configs live in `~/.dotlocal/`, discovered by a 5-level precedence system. Local always overrides public.
- **Core Libraries:** Only `core/lib/ui.sh`, `core/lib/common.sh`, and `core/lib/symlink.sh` are shared infrastructure.

## Integration Points & External Dependencies
- **Homebrew:** Architecture-aware setup in `homebrew/`. No packages forced; user controls Brewfile contents.
- **MCP/Claude:** AI agent integration via `claude/` and MCP server setup. See `CLAUDE.md` and `docs/guides/LOCAL_OVERRIDES.md` for details.
- **Infrastructure Symlinks:** Dotlocal auto-creates 6 symlinks for shared access (core, docs, MICRODOTS.md, CLAUDE.md, TASKS.md, COMPLIANCE.md).

## Patterns & Anti-Patterns
- **Do:**
  - Use defensive checks before configuring
  - Follow strict loading order
  - Use only specialized symlink functions
  - Keep all topic logic self-contained
- **Don't:**
  - Reference other topics (except core/lib)
  - Use hardcoded paths/usernames
  - Output debug info to stdout in command substitution contexts
  - Call `ln -s` directly

## Key Files & Directories
- `core/` — Command routing, shared libraries
- `bin/dots` — Main command router
- `zsh/` — Shell config, function autoloading
- `homebrew/` — Package management foundation
- `git/` — Version control config
- `tests/` — Comprehensive test suite
- `docs/guides/` — Essential guides, including:
  - `UI_STYLE_GUIDE.md` — UI library usage and output standards (required for consistent agent output)
  - `LOCAL_OVERRIDES.md` — Dotlocal system documentation
  - `MIGRATION_TO_DOTLOCAL.md` — Migration guide
- `docs/architecture/` — Deep technical documentation:
  - `IMPLEMENTATION.md` — Technical implementation details and internals
  - `COMPLIANCE.md` — System compliance assessment and validation
  - `INFRASTRUCTURE.md` — Infrastructure symlinks and shared components
  - `MICRODOTS.md` — Complete microservices architecture guide
- `docs/reference/` — Reference materials:
  - `GLOSSARY.md` — Complete terminology, commands, and function reference

**All documents in the `docs/` folder are required reading for understanding architecture, compliance, infrastructure, migration, and terminology.**

## Example: Defensive PATH Setup
```zsh
# path.zsh
if [[ -x "/opt/homebrew/bin/mytool" ]]; then
  export PATH="/opt/homebrew/bin:$PATH"
elif [[ -x "/usr/local/bin/mytool" ]]; then
  export PATH="/usr/local/bin:$PATH"
fi
```

## Example: Command Substitution Safety
```bash
resolve_local_path() {
  echo "› Starting discovery..." >&2  # Debug to stderr
  echo "/path/to/local"              # Clean return value
}
local_path=$(resolve_local_path)      # Only gets path
```

---

For more, see `MICRODOTS.md`, `CLAUDE.md`, and `docs/architecture/IMPLEMENTATION.md`.

_If any section is unclear or incomplete, please provide feedback to iterate and improve._
