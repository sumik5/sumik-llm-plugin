# agent-browser Command Reference

This document provides a comprehensive reference for all agent-browser commands.

## Navigation Commands

| Command | Description |
|---------|-------------|
| `open <url>` | Navigate to URL |
| `open <url> --headed` | Navigate with visible browser window |
| `open <url> --headers '{"key":"value"}'` | Navigate with custom HTTP headers |
| `back` | Go back in history |
| `forward` | Go forward in history |
| `reload` | Reload current page |
| `close` | Close browser session |

### Navigation Options

```bash
# Basic navigation
agent-browser open https://example.com

# With headers (e.g., authentication)
agent-browser open https://api.example.com --headers '{"Authorization": "Bearer TOKEN"}'

# With visible browser for debugging
agent-browser open https://example.com --headed

# With custom user agent
agent-browser open https://example.com --headers '{"User-Agent": "Custom Agent"}'
```

## Snapshot Commands

The `snapshot` command returns an accessibility tree with element references.

| Option | Short | Description |
|--------|-------|-------------|
| `--interactive` | `-i` | Show only interactive elements (recommended) |
| `--compact` | `-c` | Remove empty nodes |
| `--depth <n>` | `-d` | Limit tree depth |
| `--selector <css>` | `-s` | Scope to CSS selector |
| `--json` | | Output as JSON |

### Snapshot Examples

```bash
# Recommended: interactive elements only
agent-browser snapshot -i

# Compact output for large pages
agent-browser snapshot -i -c

# Scope to specific area
agent-browser snapshot -s "#main-content" -i

# Machine-readable output
agent-browser snapshot -i --json

# Combined options
agent-browser snapshot -i -c -d 5
```

## Interaction Commands

### Mouse Actions

| Command | Description |
|---------|-------------|
| `click <selector>` | Click element |
| `dblclick <selector>` | Double-click element |
| `hover <selector>` | Hover over element |
| `drag <from> <to>` | Drag from one element to another |

### Keyboard Actions

| Command | Description |
|---------|-------------|
| `fill <selector> <text>` | Clear field and type text |
| `type <selector> <text>` | Type text without clearing |
| `press <key>` | Press a single key |
| `press <key1>+<key2>` | Press key combination |

### Key Names

Common key names for `press` command:
- Navigation: `Enter`, `Tab`, `Escape`, `Backspace`, `Delete`
- Arrows: `ArrowUp`, `ArrowDown`, `ArrowLeft`, `ArrowRight`
- Modifiers: `Control`, `Shift`, `Alt`, `Meta` (Cmd on Mac)
- Function: `F1`-`F12`
- Special: `Home`, `End`, `PageUp`, `PageDown`, `Space`

```bash
# Key combinations
agent-browser press Control+a      # Select all
agent-browser press Control+c      # Copy
agent-browser press Control+v      # Paste
agent-browser press Control+Shift+i # DevTools
agent-browser press Meta+Enter     # Mac: Cmd+Enter
```

### Form Controls

| Command | Description |
|---------|-------------|
| `check <selector>` | Check a checkbox |
| `uncheck <selector>` | Uncheck a checkbox |
| `select <selector> <value>` | Select dropdown option |
| `upload <selector> <file>` | Upload file to input |

### Scroll Actions

| Command | Description |
|---------|-------------|
| `scroll up <px>` | Scroll page up |
| `scroll down <px>` | Scroll page down |
| `scroll left <px>` | Scroll page left |
| `scroll right <px>` | Scroll page right |
| `scrollintoview <selector>` | Scroll element into view |

## Information Retrieval

| Command | Description |
|---------|-------------|
| `get text <selector>` | Get visible text content |
| `get value <selector>` | Get input field value |
| `get html <selector>` | Get element's HTML |
| `get attr <selector> <name>` | Get attribute value |
| `get title` | Get page title |
| `get url` | Get current URL |
| `get count <selector>` | Count matching elements |
| `get box <selector>` | Get element bounding box |

