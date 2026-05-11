# TestState Design & Frontend Standards

This project follows the "Genesis-Dark" aesthetic—a premium, high-density, and developer-centric dark theme. All UI contributions must adhere to these structural and stylistic guidelines.

## Project Architecture & Modules
TestState is structured as a multi-language monorepo:

### 1. Specification (`/specification`)
Contains the source `.proto` files that define the Universal Agent Protocol (UAP). This is the "Source of Truth" for all communications.

### 2. CMS Hub (`/implementation/server/teststate-cms`)
A **Quarkus** application that serves as the central brain.
- **Hub**: Manages gRPC connections from agents.
- **CMS**: Provides the web dashboard for test/payload management.
- **Persistence**: Uses Hibernate Panache with PostgreSQL for storing test data.

### 3. Agent Implementations (`/implementation/client`)
Specialized workers that connect to the Hub to execute tasks:
- **`teststate-client-node`**: Core TypeScript SDK for building Node.js agents.
- **`side-agent`**: Executes Selenium-IDE (`.side`) projects.
- **`puppeteer-replay-agent`**: Runs Chrome DevTools Recorder JSON exports.
- **`teststate-ai-translation-agent`**: A sophisticated AI-powered agent that translates manual test scripts into Selenium (.side) or Puppeteer Replay JSON using a strategy-based interaction loop.

---

## AI Agent Design Patterns

All AI-driven agents in TestState must adhere to these deterministic execution patterns:

### 1. Interaction Log as Ground Truth
AI agents are forbidden from "hallucinating" results. Every action must be recorded via a tool call into a `BrowserInteractionLog`. The final output script must be a direct assembly of these recorded steps.

### 2. Strategy-Based Tooling
Interaction logic is decoupled into format-specific strategies (e.g., `SeleniumBrowserTools`, `PuppeteerBrowserTools`). 
- **Direct Copy**: Tool outputs must be exact JSON objects ready for final assembly.
- **Multi-Selector Support**: Tools should accept and log multiple selector variants (ARIA, ID, CSS) to improve script resilience.

### 3. Proactive Synchronization (SYNC > PAUSE)
AI agents must prioritize dynamic state verification (`waitForElementVisible`) over fixed sleeps (`pause`). 
- **Grace Periods**: Transition-heavy formats (like Puppeteer) automatically handle page delays by interleaving short grace periods before verification steps.

### 4. Continuous Planning
Agents must maintain a living `BrowserExecutionPlan` and update it at least once every 3 turns to synchronize the roadmap with the live application state.

---
## Frontend Aesthetic: "Genesis-Dark"
 
TestState uses a systematic, high-density design system. **Inline styles are strictly forbidden.** All layouts must use the predefined semantic classes in `style.css`.
 
## 1. Core Aesthetic & Variables
- **Background**: `#010409` (Primary), `#0d1117` (Surface/Cards)
- **Accents**: `#58a6ff` (Primary), `#238636` (Success/Action)
- **Typography**: `-apple-system, BlinkMacSystemFont, "Segoe UI", ...`
- **Transitions**: `0.2s` for interactive elements (hover, transform).
- **Naming**: **No abbreviations.** Use `Description` instead of `Desc`, `Iterations` instead of `Iter`, etc.
 
## 2. Layout Patterns
 
### Header (Flexbox)
The global header uses **Flexbox** for responsive alignment. The brand heading is pushed to the left and the navigation to the right using `justify-content: space-between`.
 
### Grids & Data Management
We avoid legacy `<table>` elements. All data visualization uses CSS Grid.
 
#### A. Data Grid (List Views)
The `.data-grid` provides a table-like structure using `subgrid`. Headers and rows must span the full width.
```html
<section class="data-grid tests-grid">
    <div class="data-grid-header full-column">
        <div class="data-grid-cell">Column 1</div>
    </div>
    <div class="data-grid-row full-column">
        <div class="data-grid-cell">Data 1</div>
    </div>
</section>
```
*Note: Always define column widths on the parent `.data-grid` (e.g., `.tests-grid`).*
 
#### B. Card Grid (Dashboard/Overview)
Use `.card-grid` for responsive article/card layouts. It uses `auto-fill` to manage density.
```html
<div class="card-grid">
    <article>...</article>
</div>
```
 
### Statistical Overviews
Used for high-level metrics. `.stats-container` uses a flexible layout where boxes grow to fill the row.
```html
<div class="stats-container">
    <div class="stat-box">
        <span class="label">Total</span>
        <span class="value">100</span>
    </div>
</div>
```
 
## 3. Form Standards
Forms must be semantic and data-driven. **Never use `<p>` tags for wrapping fields.**
 
### Fieldset & Legend
Group related inputs using fieldsets.
```html
<fieldset>
    <legend>Settings</legend>
    <div class="field">
        <label>Iterations</label>
        <input type="number" name="iterations" class="input-small">
    </div>
</fieldset>
```
 
### Form Utilities
- `.full-width-form`: Expands fieldsets to 100% width.
- `.form-actions`: Flex-end container for primary buttons.
- `.input-small`: Constrains input width for numeric/short fields.
- `.input-readonly`: Styled for non-editable background (`var(--surface)`).
 
## 4. Component Standards
 
### Status Badges
Consistent, color-coded badges:
- `.status-completed`: Success/Green (`#3fb950`)
- `.status-running`: Active/Blue (`#58a6ff`)
- `.status-pending`: Warning/Yellow (`#d29922`)
- `.status-failed`: Error/Red (`#f85149`)
 
