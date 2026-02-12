# User Journey Diagrams

User journey diagrams map user experiences through workflows and identify pain points. They combine tasks, satisfaction scores, and actors to reveal opportunities for improvement.

## Basic Syntax

```mermaid
journey
    title My Working Day
    section Morning
        Wake up: 5: Me
        Commute: 2: Me
    section Work
        Meetings: 1: Me
        Coding: 5: Me
```

## Task Syntax

Each task includes:
- **Task name** - Description of the action
- **Score** (1-5) - Satisfaction level (1 = poor, 5 = excellent)
- **Actors** - Comma-separated participants

```mermaid
journey
    title Software Deployment Process
    section Preparation
        Write code: 4: Developer
        Run tests: 3: Developer, CI System
    section Deployment
        Deploy to staging: 2: Developer, DevOps
        Manual testing: 1: QA Team
    section Release
        Deploy to production: 5: DevOps
```

## Multiple Actors

Multiple actors can participate in the same task:

```mermaid
journey
    title Pull Request Review Process
    section Submission
        Create PR: 5: Developer
        Automated checks: 4: CI, Linter
    section Review
        Code review: 3: Senior Dev, Junior Dev
        Request changes: 2: Senior Dev
    section Resolution
        Fix issues: 3: Developer
        Re-review: 4: Senior Dev
        Merge PR: 5: Developer, Senior Dev
```

## Scoring Guidelines

Use scores to highlight problem areas:

- **5 (Excellent)** - Smooth, efficient, satisfying experience
- **4 (Good)** - Generally positive with minor friction
- **3 (Neutral)** - Acceptable but room for improvement
- **2 (Poor)** - Frustrating, time-consuming, or error-prone
- **1 (Very Poor)** - Major pain point requiring immediate attention

```mermaid
journey
    title API Integration Experience
    section Discovery
        Find documentation: 2: Developer
        Understand auth: 1: Developer
    section Implementation
        Setup SDK: 3: Developer
        First API call: 2: Developer
        Debug errors: 1: Developer
    section Production
        Monitor API: 4: Developer, Ops Team
        Handle rate limits: 3: Developer
```

**This journey reveals documentation and debugging as major pain points.**

## Real-World Example: User Onboarding

```mermaid
journey
    title New User Onboarding
    section Sign Up
        Visit landing page: 4: User
        Fill registration form: 3: User
        Email verification: 2: User, Email System
    section Setup
        Choose plan: 4: User
        Enter payment info: 2: User, Payment Gateway
        Setup profile: 3: User
    section First Use
        Complete tutorial: 1: User, System
        Create first project: 4: User
        Invite team members: 3: User, Teammate
    section Engagement
        Receive onboarding emails: 4: User, Email System
        First success milestone: 5: User
```

**Analysis:** Email verification (score 2) and tutorial (score 1) need improvement. First success milestone (score 5) is a highlight.

## Technical Workflow Example: CI/CD Pipeline

```mermaid
journey
    title Continuous Integration Workflow
    section Code Commit
        Write feature code: 5: Developer
        Run local tests: 4: Developer
        Push to repository: 5: Developer, Git
    section CI Pipeline
        Trigger build: 4: CI System
        Run unit tests: 3: CI System
        Build Docker image: 2: CI System
        Security scan: 1: CI System
    section Deployment
        Deploy to staging: 3: CI System, DevOps
        Integration tests: 2: CI System, QA
        Manual approval: 1: Lead Developer
        Deploy to production: 4: DevOps
```

**Pain points:** Security scan (1), manual approval (1), and integration tests (2) slow down the pipeline.

## Use Cases

1. **User Experience Research** - Map user interactions to find friction points
2. **Process Optimization** - Identify bottlenecks in internal workflows
3. **Customer Support Analysis** - Track support ticket resolution experience
4. **Developer Experience** - Analyze developer workflows (CI/CD, code review, deployment)
5. **Product Onboarding** - Optimize new user activation flow
6. **API Usability** - Evaluate developer experience with APIs
7. **Incident Response** - Review and improve incident handling processes

## Sections for Structure

Organize journeys into logical phases:

```mermaid
journey
    title E-Commerce Purchase Journey
    section Discovery
        Browse products: 4: Customer
        Search by category: 3: Customer
        Read reviews: 4: Customer
    section Decision
        Compare prices: 3: Customer
        Add to cart: 5: Customer
    section Checkout
        Enter shipping info: 2: Customer
        Select payment method: 2: Customer
        Review order: 3: Customer
        Complete purchase: 4: Customer, Payment Gateway
    section Post-Purchase
        Order confirmation: 5: Customer, Email System
        Track shipment: 4: Customer
        Receive product: 5: Customer
```

## Tips for Effective Journey Maps

1. **Focus on real workflows** - Base journeys on actual user behavior, not ideal scenarios
2. **Be honest with scores** - Low scores reveal improvement opportunities
3. **Include all actors** - Show system components and team members involved
4. **Group related tasks** - Use sections to create narrative flow
5. **Identify patterns** - Look for consistently low scores across sections
6. **Prioritize improvements** - Address score 1-2 tasks first
7. **Combine with analytics** - Validate scores with data (error rates, completion time)
8. **Update regularly** - Revisit journeys after implementing improvements
9. **Share with stakeholders** - Use as communication tool for user experience issues
10. **Keep it actionable** - Each low score should lead to a concrete improvement task

## Common Anti-Patterns to Avoid

- **All high scores** - Not realistic; doesn't reveal problems
- **Too many actors** - Keep to 2-3 key participants per task
- **Vague task names** - Be specific (e.g., "Enter credit card" not "Pay")
- **Missing context** - Add sections to explain journey phases
