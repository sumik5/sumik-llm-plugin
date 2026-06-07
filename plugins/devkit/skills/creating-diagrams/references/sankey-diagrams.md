# Sankey Diagrams

Sankey diagrams visualize flow and quantity distribution through a system. Width of arrows represents magnitude, making them ideal for resource flow, data pipelines, and budget allocation visualization.

## Basic Syntax

```mermaid
sankey-beta
    Source,Target,100
```

## CSV Format

Sankey diagrams use CSV format: `source,target,value`

```mermaid
sankey-beta
    Frontend,API Gateway,1000
    API Gateway,User Service,400
    API Gateway,Order Service,600
    User Service,Database,400
    Order Service,Database,600
```

## Handling Commas and Quotes

**Values with commas:**
```mermaid
sankey-beta
    "Source, with comma",Target,150
    Another Source,"Target, with comma",200
```

**Escaping quotes:**
```mermaid
sankey-beta
    "Node with ""quotes""",Target,100
```

## Multiple Flows

Create complex flow networks:

```mermaid
sankey-beta
    A,B,30
    A,C,20
    B,D,25
    B,E,5
    C,D,15
    C,F,5
    D,G,40
    E,G,5
    F,G,5
```

## Readable Formatting

Use blank lines to group related flows:

```mermaid
sankey-beta
    %% Input sources
    Solar,Electricity Grid,500
    Wind,Electricity Grid,300
    Natural Gas,Electricity Grid,700

    %% Distribution
    Electricity Grid,Residential,400
    Electricity Grid,Commercial,600
    Electricity Grid,Industrial,500
```

## Link Colors

### Source Color
Links inherit color from source node:

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'linkColor':'source'}}}%%
sankey-beta
    Frontend,Backend,1000
    Backend,Database,800
    Backend,Cache,200
```

### Target Color
Links inherit color from target node:

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'linkColor':'target'}}}%%
sankey-beta
    Frontend,Backend,1000
    Backend,Database,800
    Backend,Cache,200
```

### Gradient
Links use gradient from source to target:

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'linkColor':'gradient'}}}%%
sankey-beta
    Frontend,Backend,1000
    Backend,Database,800
    Backend,Cache,200
```

### Custom Color
Set specific hex color:

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'linkColor':'#ff6b6b'}}}%%
sankey-beta
    Frontend,Backend,1000
    Backend,Database,800
    Backend,Cache,200
```

## Node Alignment

### Justify (Default)
Nodes spread across full width:

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'nodeAlignment':'justify'}}}%%
sankey-beta
    A,B,10
    B,C,10
    C,D,10
```

### Left Alignment
All nodes aligned to left:

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'nodeAlignment':'left'}}}%%
sankey-beta
    A,B,10
    B,C,10
    C,D,10
```

### Center Alignment
Nodes centered:

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'nodeAlignment':'center'}}}%%
sankey-beta
    A,B,10
    B,C,10
    C,D,10
```

### Right Alignment
All nodes aligned to right:

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'nodeAlignment':'right'}}}%%
sankey-beta
    A,B,10
    B,C,10
    C,D,10
```

## Comprehensive Example: Data Pipeline

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'linkColor':'gradient'}}}%%
sankey-beta
    %% Data sources
    Mobile App,API Gateway,5000
    Web App,API Gateway,8000
    Third Party,API Gateway,2000

    %% API processing
    API Gateway,Authentication,15000

    %% Authentication flow
    Authentication,User Service,10000
    Authentication,Rejected,5000

    %% Service layer
    User Service,Write to DB,7000
    User Service,Cache Update,3000

    %% Storage
    Write to DB,Primary Database,7000
    Primary Database,Replica,7000
    Cache Update,Redis Cache,3000

    %% Analytics
    Primary Database,Analytics Pipeline,2000
    Analytics Pipeline,Data Warehouse,2000
