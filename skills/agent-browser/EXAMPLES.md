# agent-browser Practical Examples

Real-world usage examples for common automation scenarios.

## Example 1: Login Flow with State Persistence

```bash
# Initial login
agent-browser open https://app.example.com/login
agent-browser snapshot -i
# Output: textbox "Email" [ref=e1], textbox "Password" [ref=e2], button "Sign In" [ref=e3]

agent-browser fill @e1 "user@example.com"
agent-browser fill @e2 "secretPassword123"
agent-browser click @e3
agent-browser wait --url "**/dashboard"

# Save authenticated state for reuse
agent-browser state save auth-state.json
agent-browser close

# Later: reuse authenticated session
agent-browser state load auth-state.json
agent-browser open https://app.example.com/dashboard
agent-browser snapshot -i
# Already logged in!
```

## Example 2: Form with Multiple Input Types

```bash
agent-browser open https://example.com/registration
agent-browser snapshot -i

# Text inputs
agent-browser fill @e1 "John Doe"           # Name
agent-browser fill @e2 "john@example.com"   # Email
agent-browser fill @e3 "+1-555-123-4567"    # Phone

# Dropdown selection
agent-browser select @e4 "USA"              # Country

# Radio buttons / Checkboxes
agent-browser click @e5                     # Select plan
agent-browser check @e6                     # Terms checkbox

# Date picker (if native input)
agent-browser fill @e7 "2024-12-31"

# File upload
agent-browser upload @e8 /path/to/document.pdf

# Submit
agent-browser click @e9
agent-browser wait --load networkidle
agent-browser wait --text "Registration successful"
```

## Example 3: Data Scraping with JSON Output

```bash
agent-browser open https://example.com/products
agent-browser snapshot -i --json > page-structure.json

# Get specific data
agent-browser get text ".product-title" --json
agent-browser get text ".product-price" --json
agent-browser get attr ".product-image" src --json

# Count items
agent-browser get count ".product-card"

# Pagination scraping loop pattern
agent-browser open https://example.com/products?page=1
agent-browser snapshot -i

# Get data from page 1
agent-browser get text @e1 --json >> results.json

# Go to next page
agent-browser click @e10  # "Next" button
agent-browser wait --load networkidle
agent-browser snapshot -i

# Get data from page 2
agent-browser get text @e1 --json >> results.json
```

## Example 4: Screenshot Documentation

```bash
# Full page screenshot
agent-browser open https://example.com/features
agent-browser wait --load networkidle
agent-browser screenshot features-full.png --full

# Specific element screenshot
agent-browser snapshot -i
agent-browser screenshot hero-section.png --selector "#hero"

# Multiple viewport screenshots
agent-browser set viewport 1920 1080
agent-browser screenshot desktop.png

agent-browser set viewport 768 1024
agent-browser screenshot tablet.png

agent-browser set viewport 375 667
agent-browser screenshot mobile.png

# Generate PDF
agent-browser pdf documentation.pdf --format A4
```

## Example 5: Parallel Testing with Sessions

```bash
# Start multiple isolated sessions
agent-browser --session user1 open https://app.example.com/login
agent-browser --session user2 open https://app.example.com/login
agent-browser --session admin open https://app.example.com/admin/login

# Login as different users (each session is independent)
agent-browser --session user1 snapshot -i
agent-browser --session user1 fill @e1 "user1@example.com"
agent-browser --session user1 fill @e2 "password1"
agent-browser --session user1 click @e3

agent-browser --session user2 snapshot -i
agent-browser --session user2 fill @e1 "user2@example.com"
agent-browser --session user2 fill @e2 "password2"
agent-browser --session user2 click @e3

agent-browser --session admin snapshot -i
agent-browser --session admin fill @e1 "admin@example.com"
agent-browser --session admin fill @e2 "adminpass"
agent-browser --session admin click @e3

# Each session has separate cookies, storage, auth state
agent-browser session list

# Test interaction between users
agent-browser --session user1 open https://app.example.com/chat
agent-browser --session user2 open https://app.example.com/chat
# ... test real-time messaging between users

# Cleanup
agent-browser --session user1 close
agent-browser --session user2 close
agent-browser --session admin close
```

## Example 6: API Authentication & Headers

```bash
# Access authenticated API endpoint
agent-browser open https://api.example.com/dashboard \
  --headers '{"Authorization": "Bearer eyJhbGciOiJIUzI1NiIs..."}'

# Set headers globally for session
agent-browser set headers '{"Authorization": "Bearer TOKEN", "X-API-Key": "key123"}'
agent-browser open https://api.example.com/protected
agent-browser snapshot -i
```

## Example 7: E2E Test Pattern

```bash
#!/bin/bash
# e2e-test.sh - Complete E2E test example

set -e  # Exit on error

echo "Starting E2E test..."

# Setup
agent-browser open https://app.example.com --headed

# Test: User can search for products
agent-browser snapshot -i
agent-browser fill @e1 "laptop"  # Search input
agent-browser click @e2          # Search button
agent-browser wait --load networkidle
agent-browser wait --text "results found"
echo "✓ Search works"

# Test: User can add item to cart
agent-browser snapshot -i
agent-browser click @e3          # First product
agent-browser wait --url "**/product/*"
agent-browser snapshot -i
agent-browser click @e4          # Add to cart
agent-browser wait --text "Added to cart"
echo "✓ Add to cart works"

# Test: User can view cart
agent-browser click @e5          # Cart icon
agent-browser wait --url "**/cart"
agent-browser snapshot -i
CART_COUNT=$(agent-browser get text ".cart-count")
[ "$CART_COUNT" = "1" ] && echo "✓ Cart count correct"

# Test: User can proceed to checkout
agent-browser click @e6          # Checkout button
agent-browser wait --url "**/checkout"
echo "✓ Checkout navigation works"

# Cleanup
agent-browser close
echo "All tests passed!"
```

