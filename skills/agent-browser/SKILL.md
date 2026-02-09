---
name: agent-browser
description: Advanced browser automation with semantic locators, state persistence, and network interception. Use when complex browser scenarios require role/label finding, save/load auth, device emulation, or JSON output. Provides rich debugging tools. For simple workflows, use playwright instead.
allowed-tools:
  - Bash(agent-browser:*)
  - Bash(which agent-browser*)
  - Bash(command -v agent-browser*)
  - Bash(npm install -g agent-browser*)
  - Bash(export AGENT_BROWSER_PROFILE*)
---

# Browser Automation with agent-browser

## Prerequisites Check (Auto-Install)

**IMPORTANT:** Before using agent-browser, run these commands:

```bash
# 1. Set storage location to /tmp (prevents cluttering project directories)
export AGENT_BROWSER_PROFILE=/tmp/agent-browser-profile

# 2. Auto-install if not present
which agent-browser || npm install -g agent-browser
```

## Environment Variables

| Variable | Description | Recommended Value |
|----------|-------------|-------------------|
| `AGENT_BROWSER_PROFILE` | Browser profile storage location | `/tmp/agent-browser-profile` |
| `AGENT_BROWSER_SESSION` | Default session name | (optional) |

**Always set `AGENT_BROWSER_PROFILE` before running commands** to avoid creating `.playwright-cli` folders in your working directory.

## Quick Start Workflow

```bash
# 1. Navigate to page
agent-browser open <url>

# 2. Get interactive elements with refs (@e1, @e2, etc.)
agent-browser snapshot -i

# 3. Interact using refs from snapshot
agent-browser click @e1
agent-browser fill @e2 "input text"

# 4. Re-snapshot after DOM changes
agent-browser snapshot -i

# 5. Close browser when done
agent-browser close
```

## Core Workflow Pattern

1. **Navigate**: `agent-browser open <url>`
2. **Snapshot**: `agent-browser snapshot -i` (returns elements with refs like `@e1`, `@e2`)
3. **Interact**: Use refs from snapshot for clicks, fills, etc.
4. **Re-snapshot**: After navigation or significant DOM changes
5. **Repeat**: Until task is complete

## Selectors (Priority Order)

| Type | Syntax | Example | When to Use |
|------|--------|---------|-------------|
| **Refs** | `@e1`, `@e2` | `click @e1` | Always preferred (from snapshot) |
| **CSS** | Standard CSS | `click "#submit"` | When ref unavailable |
| **Text** | `text=...` | `click "text=Submit"` | Match visible text |
| **Role** | `role ...` | `find role button click` | Semantic selection |
| **Label** | `label ...` | `find label "Email" fill "x"` | Form inputs |

## Essential Commands

### Navigation
```bash
agent-browser open <url>      # Navigate to URL
agent-browser back            # Go back
agent-browser forward         # Go forward
agent-browser reload          # Reload page
agent-browser close           # Close browser
```

### Snapshot (Page Analysis)
```bash
agent-browser snapshot        # Full accessibility tree
agent-browser snapshot -i     # Interactive elements only (RECOMMENDED)
agent-browser snapshot -c     # Compact output (remove empty nodes)
agent-browser snapshot -d 3   # Limit depth to 3 levels
agent-browser snapshot -s "#main"  # Scope to CSS selector
```

### Interactions
```bash
agent-browser click @e1           # Click element
agent-browser dblclick @e1        # Double-click
agent-browser fill @e2 "text"     # Clear and type
agent-browser type @e2 "text"     # Type without clearing
agent-browser press Enter         # Press key
agent-browser press Control+a     # Key combination
agent-browser hover @e1           # Hover over element
agent-browser check @e1           # Check checkbox
agent-browser uncheck @e1         # Uncheck checkbox
agent-browser select @e1 "value"  # Select dropdown option
agent-browser scroll down 500     # Scroll page
agent-browser scrollintoview @e1  # Scroll element into view
agent-browser drag @e1 @e2        # Drag from e1 to e2
agent-browser upload @e1 file.png # Upload file
```

### Information Retrieval
```bash
agent-browser get text @e1        # Get element text
agent-browser get value @e1       # Get input value
agent-browser get html @e1        # Get element HTML
agent-browser get attr @e1 href   # Get attribute value
agent-browser get title           # Get page title
agent-browser get url             # Get current URL
agent-browser get count "button"  # Count matching elements
```

### Wait Commands
```bash
agent-browser wait @e1                     # Wait for element visible
agent-browser wait 2000                    # Wait milliseconds
agent-browser wait --text "Success"        # Wait for text to appear
agent-browser wait --url "**/dashboard"    # Wait for URL pattern
agent-browser wait --load networkidle      # Wait for network idle
```

### Screenshots & PDF
```bash
agent-browser screenshot              # Screenshot to stdout
agent-browser screenshot output.png   # Save to file
agent-browser screenshot --full       # Full page screenshot
agent-browser pdf output.pdf          # Generate PDF
```

## Sessions (Parallel Browsers)

Run multiple independent browser instances:

```bash
agent-browser --session login open https://app.example.com
agent-browser --session test open https://test.example.com
agent-browser session list              # List active sessions
agent-browser --session login close     # Close specific session
```

## Authentication Headers

Set HTTP headers for authenticated requests:

```bash
# Set headers when opening URL
agent-browser open https://api.example.com --headers '{"Authorization": "Bearer TOKEN"}'

# Set global headers for session
agent-browser set headers '{"Authorization": "Bearer TOKEN"}'
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `AGENT_BROWSER_SESSION` | Default session name |
| `AGENT_BROWSER_EXECUTABLE_PATH` | Custom browser binary path |

## JSON Output (for Parsing)

Add `--json` for machine-readable output:

```bash
agent-browser snapshot -i --json
agent-browser get text @e1 --json
agent-browser get url --json
```

## Debugging

```bash
agent-browser open example.com --headed  # Show browser window
agent-browser console                    # View console messages
agent-browser errors                     # View page errors
agent-browser --debug open example.com   # Enable debug output
```

## Common Patterns

### Form Submission
```bash
agent-browser open https://example.com/form
agent-browser snapshot -i
agent-browser fill @e1 "user@example.com"    # Email field
agent-browser fill @e2 "password123"          # Password field
agent-browser click @e3                       # Submit button
agent-browser wait --load networkidle
```

### Login & Save State
```bash
agent-browser open https://app.example.com/login
agent-browser snapshot -i
agent-browser fill @e1 "username"
agent-browser fill @e2 "password"
agent-browser click @e3
agent-browser wait --url "**/dashboard"
agent-browser state save auth.json

# Later: restore state
agent-browser state load auth.json
agent-browser open https://app.example.com/dashboard
```

### Data Extraction
```bash
agent-browser open https://example.com/data
agent-browser snapshot -i
agent-browser get text @e1 --json
agent-browser eval "document.querySelectorAll('.item').length"
```

## Additional Resources

- **Detailed Command Reference**: See `COMMANDS.md`
- **Practical Examples**: See `EXAMPLES.md`
- **GitHub Repository**: https://github.com/vercel-labs/agent-browser