### Buttons
- `.btn`: Standard gray secondary.
- `.btn-primary`: Vibrant green call-to-action.
- `.btn-error`: Red destructive/stop action.
- `.btn.small`: Compact version for dense data grids.
 
### Telemetry & Console
- `.console`: Fixed-height, monospace, black background scrollable log.
- `.metadata-pre`: For raw JSON/Metadata; transparent, no padding, pre-wrap.
- `.status-message`: Global overflow handling (`overflow-wrap: anywhere`).
 
## 5. CSS Utilities
- **Flex**: `.flex`, `.flex-between`, `.flex-column`, `.align-end`.
- **Text**: `.muted`, `.small`, `.font-mono`, `.truncate`, `.text-right`.
- **Colors**: `.text-success`, `.text-error`, `.text-accent`.
- **Spacing**: `.mb-1` to `.mb-4`, `.mt-1`, `.ml-1`.
- **Grid Utility**: `.full-column` (`grid-column: 1 / -1`).
- **Visibility**: `.d-none`, `.d-block`, `.d-contents`.

---

## Containerization & Orchestration

TestState is fully containerized for production-grade reliability and performance.

### 1. Dockerfile Standards
All modules use multi-stage Dockerfiles optimized for speed and security:
- **Build Stage**: Leverages layered caching by copying dependency manifests (`pom.xml`, `package.json`) and running `mvn dependency:go-offline` or `npm install` before copying source code.
- **Runtime Stage**: Uses minimal base images (Alpine-based) to reduce attack surface and image size.
- **Agent Runtimes**: 
  - **Node.js**: Uses `node:22-slim`.
  - **Java**: Uses `eclipse-temurin:21-jdk-alpine`. Note: Agents that perform dynamic compilation require a full **JDK** instead of a JRE.

### 2. Browser Agent Optimization
Special considerations for agents that use headless browsers (Puppeteer, Selenium):
- **Shared Memory**: Always set `shm_size: 2gb` in `docker-compose.yml` for services using Chromium to prevent rendering crashes.
- **System Chromium**: Prefer installing the system `chromium` package via `apt` in the Dockerfile rather than using Puppeteer's internal downloader. Set `PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium`.

### 3. Native Image & Qute Optimization
TestState CMS is optimized for **GraalVM Native Image** deployment to ensure minimal memory footprint and instant startup.

#### A. "Plain Java" Template Extensions
To maintain a clean codebase while supporting native builds, we avoid littering data models with `@RegisterForReflection` or `@TemplateData`. Instead, we use **Qute Template Extensions**:
- **Centralized Logic**: Formatting and complex logic are moved to `TemplateExtensions.java` as static methods.
- **Reflection-Free**: Extension methods are called directly by Qute, avoiding the need for reflection on entities and DTOs.
- **Property Mapping**: Use extensions to provide "virtual properties" (e.g., `{session.status.state.displayState}`) to keep templates clean and type-safe.

#### B. Native Reflection Registration
Only use `@RegisterForReflection` when strictly necessary for 3rd-party libraries that rely on deep reflection:
- **Jackson Serialization**: Classes sent over WebSockets (`WSMessage`) or REST must be registered so Jackson can see their fields in native mode.
- **Protobuf Types**: Use `@TemplateData(target = ...)` or Template Extensions to expose Protobuf generated classes to the UI without modifying generated code.

#### C. Unified Multi-Stage Dockerfile
We use a single `Dockerfile` with multiple targets to manage both JVM and Native builds:
- **`CMS_TARGET`**: Can be toggled between `native` (using Mandrel/GraalVM) and `jvm` (standard JDK).
- **Build-Time Memory**: Native builds are memory-intensive. Deployment recipes (`just deploy`) include a `docker compose down` step to free up VPS RAM before starting the native compilation.

### 4. Java Execution Strategy
Instead of fat JARs (Shading), we use a classpath-based model:
- **`maven-dependency-plugin`**: Used to export all dependencies to a `lib/` folder.
- **`maven-jar-plugin`**: Configures the JAR manifest with `addClasspath: true` and `classpathPrefix: lib/`.
- **Execution**: Run via `java -jar agent.jar`, which automatically finds dependencies in the `lib/` directory.

### 5. Orchestration (`docker-compose.yml`)
- **Central CMS Hub**: The main endpoint for all agents (`http://cms:9000`).
- **Selenium Grid**: Integrated Hub and Chrome nodes for cross-agent browser automation.
- **Persistent Storage**: Uses Docker volumes for CMS data persistence.

### 6. Submodule Management & Deployment Bundling
TestState uses a **Multi-Repo Submodule** architecture. This requires specific care during deployment:
- **Recursive Cloning**: Always use `git clone --recursive` or `git submodule update --init --recursive` to ensure all agent code is available.
- **Context Bundling**: Docker builds for submodules are often triggered from the root. Ensure that the submodule directory is correctly mapped in the `Dockerfile` and that the `.dockerignore` doesn't inadvertently exclude submodule source code.
- **Recipe-Driven Builds**: Use the root `justfile` recipes (e.g., `just build-ai-translation-agent`) to handle the cross-repo dependencies and ensure all artifacts are built in the correct order before containerization.
- **Version Pinning**: Submodule pointers in the `stack` (root) repository serve as the deployment manifest. Commits in submodules must be pushed and the root pointer updated to deploy new changes.
