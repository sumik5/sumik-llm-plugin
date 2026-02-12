# ZenUML Diagrams

ZenUML diagrams are specialized sequence diagrams with a more intuitive, code-like syntax. They excel at showing nested method calls and control flow in a visually compact way.

## Basic Syntax

```mermaid
zenuml
    title Order Process
    Client->OrderService.create(order) {
        OrderService->Database.save(order) {
            return saved
        }
        return confirmation
    }
```

**Key difference from standard sequence diagrams**: ZenUML uses curly braces `{}` to represent nested method calls and activation blocks naturally, without explicit activation/deactivation syntax.

## Participants

### Implicit Participants

Participants are automatically created when first used:

```mermaid
zenuml
    title User Authentication
    Client->AuthService.login(credentials)
    AuthService->Database.validateUser(credentials)
    Database->AuthService.userRecord
    AuthService->Client.token
```

### Explicit Participant Declaration

Declare participants with custom labels and symbols:

```mermaid
zenuml
    title Payment Processing
    participant U as "User"
    participant API as "API Gateway"
    @actor User
    @database Database

    U->API.checkout()
    API->Database.createOrder()
```

**Annotators (symbols):**
- `@actor` - Stick figure icon
- `@database` - Database icon
- `@boundary` - Box icon
- `@control` - Circle icon
- `@entity` - Rectangle icon
- `@queue` - Queue icon

## Message Types

### Synchronous Messages (`->`)

Represents a blocking call waiting for a response:

```mermaid
zenuml
    title Synchronous API Call
    Client->API.getUser(id) {
        API->Database.findUser(id) {
            return userRecord
        }
        return user
    }
```

### Asynchronous Messages (`=>`)

Represents a non-blocking call (fire-and-forget):

```mermaid
zenuml
    title Event Publishing
    OrderService=>EventBus.publish("order.created")
    OrderService->Client.response
    EventBus=>EmailService.sendConfirmation()
    EventBus=>InventoryService.reserveStock()
```

### Creation Messages

Create a new participant:

```mermaid
zenuml
    title Factory Pattern
    Client->Factory.createService() {
        Factory->new Service: create
        return serviceInstance
    }
```

### Return Messages

#### Explicit Return (`<-`)

```mermaid
zenuml
    title Explicit Return
    Client->Service.calculate(data) {
        Service->Helper.process(data)
        Helper<-Service: processedData
        return result
    }
```

#### Return Statement

```mermaid
zenuml
    title Return Statement
    Client->Calculator.add(a, b) {
        return a + b
    }
```

#### @return Annotation

```mermaid
zenuml
    title Return Annotation
    Client->Service.getData() {
        Service->Database.query()
        @return queryResult
    }
```

## Control Structures

### Loop Statements

#### While Loop

```mermaid
zenuml
    title Retry Logic
    Client->Service.fetchData() {
        while(retries < 3) {
            Service->ExternalAPI.request() {
                if(success) {
                    return data
                }
                retries = retries + 1
            }
        }
        return error
    }
```

#### For Loop

```mermaid
zenuml
    title Batch Processing
    Scheduler->BatchProcessor.processBatch() {
        for(i = 0; i < batchSize; i++) {
            BatchProcessor->Worker.processItem(i)
        }
    }
```

#### ForEach Loop

```mermaid
zenuml
    title Parallel Processing
    Controller->Service.processOrders(orders) {
        forEach(order in orders) {
            Service=>Worker.process(order)
        }
    }
```

#### Infinite Loop

```mermaid
zenuml
    title Event Loop
    Server->EventLoop.start() {
        loop {
            EventLoop->Queue.poll() {
                if(hasEvent) {
                    EventLoop->Handler.handle(event)
                }
            }
        }
    }
```

### Conditional Statements

#### If-Else

```mermaid
zenuml
    title Conditional Authorization
    Client->API.accessResource() {
        API->AuthService.checkPermission() {
            if(isAuthorized) {
                return granted
            } else {
                return denied
            }
        }
        if(granted) {
            API->Database.fetchResource()
        } else {
            return "403 Forbidden"
        }
    }
```

#### Else-If Chain

```mermaid
zenuml
    title Request Routing
    Client->Gateway.route(request) {
        if(request.type == "user") {
            Gateway->UserService.handle(request)
        } else if(request.type == "order") {
            Gateway->OrderService.handle(request)
        } else if(request.type == "payment") {
            Gateway->PaymentService.handle(request)
        } else {
            return "404 Not Found"
        }
    }
```

### Optional Blocks

```mermaid
zenuml
    title Optional Caching
    Client->Service.getData(id) {
        opt {
            Service->Cache.get(id) {
                if(found) {
                    return cachedData
                }
            }
        }
        Service->Database.query(id)
        Service->Cache.set(id, data)
        return data
    }
```

### Parallel Execution

```mermaid
zenuml
    title Parallel Service Calls
    Client->Orchestrator.aggregateData() {
        par {
            Orchestrator->UserService.getUser()
            Orchestrator->OrderService.getOrders()
            Orchestrator->PaymentService.getPayments()
        }
        return aggregatedData
    }
```

### Exception Handling

```mermaid
zenuml
    title Error Handling
    Client->Service.processPayment(amount) {
        try {
            Service->PaymentGateway.charge(amount) {
                if(insufficient_funds) {
                    throw "InsufficientFundsError"
                }
                return success
            }
        } catch {
            Service->Logger.error("Payment failed")
            Service->NotificationService.alertUser()
            return failure
        } finally {
            Service->Database.logTransaction()
        }
    }
```

## Nested Method Calls

