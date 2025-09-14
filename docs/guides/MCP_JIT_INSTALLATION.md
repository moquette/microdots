# MCP Just-In-Time Installation

## Overview

MCP (Model Context Protocol) servers in this dotfiles setup use **just-in-time (JIT) installation**, meaning they are installed automatically on first use rather than during initial setup.

## How It Works

All MCP servers are configured with `npx -y` in `servers.json`:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", ...]
    }
  }
}
```

The `-y` flag tells npx to automatically install and run the package without prompting.

## Benefits

1. **Faster Initial Setup** - Dotfiles installation doesn't need to download MCP packages
2. **Always Latest Version** - Servers are fetched fresh when needed
3. **Minimal Disk Usage** - Only installed servers take up space
4. **No Version Conflicts** - Each server manages its own dependencies

## Expected Behavior

When running tests or audits:
- MCP packages will appear as "missing" or "not installed" - **this is normal**
- The packages install automatically when Claude Code first uses them
- No manual installation is required

## Server List

The following servers are configured for JIT installation:
- `@modelcontextprotocol/server-filesystem` - File system operations
- `@modelcontextprotocol/server-memory` - Knowledge graph
- `@modelcontextprotocol/server-sequential-thinking` - Problem solving
- `@modelcontextprotocol/server-puppeteer` - Web automation
- `@upstash/context7-mcp` - Documentation retrieval
- `openmemory` - Persistent memory

## Testing

To verify JIT configuration is working:

```bash
# Run the JIT installation test
./tests/integration/test_mcp_jit_installation.sh

# Check that servers.json uses npx -y
grep -c '"npx"' ~/.dotlocal/claude/mcp/servers.json
grep -c '"-y"' ~/.dotlocal/claude/mcp/servers.json
# Both counts should match
```

## Troubleshooting

If an MCP server fails to start:
1. Check internet connection (packages download on first use)
2. Verify npm/npx is installed: `command -v npx`
3. Try manually: `npx -y @modelcontextprotocol/server-filesystem --help`
4. Check Claude Code logs for specific error messages

## Manual Pre-Installation (Optional)

If you prefer to pre-install servers (not recommended):

```bash
# Install all MCP servers globally
npm install -g \
  @modelcontextprotocol/server-filesystem \
  @modelcontextprotocol/server-memory \
  @modelcontextprotocol/server-sequential-thinking \
  @modelcontextprotocol/server-puppeteer \
  @upstash/context7-mcp \
  openmemory
```

Note: Pre-installation defeats the purpose of JIT and may cause version issues.

## Summary

**"Missing" MCP packages are not an error** - they are configured to install automatically when needed. This is the intended, optimal behavior for the system.