# Mindmaps

Mindmaps visualize hierarchical information radiating from a central concept. Useful for brainstorming, organizing ideas, and documenting system architectures.

## Basic Syntax

```mermaid
mindmap
    root((Central Topic))
        Branch A
            Leaf 1
            Leaf 2
        Branch B
            Leaf 3
```

## Indentation-Based Hierarchy

Mindmaps use indentation to define parent-child relationships:

```mermaid
mindmap
    root((Project Planning))
        Requirements
            Functional
            Non-functional
        Design
            Architecture
            UI/UX
        Implementation
            Backend
            Frontend
        Testing
            Unit
            Integration
            E2E
```

## Node Shapes

### Default (Rounded Rectangle)

```mermaid
mindmap
    root((Core))
        Default Node
            Nested Default
```

### Square Brackets

```mermaid
mindmap
    root((System))
        [Module A]
            [Component 1]
            [Component 2]
```

### Parentheses (Rounded)

```mermaid
mindmap
    root((Center))
        (Option A)
        (Option B)
```

### Double Parentheses (Circle)

```mermaid
mindmap
    root((Main))
        ((Important))
        ((Critical))
```

### Bang Shape

```mermaid
mindmap
    root((Topic))
        ))Alert((
        ))Warning((
```

### Cloud Shape (Hexagon)

```mermaid
mindmap
    root((Ideas))
        {{Concept A}}
        {{Concept B}}
```

### Mixed Shapes

```mermaid
mindmap
    root((System Architecture))
        [Frontend]
            (React)
            (Vue)
        [Backend]
            (Node.js)
            (Python)
        {{Database}}
            ((PostgreSQL))
            ((MongoDB))
        ))Critical((
            [Security]
            [Performance]
```

## Icons

Using Font Awesome:

```mermaid
mindmap
    root((Project))
        Development ::icon(fa fa-code)
            Frontend ::icon(fa fa-desktop)
            Backend ::icon(fa fa-server)
        Testing ::icon(fa fa-check-circle)
            Unit ::icon(fa fa-flask)
            E2E ::icon(fa fa-robot)
        Deployment ::icon(fa fa-rocket)
            Staging ::icon(fa fa-cloud)
            Production ::icon(fa fa-globe)
```

## Markdown Formatting

### Bold and Italic

```mermaid
mindmap
    root((**Project Goals**))
        *Quality*
            **High Performance**
            *Low Latency*
        *Scalability*
            **Horizontal Scaling**
            *Load Balancing*
```

### Text Wrapping

Long text automatically wraps:

```mermaid
mindmap
    root((Software Development))
        Planning and Requirements Gathering Phase
            Stakeholder Interviews and User Research
            Competitive Analysis
        Design and Architecture
            System Design Documents
            API Specifications
```

## Styling

### Class-Based Styling

```mermaid
mindmap
    root((Features))
        Core Features
            Authentication:::critical
            Authorization:::critical
        Optional Features
            Theming:::optional
            Export:::optional

classDef critical fill:#f66,stroke:#933,color:#fff
classDef optional fill:#6cf,stroke:#39c,color:#000
```

## Use Cases

### Software Architecture Overview

```mermaid
mindmap
    root((E-Commerce Platform))
        [Frontend]
            (Web App)
                React
                TypeScript
                Tailwind CSS
            (Mobile App)
                React Native
                iOS
                Android
        [Backend Services]
            (API Gateway)
            (Auth Service)
                JWT
                OAuth2
            (Product Service)
                Catalog
                Search
            (Order Service)
                Cart
                Checkout
                Payment
        {{Infrastructure}}
            ((Cloud Provider))
                AWS
                Kubernetes
            ((Databases))
                PostgreSQL
                Redis
                Elasticsearch
        ))Monitoring((
            [Observability]
                Logs
                Metrics
                Traces
            [Alerting]
                PagerDuty
                Slack
```

### Feature Planning

```mermaid
mindmap
    root((v2.0 Release))
        **Core Features**
            User Management ::icon(fa fa-users)
                Registration
                Login/Logout
                Profile
            Content System ::icon(fa fa-file-text)
                Create
                Edit
                Delete
                Version History
        **Integrations**
            Third-Party APIs ::icon(fa fa-plug)
                Payment Gateway
                Email Service
                Analytics
            Social Media ::icon(fa fa-share-alt)
                Facebook
                Twitter
                LinkedIn
        **Infrastructure**
            Performance ::icon(fa fa-tachometer-alt)
                Caching Strategy
                CDN Setup
            Security ::icon(fa fa-shield-alt)
                HTTPS
                Rate Limiting
                Input Validation
```

