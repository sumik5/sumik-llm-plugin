# Packet Diagrams

Packet diagrams visualize network packet structures and binary protocol layouts. They show bit-level field organization in protocol headers and data structures.

## Basic Syntax

```mermaid
packet-beta
    0-15: "Source Port"
    16-31: "Destination Port"
    32-63: "Sequence Number"
    64-95: "Acknowledgment Number"
```

## Field Definition Syntax

### Classic Bit Range Syntax

Specify exact bit positions:

```mermaid
packet-beta
    0-3: "Version"
    4-7: "IHL"
    8-15: "Type of Service"
    16-31: "Total Length"
```

### Modern Increment Syntax (v11.7.0+)

Use `+N` to automatically increment from previous field:

```mermaid
packet-beta
    +4: "Version"
    +4: "IHL"
    +8: "Type of Service"
    +16: "Total Length"
```

**Advantages:**
- No manual bit calculation
- Automatically tracks position
- Easier to modify field sizes

### Single-Bit Fields

```mermaid
packet-beta
    0: "Flag A"
    1: "Flag B"
    2: "Flag C"
    3-15: "Reserved"
    16-31: "Data"
```

**Or with modern syntax:**

```mermaid
packet-beta
    +1: "Flag A"
    +1: "Flag B"
    +1: "Flag C"
    +13: "Reserved"
    +16: "Data"
```

## Mixing Classic and Modern Syntax

Both syntaxes can be mixed in the same diagram:

```mermaid
packet-beta
    0-7: "Opcode"
    +8: "Flags"
    16-31: "Length"
    +16: "Checksum"
```

## Comments

Add explanatory notes:

```mermaid
packet-beta
    %% IPv4 Header Structure
    0-3: "Version"
    4-7: "IHL"
    %% Quality of Service
    8-15: "DSCP/ECN"
    16-31: "Total Length"
```

## Configuration

### Bits Per Row

Control how many bits are displayed per row (default: 32):

```javascript
%%{
  init: {
    'packet': {
      'bitsperrow': 16
    }
  }
}%%
```

```mermaid
%%{init: {'packet': {'bitsperrow': 16}}}%%
packet-beta
    0-7: "Type"
    8-15: "Code"
    16-31: "Checksum"
    32-63: "Identifier"
```

### Bit Width

Set pixel width per bit (default: 32):

```javascript
%%{init: {'packet': {'bitwidth': 24}}}%%
```

### Padding

Adjust horizontal and vertical padding:

```javascript
%%{init: {'packet': {'paddingx': 10, 'paddingy': 15}}}%%
```

### Row Height

Set row height in pixels (default: 32):

```javascript
%%{init: {'packet': {'rowheight': 40}}}%%
```

### Show Bit Numbers

Toggle bit position labels:

```javascript
%%{init: {'packet': {'showbits': false}}}%%
```

## Use Cases in Software Development

### TCP Header Structure

```mermaid
packet-beta
    title TCP Header
    0-15: "Source Port"
    16-31: "Destination Port"
    32-63: "Sequence Number"
    64-95: "Acknowledgment Number"
    96-99: "Data Offset"
    100-105: "Reserved"
    106: "URG"
    107: "ACK"
    108: "PSH"
    109: "RST"
    110: "SYN"
    111: "FIN"
    112-127: "Window Size"
    128-143: "Checksum"
    144-159: "Urgent Pointer"
```

### IPv4 Packet Header

```mermaid
packet-beta
    title IPv4 Header
    +4: "Version"
    +4: "IHL"
    +8: "DSCP/ECN"
    +16: "Total Length"
    +16: "Identification"
    +3: "Flags"
    +13: "Fragment Offset"
    +8: "TTL"
    +8: "Protocol"
    +16: "Header Checksum"
    +32: "Source IP Address"
    +32: "Destination IP Address"
```

### UDP Datagram Header

```mermaid
packet-beta
    title UDP Header
    0-15: "Source Port"
    16-31: "Destination Port"
    32-47: "Length"
    48-63: "Checksum"
```

### Custom Application Protocol

```mermaid
packet-beta
    title Custom RPC Protocol
    +8: "Version"
    +8: "Message Type"
    +16: "Request ID"
    +32: "Timestamp"
    +16: "Payload Length"
    +16: "Checksum"
    +128: "Payload Data"
```

