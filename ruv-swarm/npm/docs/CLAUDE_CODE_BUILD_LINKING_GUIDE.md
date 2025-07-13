# Claude Code Build and Linking Guide for ruv-swarm

This guide provides step-by-step instructions for building and linking ruv-swarm for local development with Claude Code.

## Prerequisites

- Node.js >= 18.20.8
- npm >= 9.0.0
- Claude Code CLI installed
- Git for version control

## Building and Linking ruv-swarm

### 1. Clone and Navigate to Repository

```bash
git clone https://github.com/ruvnet/ruv-FANN.git
cd ruv-FANN/ruv-swarm/npm
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Update Version for Local Development

Edit `package.json` to add a suffix to distinguish local builds:

```json
{
  "version": "1.0.18-bugfix"  // or "1.0.18-local", etc.
}
```

### 4. Build the Package (if needed)

```bash
npm run build:all  # Builds WASM and other components
```

### 5. Create Global npm Link

```bash
# Remove any existing link
npm unlink -g

# Create new link
npm link
```

### 6. Verify Link

```bash
# Check global packages
npm ls -g --depth=0 | grep ruv-swarm
# Should show: ruv-swarm@1.0.18-bugfix -> /path/to/ruv-FANN/ruv-swarm/npm

# Verify executable
which ruv-swarm
# Should show: /opt/homebrew/bin/ruv-swarm (or similar)

# Test command
ruv-swarm --version
# Should show: 1.0.18-bugfix
```

## Configuring Claude Code MCP Server

### 1. Remove Existing MCP Servers

```bash
# List current servers
claude mcp list

# Remove old servers
claude mcp remove ruv-swarm-local
```

### 2. Add Local Development Server

```bash
# Add with stability flag for production use
claude mcp add ruv-swarm-local "ruv-swarm mcp start --stability"

# For testing/debugging (no timeout)
claude mcp add ruv-swarm-debug "ruv-swarm mcp start"
```

### 3. Verify Configuration

```bash
claude mcp list
# Should show: ruv-swarm-local: ruv-swarm mcp start --stability
```

## Troubleshooting

### MCP Server Fails to Start

1. **Check Logs**
   ```bash
   # Find log directory
   ls ~/Library/Caches/claude-cli-nodejs/*/mcp-logs-ruv-swarm-local/
   
   # View latest log
   tail -f ~/Library/Caches/claude-cli-nodejs/*/mcp-logs-ruv-swarm-local/*.txt
   ```

2. **Common Issues**
   - `ENOENT` error: npm link not properly created
   - `Module not found`: Dependencies not installed
   - `WASM loading failed`: Need to build WASM components

### Fixing Link Issues

1. **Complete Clean and Re-link**
   ```bash
   # Unlink globally
   npm unlink -g
   
   # Clean npm cache
   npm cache clean --force
   
   # Remove node_modules
   rm -rf node_modules
   
   # Reinstall and link
   npm install
   npm link
   ```

2. **Verify Executable Permissions**
   ```bash
   ls -la bin/
   # All .js files should have execute permissions (rwxr-xr-x)
   
   # Fix if needed
   chmod +x bin/*.js
   ```

### Testing MCP Server

1. **Direct Test**
   ```bash
   # Test MCP server directly
   ruv-swarm mcp start --stability
   # Should show initialization messages and wait for input
   # Press Ctrl+C to exit
   ```

2. **Test in Claude Code**
   ```bash
   # Restart Claude Code to reload MCP servers
   # In your Claude Code session, check if ruv-swarm tools are available
   ```

## Development Workflow

1. **Make Changes** to ruv-swarm source code
2. **Rebuild** if necessary (for WASM changes)
3. **No need to re-link** - changes are immediate
4. **Restart Claude Code** to reload MCP server with changes

## Best Practices

1. **Version Naming**: Use suffixes like `-local`, `-dev`, or `-bugfix` for local builds
2. **Clean Builds**: Run `npm run build:all` after major changes
3. **Test First**: Always test with `ruv-swarm mcp start` before adding to Claude Code
4. **Check Logs**: Monitor MCP logs when debugging connection issues
5. **Use Stability Flag**: Add `--stability` for production use to prevent timeouts

## Quick Commands Reference

```bash
# Build everything
npm run build:all

# Link for development
npm link

# Test MCP server
ruv-swarm mcp start --stability

# Add to Claude Code
claude mcp add ruv-swarm-local "ruv-swarm mcp start --stability"

# Check status
claude mcp list

# View logs (macOS)
tail -f ~/Library/Caches/claude-cli-nodejs/*/mcp-logs-ruv-swarm-local/*.txt
```

## Important Notes

- The npm link creates a global symlink to your local development directory
- Changes to JavaScript files take effect immediately (no rebuild needed)
- Changes to WASM require rebuilding with `npm run build:wasm`
- Claude Code must be restarted to reload MCP servers
- Use `--stability` flag to prevent connection timeouts in production use