### Technology Stack

```mermaid
mindmap
    root((Tech Stack))
        [Frontend]
            (Framework)
                Next.js 14
                React 19
                TypeScript
            (Styling)
                Tailwind CSS
                shadcn/ui
            (State Management)
                Zustand
                React Query
        [Backend]
            (Runtime)
                Node.js
                TypeScript
            (Framework)
                NestJS
            (API)
                GraphQL
                Apollo Server
        {{Database}}
            ((Primary))
                PostgreSQL
                Prisma ORM
            ((Cache))
                Redis
            ((Search))
                Elasticsearch
        [DevOps]
            (CI/CD)
                GitHub Actions
                Docker
            (Hosting)
                Vercel
                AWS ECS
            (Monitoring)
                Datadog
                Sentry
```

### API Design Brainstorm

```mermaid
mindmap
    root((API Design))
        **Authentication**
            Endpoints
                POST /auth/login
                POST /auth/register
                POST /auth/refresh
            Security
                JWT Tokens
                Rate Limiting
                CORS Policy
        **Resources**
            Users
                GET /users
                POST /users
                PUT /users/:id
                DELETE /users/:id
            Products
                GET /products
                POST /products
                GET /products/:id
            Orders
                GET /orders
                POST /orders
        **Data Format**
            Request
                JSON
                Validation
                Schema
            Response
                JSON API
                Pagination
                Error Format
```

### Learning Path

```mermaid
mindmap
    root((Becoming a Full-Stack Developer))
        *Frontend Basics*
            HTML & CSS
                Semantic HTML
                Flexbox
                Grid
            JavaScript
                ES6+
                DOM Manipulation
                Async/Await
        *Frontend Frameworks*
            React
                Components
                Hooks
                Context
            TypeScript
                Types
                Interfaces
                Generics
        *Backend Development*
            Node.js
                Express
                REST APIs
                Authentication
            Databases
                SQL
                    PostgreSQL
                    Joins
                NoSQL
                    MongoDB
        *DevOps*
            Version Control
                Git
                GitHub
            Deployment
                Docker
                CI/CD
                Cloud Platforms
```

### Problem Analysis

```mermaid
mindmap
    root((Performance Issue))
        **Symptoms**
            Slow Page Load
                3+ seconds
                Mobile Affected
            High Server Load
                CPU 80%+
                Memory Leaks
        **Potential Causes**
            Frontend
                Large Bundle Size
                Too Many Requests
                No Code Splitting
            Backend
                N+1 Queries
                Missing Indexes
                No Caching
            Infrastructure
                Insufficient Resources
                Network Latency
        **Solutions**
            Quick Wins
                Enable Compression
                Add CDN
                Database Indexes
            Long-Term
                Code Splitting
                Query Optimization
                Horizontal Scaling
```

### Sprint Retrospective

```mermaid
mindmap
    root((Sprint Retrospective))
        {{What Went Well}}
            Team Collaboration ::icon(fa fa-users)
            Code Quality ::icon(fa fa-check)
            Testing Coverage ::icon(fa fa-vial)
        ))What Could Improve((
            Deployment Speed ::icon(fa fa-clock)
            Documentation ::icon(fa fa-book)
            Communication ::icon(fa fa-comments)
        [Action Items]
            (Immediate)
                Automate Deployment
                Update Docs
            (Next Sprint)
                Pair Programming
                Weekly Syncs
```

### Security Checklist

```mermaid
mindmap
    root((Security Audit))
        **Authentication**
            Implementation
                Password Hashing
                MFA Support
                Session Management
            Vulnerabilities
                Brute Force
                Session Fixation
        **Authorization**
            Access Control
                RBAC
                Resource Permissions
            Testing
                Privilege Escalation
                IDOR
        **Data Protection**
            In Transit
                HTTPS
                TLS 1.3
            At Rest
                Encryption
                Key Management
        **Code Security**
            Dependencies
                Audit npm packages
                Update regularly
            Input Validation
                XSS Prevention
                SQL Injection
```

## Tips for Effective Mindmaps

1. **Central concept** - Start with the core idea as root
2. **Logical grouping** - Group related concepts under parent nodes
3. **Consistent indentation** - Maintain clear hierarchy
4. **Use shapes meaningfully** - Different shapes for different types of nodes
5. **Add icons** - Visual cues improve readability
6. **Markdown formatting** - Emphasize important nodes with bold/italic
7. **Limit depth** - Keep to 3-4 levels for clarity
8. **Balance branches** - Distribute information evenly