### State Verification

| Command | Description |
|---------|-------------|
| `is visible <selector>` | Check if element is visible |
| `is enabled <selector>` | Check if element is enabled |
| `is checked <selector>` | Check if checkbox is checked |

## Wait Commands

| Command | Description |
|---------|-------------|
| `wait <selector>` | Wait for element to be visible |
| `wait <ms>` | Wait for milliseconds |
| `wait --text "<text>"` | Wait for text to appear |
| `wait --url "<pattern>"` | Wait for URL to match pattern |
| `wait --load networkidle` | Wait for network to be idle |
| `wait --load domcontentloaded` | Wait for DOM ready |
| `wait --load load` | Wait for page load |
| `wait --js "<expression>"` | Wait for JS condition to be true |

### Wait Examples

```bash
# Wait for element
agent-browser wait @e1
agent-browser wait "#loading" --hidden  # Wait until hidden

# Wait for network
agent-browser wait --load networkidle

# Wait for URL change
agent-browser wait --url "**/success"
agent-browser wait --url "https://example.com/dashboard"

# Wait for JavaScript condition
agent-browser wait --js "document.readyState === 'complete'"
agent-browser wait --js "window.dataLoaded === true"
```

## Semantic Locators (find command)

Find elements by semantic properties instead of refs:

| Locator Type | Description |
|--------------|-------------|
| `role <role>` | Find by ARIA role |
| `text "<text>"` | Find by visible text |
| `label "<label>"` | Find by associated label |
| `placeholder "<text>"` | Find by placeholder text |
| `alt "<text>"` | Find by alt text (images) |
| `title "<text>"` | Find by title attribute |
| `testid "<id>"` | Find by data-testid |

### Semantic Locator Examples

```bash
# Find by role and interact
agent-browser find role button click --name "Submit"
agent-browser find role textbox fill "hello" --name "Email"

# Find by text
agent-browser find text "Sign In" click
agent-browser find text "Continue" click

# Find by label (forms)
agent-browser find label "Email" fill "user@example.com"
agent-browser find label "Password" fill "secret123"

# Find by placeholder
agent-browser find placeholder "Search..." fill "query"

# Find by test id
agent-browser find testid "submit-button" click
```

## Network Commands

### Request Interception

| Command | Description |
|---------|-------------|
| `network route <pattern> <action>` | Intercept matching requests |
| `network unroute <pattern>` | Stop intercepting |
| `network requests` | List captured requests |

### Network Actions

```bash
# Block specific requests
agent-browser network route "**/*.png" block
agent-browser network route "**/analytics/*" block

# Mock API response
agent-browser network route "**/api/users" fulfill --body '{"users":[]}'

# Continue with modified headers
agent-browser network route "**/api/*" continue --headers '{"X-Custom": "value"}'

# View captured requests
agent-browser network requests
agent-browser network requests --json
```

## Tab & Window Management

| Command | Description |
|---------|-------------|
| `tab list` | List all tabs |
| `tab new <url>` | Open new tab |
| `tab switch <index>` | Switch to tab by index |
| `tab close [index]` | Close tab |
| `window new <url>` | Open new window |
| `window close` | Close current window |

### Frame Navigation

| Command | Description |
|---------|-------------|
| `frame list` | List all frames |
| `frame select <name\|index>` | Switch to frame |
| `frame main` | Return to main frame |

```bash
# Work with iframes
agent-browser frame list
agent-browser frame select "iframe-name"
agent-browser snapshot -i
agent-browser click @e1
agent-browser frame main  # Return to main
```

## Storage Management

### Cookies

| Command | Description |
|---------|-------------|
| `cookies list` | List all cookies |
| `cookies get <name>` | Get specific cookie |
| `cookies set <name> <value>` | Set cookie |
| `cookies delete <name>` | Delete cookie |
| `cookies clear` | Clear all cookies |

### Local/Session Storage