## Example 8: Handling Dynamic Content

```bash
# Wait for AJAX-loaded content
agent-browser open https://example.com/dashboard
agent-browser wait --load networkidle
agent-browser wait --js "window.dataLoaded === true"
agent-browser snapshot -i

# Infinite scroll handling
agent-browser open https://example.com/feed
agent-browser snapshot -i

# Scroll to load more content
agent-browser scroll down 1000
agent-browser wait --load networkidle
agent-browser snapshot -i  # Re-snapshot to get new elements

# Load more until no new content
PREV_COUNT=0
CURR_COUNT=$(agent-browser get count ".feed-item")
while [ "$CURR_COUNT" -gt "$PREV_COUNT" ]; do
  PREV_COUNT=$CURR_COUNT
  agent-browser scroll down 1000
  agent-browser wait --load networkidle
  CURR_COUNT=$(agent-browser get count ".feed-item")
done
echo "Loaded all $CURR_COUNT items"
```

## Example 9: Modal & Dialog Handling

```bash
agent-browser open https://example.com/settings
agent-browser snapshot -i

# Click button that triggers modal
agent-browser click @e1  # "Delete Account" button

# Wait for modal to appear
agent-browser wait ".modal"
agent-browser snapshot -i  # Re-snapshot to get modal elements

# Interact with modal
agent-browser fill @e5 "DELETE"  # Confirmation input
agent-browser click @e6           # Confirm button

# Handle JavaScript confirm dialog
agent-browser dialog accept

# Or dismiss it
# agent-browser dialog dismiss
```

## Example 10: Working with iFrames

```bash
agent-browser open https://example.com/embed-page
agent-browser snapshot -i  # Main frame content

# List available frames
agent-browser frame list

# Switch to iframe
agent-browser frame select "payment-iframe"
agent-browser snapshot -i  # Now shows iframe content

# Interact within iframe
agent-browser fill @e1 "4111111111111111"  # Card number
agent-browser fill @e2 "12/25"              # Expiry
agent-browser fill @e3 "123"                # CVV
agent-browser click @e4                     # Submit

# Return to main frame
agent-browser frame main
agent-browser snapshot -i
```

## Example 11: Network Interception & Mocking

```bash
# Block analytics and ads
agent-browser network route "**/analytics/*" block
agent-browser network route "**/ads/*" block

# Mock API response for testing
agent-browser network route "**/api/user" fulfill \
  --body '{"name": "Test User", "email": "test@example.com"}'

# Navigate with mocked responses
agent-browser open https://app.example.com
agent-browser snapshot -i

# Check captured requests
agent-browser network requests --json

# Remove interception
agent-browser network unroute "**/api/user"
```

## Example 12: Mobile Testing with Device Emulation

```bash
# Emulate iPhone
agent-browser emulate "iPhone 13"
agent-browser open https://example.com
agent-browser screenshot mobile-ios.png

# Emulate Android
agent-browser emulate "Pixel 5"
agent-browser open https://example.com
agent-browser screenshot mobile-android.png

# Custom viewport with touch
agent-browser set viewport 390 844
agent-browser open https://example.com
agent-browser snapshot -i

# Test responsive design breakpoints
for WIDTH in 320 375 768 1024 1920; do
  agent-browser set viewport $WIDTH 800
  agent-browser screenshot "viewport-${WIDTH}.png"
done
```

## Example 13: Debugging Session

```bash
# Start with debug mode and visible browser
agent-browser --debug --headed open https://buggy-app.example.com

# Check for JavaScript errors
agent-browser errors

# View console messages
agent-browser console

# Start tracing for performance analysis
agent-browser trace start

# Perform actions
agent-browser snapshot -i
agent-browser click @e1
agent-browser fill @e2 "test"
agent-browser click @e3

# Stop and save trace
agent-browser trace stop debug-trace.zip
# Open trace.zip in Playwright Trace Viewer
```

## Example 14: Cookie-based Session Management

```bash
# List current cookies
agent-browser cookies list

# Set custom cookie
agent-browser cookies set "session_id" "abc123"
agent-browser cookies set "user_pref" "dark_mode"

# Get specific cookie value
agent-browser cookies get "session_id"

# Clear and start fresh
agent-browser cookies clear
agent-browser storage local clear
agent-browser storage session clear
```

## Tips for Effective Automation

1. **Always snapshot before interacting** - refs change after DOM updates
2. **Use `-i` flag** - interactive elements only reduces noise
3. **Wait for network idle** after navigation or form submissions
4. **Save state** for authenticated sessions to avoid repeated logins
5. **Use `--json`** for machine-readable output in scripts
6. **Use sessions** for parallel independent tests
7. **Re-snapshot** after any action that changes the DOM