### WebSocket Frame Format

```mermaid
packet-beta
    title WebSocket Frame
    0: "FIN"
    1-3: "RSV1-3"
    4-7: "Opcode"
    8: "MASK"
    9-15: "Payload Length"
    16-31: "Extended Payload Length (optional)"
    32-63: "Masking Key (if MASK=1)"
```

### Binary File Format Header

```mermaid
packet-beta
    title Custom File Format
    +32: "Magic Number"
    +16: "Version"
    +16: "Flags"
    +32: "File Size"
    +32: "Header Size"
    +32: "Data Offset"
    +32: "Timestamp"
    +64: "Reserved"
```

### DNS Query Header

```mermaid
packet-beta
    title DNS Header
    0-15: "Transaction ID"
    16: "QR"
    17-20: "Opcode"
    21: "AA"
    22: "TC"
    23: "RD"
    24: "RA"
    25-27: "Z"
    28-31: "RCODE"
    32-47: "QDCOUNT"
    48-63: "ANCOUNT"
    64-79: "NSCOUNT"
    80-95: "ARCOUNT"
```

### TLS Record Layer

```mermaid
packet-beta
    title TLS 1.3 Record
    +8: "Content Type"
    +16: "Legacy Version"
    +16: "Length"
    +8: "Encrypted Data (variable)"
```

### Custom Bitfield Structure

```mermaid
packet-beta
    title Feature Flags Register
    0: "Enable Logging"
    1: "Enable Caching"
    2: "Enable Compression"
    3: "Enable Encryption"
    4: "Enable Retry"
    5: "Enable Telemetry"
    6-7: "Log Level"
    8-15: "Max Retries"
    16-31: "Timeout (ms)"
```

### Ethernet Frame Header

```mermaid
packet-beta
    title Ethernet II Frame
    +48: "Destination MAC"
    +48: "Source MAC"
    +16: "EtherType"
    +368: "Payload (46-1500 bytes)"
    +32: "Frame Check Sequence"
```

### HTTP/2 Frame Format

```mermaid
packet-beta
    title HTTP/2 Frame
    +24: "Length"
    +8: "Type"
    +8: "Flags"
    +1: "Reserved"
    +31: "Stream Identifier"
    +64: "Frame Payload (variable)"
```

## Tips for Effective Packet Diagrams

1. **Use modern syntax** - `+N` syntax is easier to maintain than manual bit ranges
2. **Add title** - Use `title` keyword to identify the protocol or structure
3. **Group related fields** - Use comments (`%%`) to separate logical sections
4. **Document flags** - Single-bit flags benefit from clear labeling
5. **Show variable fields** - Indicate optional or variable-length fields in labels
6. **Match standard layouts** - For well-known protocols, follow RFC specifications
7. **Adjust bits per row** - Use 8, 16, or 32 bits per row for optimal readability
8. **Include reserved fields** - Show reserved/padding bits for completeness
9. **Use consistent naming** - Follow naming conventions from protocol specs
10. **Add bit positions** - Keep `showbits: true` for technical documentation

## Common Bit-Per-Row Settings

| Bits Per Row | Best For |
|--------------|----------|
| 8 | Byte-aligned structures, simple flags |
| 16 | Word-aligned protocols, compact display |
| 32 | Standard network protocols (IPv4, TCP, UDP) |
| 64 | 64-bit architectures, timestamps |

## Configuration Example

```mermaid
%%{
  init: {
    'packet': {
      'bitsperrow': 32,
      'bitwidth': 28,
      'paddingx': 5,
      'paddingy': 10,
      'rowheight': 36,
      'showbits': true
    }
  }
}%%
packet-beta
    title Custom Protocol (32-bit aligned)
    +8: "Version"
    +8: "Type"
    +16: "Length"
    +32: "Timestamp"
    +16: "Checksum"
    +16: "Flags"
```

## Styling Considerations

- Packet diagrams inherit theme colors from Mermaid
- Field labels automatically wrap if they exceed available width
- Bit position numbers appear above each row by default
- Reserved/unused fields are visually identical to named fields
