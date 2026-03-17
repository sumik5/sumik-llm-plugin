# State Diagrams

State diagrams visualize state machines, showing how systems transition between states based on events. Useful for modeling workflows, protocols, and application states.

## Basic Syntax

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Active: start
    Active --> Idle: stop
    Active --> [*]: terminate
```

## States and Transitions

### Simple States

```mermaid
stateDiagram-v2
    [*] --> Stopped
    Stopped --> Running: start()
    Running --> Stopped: stop()
    Running --> [*]
```

### States with Descriptions

```mermaid
stateDiagram-v2
    s1: Idle State
    s2: Processing Request
    s3: Waiting for Response

    [*] --> s1
    s1 --> s2: request received
    s2 --> s3: sent to API
    s3 --> s1: response completed
```

### Labeled Transitions

```mermaid
stateDiagram-v2
    [*] --> Draft
    Draft --> Review: submit()
    Review --> Draft: request changes
    Review --> Approved: approve()
    Approved --> Published: publish()
    Published --> [*]
```

## Composite States

### Nested States

```mermaid
stateDiagram-v2
    [*] --> NotRunning

    state Running {
        [*] --> Processing
        Processing --> Paused: pause()
        Paused --> Processing: resume()
        Processing --> [*]: complete
    }

    NotRunning --> Running: start()
    Running --> NotRunning: stop()
```

### Multi-Level Nesting

```mermaid
stateDiagram-v2
    state Application {
        [*] --> Frontend

        state Frontend {
            [*] --> Loading
            Loading --> Ready
            Ready --> Error
        }

        state Backend {
            [*] --> Connecting
            Connecting --> Connected
            Connected --> Disconnected
        }

        Frontend --> Backend
    }
```

## Choice States

Conditional branching based on conditions:

```mermaid
stateDiagram-v2
    [*] --> ValidateInput
    ValidateInput --> choice1

    state choice1 <<choice>>
    choice1 --> Success: if valid
    choice1 --> Error: if invalid

    Success --> [*]
    Error --> [*]
```

## Fork and Join States

### Parallel Execution (Fork)

```mermaid
stateDiagram-v2
    state fork_state <<fork>>
    [*] --> fork_state
    fork_state --> TaskA
    fork_state --> TaskB

    TaskA --> join_state
    TaskB --> join_state

    state join_state <<join>>
    join_state --> Complete
    Complete --> [*]
```

### Build Pipeline Example

```mermaid
stateDiagram-v2
    [*] --> BuildStarted

    state fork_parallel <<fork>>
    BuildStarted --> fork_parallel

    fork_parallel --> UnitTests
    fork_parallel --> Linting
    fork_parallel --> SecurityScan

    state join_results <<join>>
    UnitTests --> join_results
    Linting --> join_results
    SecurityScan --> join_results

    join_results --> AllChecksPass

    state AllChecksPass <<choice>>
    AllChecksPass --> Deploy: all passed
    AllChecksPass --> Failed: any failed

    Deploy --> [*]
    Failed --> [*]
```

## Concurrent States

Parallel states using `--` separator:

```mermaid
stateDiagram-v2
    [*] --> Active

    state Active {
        [*] --> UIThread
        UIThread --> UIReady
        --
        [*] --> DataThread
        DataThread --> DataLoaded
    }

    Active --> [*]
```

## Notes

```mermaid
stateDiagram-v2
    [*] --> Connecting
    Connecting --> Connected: success
    Connecting --> Failed: timeout

    note right of Connecting
        Retry up to 3 times
        with exponential backoff
    end note

    note left of Failed
        Log error and
        notify user
    end note

    Connected --> [*]
    Failed --> [*]
```

## Direction

```mermaid
stateDiagram-v2
    direction LR
    [*] --> Step1
    Step1 --> Step2
    Step2 --> Step3
    Step3 --> [*]
```

## Styling

### Class-Based Styling

```mermaid
stateDiagram-v2
    [*] --> Normal
    Normal --> Critical: threshold exceeded
    Critical --> Normal: resolved

    classDef criticalState fill:#f66,stroke:#933,color:#fff,stroke-width:3px
    classDef normalState fill:#6f6,stroke:#393,color:#000

    class Critical criticalState
    class Normal normalState
```

### Inline Styling

```mermaid
stateDiagram-v2
    [*] --> Active
    Active --> Inactive
    Inactive --> [*]

    Active:::highlight

    classDef highlight fill:#ff9,stroke:#f90,stroke-width:2px
```

## Use Cases

### API Request Lifecycle

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Pending: fetch()
    Pending --> Success: 200 OK
    Pending --> Error: 4xx/5xx
    Pending --> Timeout: timeout

    Success --> Idle: reset
    Error --> Idle: retry
    Timeout --> Idle: retry

    note right of Pending
        Loading state
        Show spinner
    end note

    note right of Error
        Show error message
        Log to monitoring
    end note
```

### User Authentication Flow

```mermaid
stateDiagram-v2
    [*] --> Anonymous

    Anonymous --> LoggingIn: login()

    state LoggingIn {
        [*] --> ValidatingCredentials
        ValidatingCredentials --> CheckingMFA
        CheckingMFA --> [*]
    }

    LoggingIn --> Authenticated: success
    LoggingIn --> Anonymous: failure

    Authenticated --> SessionExpired: timeout
    Authenticated --> Anonymous: logout()

    SessionExpired --> LoggingIn: re-authenticate
    SessionExpired --> Anonymous: close session
```

### Order Processing Workflow

```mermaid
stateDiagram-v2
    [*] --> Draft

    Draft --> Submitted: submit()

    state Submitted {
        [*] --> ValidatingStock
        ValidatingStock --> ProcessingPayment
        ProcessingPayment --> [*]
    }

    Submitted --> Processing: validation passed
    Submitted --> Cancelled: validation failed

    state fork_fulfillment <<fork>>
    Processing --> fork_fulfillment

    fork_fulfillment --> PackingItems
    fork_fulfillment --> GeneratingInvoice

    state join_ready <<join>>
    PackingItems --> join_ready
    GeneratingInvoice --> join_ready

    join_ready --> Shipped
    Shipped --> Delivered: delivery confirmed

    Delivered --> [*]
    Cancelled --> [*]
```

### WebSocket Connection States

```mermaid
stateDiagram-v2
    [*] --> Disconnected

    Disconnected --> Connecting: connect()
    Connecting --> Open: handshake success
    Connecting --> Disconnected: handshake failed

    Open --> Closing: close()
    Open --> Disconnected: error / connection lost

    Closing --> Disconnected: closed

    note right of Open
        Heartbeat: ping/pong
        every 30 seconds
    end note

    note right of Disconnected
        Auto-reconnect with
        exponential backoff
    end note
```

## Tips for Effective State Diagrams

1. **Start and end states** - Always include `[*]` for clarity
2. **Meaningful state names** - Use domain-specific terminology
3. **Label transitions** - Show events/conditions that trigger changes
4. **Use composite states** - Group related states to reduce complexity
5. **Document edge cases** - Use notes for error handling and timeouts
6. **Parallel states** - Use fork/join for concurrent operations
7. **Choice states** - Explicitly model conditional logic