ZenUML excels at showing deep call stacks:

```mermaid
zenuml
    title Deep Call Stack
    Client->Controller.handleRequest() {
        Controller->Service.processData() {
            Service->Validator.validate(data) {
                Validator->Schema.check(data) {
                    return valid
                }
                return validationResult
            }
            if(valid) {
                Service->Repository.save(data) {
                    Repository->Database.insert(data) {
                        return insertId
                    }
                    return savedEntity
                }
            }
            return result
        }
        return response
    }
```

## Comments

Add explanatory notes using markdown-style comments:

```mermaid
zenuml
    title Documented Flow
    // Initialize connection
    Client->Server.connect() {
        // Validate credentials
        Server->AuthService.authenticate(credentials)

        // Establish session
        Server->SessionManager.createSession() {
            return sessionId
        }

        return connectionEstablished
    }
```

## Use Cases in Software Development

### Microservice Communication Flow

```mermaid
zenuml
    title Order Placement Flow
    @actor Customer
    @boundary APIGateway
    @control OrderService
    @control PaymentService
    @control InventoryService
    @database Database

    Customer->APIGateway.placeOrder(orderData) {
        APIGateway->OrderService.createOrder(orderData) {
            OrderService->InventoryService.checkStock(items) {
                InventoryService->Database.queryStock(items)
                if(inStock) {
                    return available
                } else {
                    return outOfStock
                }
            }

            if(available) {
                OrderService->PaymentService.processPayment(payment) {
                    PaymentService->Database.recordTransaction()
                    return paymentConfirmed
                }

                if(paymentConfirmed) {
                    OrderService->Database.saveOrder(order)
                    OrderService=>InventoryService.reserveStock(items)
                    return orderConfirmation
                } else {
                    return paymentFailed
                }
            } else {
                return stockUnavailable
            }
        }
        return response
    }
```

### Error Handling and Retry Logic

```mermaid
zenuml
    title Resilient API Call
    Client->APIClient.fetchData() {
        try {
            while(attempts < maxRetries) {
                APIClient->ExternalService.request() {
                    if(status == 200) {
                        return data
                    } else if(status == 429) {
                        throw "RateLimitError"
                    } else if(status >= 500) {
                        throw "ServerError"
                    }
                }
                attempts = attempts + 1
                APIClient->Timer.wait(backoffDelay)
            }
        } catch {
            APIClient->Logger.error("Max retries exceeded")
            APIClient->Cache.getFallbackData()
            return fallbackData
        }
    }
```

### Authentication and Authorization

```mermaid
zenuml
    title JWT Authentication Flow
    Client->API.accessProtectedResource() {
        API->AuthMiddleware.verifyToken(token) {
            try {
                AuthMiddleware->JWTService.decode(token) {
                    JWTService->Cache.getPublicKey()
                    return payload
                }

                AuthMiddleware->Database.validateUser(payload.userId) {
                    if(userExists && userActive) {
                        return userInfo
                    } else {
                        throw "InvalidUser"
                    }
                }

                return authorized
            } catch {
                return unauthorized
            }
        }

        if(authorized) {
            API->ResourceService.fetchResource() {
                ResourceService->Database.query()
                return resource
            }
        } else {
            return "401 Unauthorized"
        }
    }
```

### Asynchronous Event-Driven Architecture

```mermaid
zenuml
    title Event-Driven Order Processing
    OrderAPI->OrderService.createOrder(orderData) {
        OrderService->Database.saveOrder(orderData)
        OrderService=>EventBus.publish("order.created", order)
        return orderId
    }

    // Asynchronous event consumers
    EventBus=>EmailService.onOrderCreated(order) {
        EmailService->TemplateEngine.render("order_confirmation")
        EmailService->SMTPServer.send(email)
    }

    EventBus=>InventoryService.onOrderCreated(order) {
        InventoryService->Database.decrementStock(order.items)
        InventoryService=>EventBus.publish("inventory.updated")
    }

    EventBus=>AnalyticsService.onOrderCreated(order) {
        AnalyticsService->DataWarehouse.trackEvent(order)
    }
```

### Database Transaction with Rollback

```mermaid
zenuml
    title Transactional Update
    Service->Database.beginTransaction() {
        try {
            Database->AccountTable.debit(fromAccount, amount) {
                if(insufficientBalance) {
                    throw "InsufficientBalance"
                }
                return success
            }

            Database->AccountTable.credit(toAccount, amount)

            Database->TransactionLog.record(transaction)

            Database.commit()
            return success
        } catch {
            Database.rollback()
            Service->Logger.error("Transaction failed")
            return failure
        }
    }
```

## Tips for Effective ZenUML Diagrams

1. **Use nesting for call stacks** - Curly braces naturally show method call hierarchy
2. **Leverage control structures** - `if/else`, `while`, `try/catch` make logic explicit
3. **Separate sync and async** - Use `->` for synchronous, `=>` for asynchronous calls
4. **Add comments** - Use `//` to explain complex logic
5. **Choose appropriate symbols** - Use `@actor`, `@database` etc. for clarity
6. **Show error paths** - Always include `catch` blocks for critical operations
7. **Limit depth** - Too many nested levels become hard to read
8. **Use return statements** - Make data flow explicit with `return` or `@return`

## External Plugin Requirement

ZenUML diagrams require the external plugin:

```javascript
import mermaid from 'mermaid';
import zenuml from '@mermaid-js/mermaid-zenuml';

await mermaid.registerExternalDiagrams([zenuml]);
```

**Note**: This diagram type is not bundled with core Mermaid and must be loaded separately.