```

## Budget Allocation Example

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'linkColor':'source', 'nodeAlignment':'justify'}}}%%
sankey-beta
    %% Revenue sources
    Product Sales,Total Revenue,500000
    Service Revenue,Total Revenue,300000
    Licensing,Total Revenue,200000

    %% Cost allocation
    Total Revenue,Engineering,400000
    Total Revenue,Sales & Marketing,300000
    Total Revenue,Operations,200000
    Total Revenue,Profit,100000

    %% Engineering breakdown
    Engineering,Salaries,250000
    Engineering,Infrastructure,100000
    Engineering,Tools & Software,50000

    %% Sales breakdown
    Sales & Marketing,Salaries,150000
    Sales & Marketing,Advertising,100000
    Sales & Marketing,Events,50000

    %% Operations breakdown
    Operations,Salaries,100000
    Operations,Office,60000
    Operations,Admin,40000
```

## Energy Flow Example

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'linkColor':'gradient'}}}%%
sankey-beta
    %% Primary energy sources
    Solar,Electricity Generation,350
    Wind,Electricity Generation,280
    Hydro,Electricity Generation,180
    Natural Gas,Electricity Generation,400
    Coal,Electricity Generation,150

    %% Generation to grid
    Electricity Generation,Transmission Grid,1360

    %% Transmission losses
    Transmission Grid,Transmission Loss,80
    Transmission Grid,Distribution,1280

    %% Distribution
    Distribution,Residential,500
    Distribution,Commercial,400
    Distribution,Industrial,300
    Distribution,Distribution Loss,80
```

## Traffic Flow Example

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'linkColor':'source'}}}%%
sankey-beta
    %% Traffic sources
    Organic Search,Website Homepage,45000
    Paid Ads,Website Homepage,25000
    Social Media,Website Homepage,15000
    Direct,Website Homepage,10000
    Email Campaign,Website Homepage,5000

    %% Homepage navigation
    Website Homepage,Product Pages,60000
    Website Homepage,Blog,25000
    Website Homepage,About,10000
    Website Homepage,Exit,5000

    %% Product page conversion
    Product Pages,Add to Cart,18000
    Product Pages,Exit,42000

    %% Cart to checkout
    Add to Cart,Checkout,12000
    Add to Cart,Abandoned Cart,6000

    %% Checkout conversion
    Checkout,Purchase Complete,9000
    Checkout,Exit,3000
```

## Microservices Communication Example

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'linkColor':'gradient', 'nodeAlignment':'justify'}}}%%
sankey-beta
    %% External requests
    External Clients,API Gateway,10000

    %% Gateway routing
    API Gateway,Auth Service,10000

    %% Authentication
    Auth Service,Authenticated,9000
    Auth Service,Rejected,1000

    %% Service distribution
    Authenticated,User Service,3000
    Authenticated,Order Service,4000
    Authenticated,Product Service,2000

    %% Database access
    User Service,User Database,3000
    Order Service,Order Database,4000
    Product Service,Product Database,2000

    %% Cache usage
    User Service,Cache,1500
    Order Service,Cache,2000
    Product Service,Cache,1000

    %% Message queue
    Order Service,Message Queue,1000
    Message Queue,Notification Service,1000
    Message Queue,Analytics Service,1000
```

## Tips for Effective Sankey Diagrams

1. **Use consistent units** - All values should represent the same measurement
2. **Group related flows** - Use blank lines to improve readability
3. **Choose appropriate alignment** - Justify for process flows, left/right for hierarchies
4. **Color strategically** - Gradient shows transformation, source/target shows ownership
5. **Show conservation** - Total input should equal total output (unless showing loss)
6. **Label clearly** - Node names should be descriptive and consistent
7. **Aggregate small flows** - Too many thin flows create visual clutter

## Common Use Cases

### Resource Management
- Budget allocation and spending
- Energy production and consumption
- Material flow in manufacturing

### Data Analytics
- User journey through website
- Data pipeline processing volumes
- Customer funnel conversion

### System Monitoring
- Network traffic distribution
- API request routing
- Service communication patterns
