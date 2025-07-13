# Claude Code MCP Server Build & Linking Guide

This guide covers building, linking, and configuring ruv-swarm as an MCP server for Claude Code.

## Prerequisites

- Node.js v18+ installed
- npm or yarn package manager
- Claude Code CLI installed (`npm install -g @anthropic/claude-code`)
- Rust toolchain (for building WASM components)

## Project Structure

```
ruv-swarm/
├── npm/                    # NPM package root
│   ├── package.json       # Main package configuration
│   ├── bin/               # Executable scripts
│   │   ├── ruv-swarm.js   # Main CLI entry point
│   │   └── ruv-swarm-secure.js  # Secure MCP server
│   ├── src/               # Source code
│   │   └── mcp/          # MCP server implementation
│   └── wasm/             # WASM bindings
│       ├── package.json  # WASM package config (needs "type": "module")
│       ├── ruv_swarm_wasm.js
│       └── ruv_swarm_wasm_bg.wasm
```

## Build Process

### 1. Clean Previous Builds
```bash
cd ruv-swarm/npm
rm -rf node_modules package-lock.json
npm cache clean --force
```

### 2. Install Dependencies
```bash
npm install
```

### 3. Build WASM Components
```bash
# From project root
cd ../rust
cargo build --release
wasm-pack build --target web --out-dir ../npm/wasm
```

### 4. Fix WASM Module Type
Ensure `ruv-swarm/npm/wasm/package.json` includes:
```json
{
  "type": "module",
  // ... other fields
}
```

### 5. Create Executable Links
```bash
cd ruv-swarm/npm
npm link
```

## MCP Server Configuration

### Binary Requirements

The MCP server binary must:
1. Be executable (`chmod +x`)
2. Have proper shebang (`#!/usr/bin/env node`)
3. Support stdio protocol
4. Handle JSON-RPC 2.0 messages
5. Implement proper shutdown on stdin close

### Key Files

**bin/ruv-swarm-secure.js:**
- Main MCP server entry point
- Implements stdio protocol
- No timeout mechanisms for stability
- Handles graceful shutdown

**src/mcp/server.js:**
- Core MCP server implementation
- Tool registration and handling
- Session management

## Claude Code Integration

### 1. Remove Existing Servers
```bash
# List current servers
claude mcp list

# Remove each server
claude mcp remove ruv-swarm
claude mcp remove ruv-swarm-local
```

### 2. Build for Production
```bash
# Update version in package.json
npm version patch  # or minor/major

# Run tests
npm test

# Build and prepare
npm run build  # if you have a build script
npm pack      # creates tarball for testing
```

### 3. Publish to NPM
```bash
npm publish
```

### 4. Add to Claude Code

**For Published Package:**
```bash
claude mcp add ruv-swarm "npx" "ruv-swarm@VERSION" "mcp" "start"
```

**For Local Development:**
```bash
# From npm directory
claude mcp add ruv-swarm-dev "./bin/ruv-swarm-secure.js" "mcp" "start"
```

## Troubleshooting

### Common Issues

1. **"Module type not specified" Warning**
   - Add `"type": "module"` to wasm/package.json
   
2. **"Command not found" Error**
   - Ensure binary has executable permissions
   - Check shebang line is correct
   
3. **MCP Server Disconnects**
   - Use secure version without timeout
   - Check for unhandled promise rejections
   
4. **"Unknown option" Errors**
   - Claude mcp add doesn't support custom flags
   - Flags go in the command arguments, not claude options

### Verification Steps

1. **Test Binary Directly:**
   ```bash
   ./bin/ruv-swarm-secure.js mcp start
   ```
   Should output JSON-RPC initialization message

2. **Check Claude Config:**
   ```bash
   claude mcp list
   ```
   Should show your server

3. **Test in Claude Code:**
   - Restart Claude Code
   - Try using an MCP tool like `mcp__ruv-swarm__swarm_init`

## Best Practices

1. **Version Pinning**: Always specify exact versions when adding to Claude
2. **Error Handling**: Implement robust error handling in MCP server
3. **Logging**: Use structured logging with session IDs
4. **Graceful Shutdown**: Handle stdin close events properly
5. **No Timeouts**: Avoid connection timeouts for stability

## Example Session

```bash
# Build and test locally
cd ruv-swarm/npm
npm install
npm test

# Test MCP server
./bin/ruv-swarm-secure.js mcp start

# Add to Claude (local)
claude mcp add ruv-swarm-test "./bin/ruv-swarm-secure.js" "mcp" "start"

# Verify
claude mcp list

# Remove and add production version
claude mcp remove ruv-swarm-test
npm publish
claude mcp add ruv-swarm "npx" "ruv-swarm@1.0.18" "mcp" "start"
```

## Security Considerations

1. **Input Validation**: Validate all MCP tool inputs
2. **Sandboxing**: Run in restricted environment
3. **No Direct Execution**: Never execute user-provided commands
4. **Version Pinning**: Use exact versions to prevent supply chain attacks
5. **Local Execution**: MCP servers run locally, not remotely