| Command | Description |
|---------|-------------|
| `storage local list` | List localStorage items |
| `storage local get <key>` | Get localStorage value |
| `storage local set <key> <value>` | Set localStorage value |
| `storage local delete <key>` | Delete localStorage item |
| `storage local clear` | Clear localStorage |
| `storage session list` | List sessionStorage items |
| `storage session get <key>` | Get sessionStorage value |
| `storage session set <key> <value>` | Set sessionStorage value |
| `storage session clear` | Clear sessionStorage |

### State Persistence

```bash
# Save authentication state
agent-browser state save auth.json

# Load saved state
agent-browser state load auth.json
```

## Dialog Handling

| Command | Description |
|---------|-------------|
| `dialog accept [text]` | Accept dialog (optional input text) |
| `dialog dismiss` | Dismiss/cancel dialog |

```bash
# Accept alert/confirm
agent-browser dialog accept

# Accept prompt with input
agent-browser dialog accept "my input"

# Dismiss/cancel
agent-browser dialog dismiss
```

## JavaScript Execution

| Command | Description |
|---------|-------------|
| `eval <expression>` | Evaluate JavaScript |
| `eval --file <path>` | Execute JS file |

```bash
# Simple evaluation
agent-browser eval "document.title"
agent-browser eval "window.scrollY"
agent-browser eval "document.querySelectorAll('a').length"

# Modify page
agent-browser eval "document.body.style.zoom = '150%'"
agent-browser eval "localStorage.setItem('key', 'value')"
```

## Screenshots & PDF

| Command | Description |
|---------|-------------|
| `screenshot` | Screenshot to stdout |
| `screenshot <path>` | Save to file |
| `screenshot --full` | Full page screenshot |
| `screenshot --selector <css>` | Screenshot specific element |
| `pdf <path>` | Generate PDF |
| `pdf <path> --format A4` | PDF with specific format |

## Session Management

| Command | Description |
|---------|-------------|
| `--session <name>` | Use named session |
| `session list` | List active sessions |
| `session close <name>` | Close specific session |

```bash
# Create isolated sessions
agent-browser --session site1 open https://site1.com
agent-browser --session site2 open https://site2.com

# Work in specific session
agent-browser --session site1 snapshot -i
agent-browser --session site1 click @e1

# List and manage
agent-browser session list
agent-browser session close site1
```

## Browser Configuration

### Set Commands

| Command | Description |
|---------|-------------|
| `set viewport <width> <height>` | Set viewport size |
| `set geolocation <lat> <lon>` | Set geolocation |
| `set offline <true\|false>` | Toggle offline mode |
| `set headers <json>` | Set global headers |

### Device Emulation

```bash
# Mobile viewport
agent-browser set viewport 375 667

# Emulate device
agent-browser emulate "iPhone 13"
agent-browser emulate "Pixel 5"

# Set geolocation
agent-browser set geolocation 40.7128 -74.0060  # NYC
```

## Debugging & Tracing

| Command | Description |
|---------|-------------|
| `console` | View console messages |
| `errors` | View page errors |
| `trace start` | Start recording trace |
| `trace stop <path>` | Stop and save trace |
| `--debug` | Enable debug output |
| `--headed` | Show browser window |

```bash
# Debug mode
agent-browser --debug open https://example.com

# Capture console
agent-browser console
agent-browser console --json

# Page errors
agent-browser errors

# Performance tracing
agent-browser trace start
# ... perform actions ...
agent-browser trace stop trace.zip
```

## Global Options

| Option | Description |
|--------|-------------|
| `--session <name>` | Use named session |
| `--json` | JSON output format |
| `--headed` | Show browser window |
| `--debug` | Enable debug logging |
| `--timeout <ms>` | Set command timeout |
| `--executable-path <path>` | Custom browser path |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `AGENT_BROWSER_SESSION` | Default session name |
| `AGENT_BROWSER_EXECUTABLE_PATH` | Custom browser binary path |
