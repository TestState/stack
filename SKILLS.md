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

### 5. Mandatory Validation Tool & Self-Correction
AI translation agents must not return raw text/unverified JSON files directly. They must invoke a mandatory validation and submission tool (`submitTranslation`).
- **Semantic Validation**: The submission tool parses the JSON and runs deep semantic and structural checks (validating URLs, nested selector arrays, and step parameters).
- **Self-Correction Loop**: If validation fails, the tool returns the exact compiler/assertion exception details. The agent is strictly commanded to capture the error, fix the payload, and resubmit recursively until a successful verification response is received.

### 6. Selector Standards & Strategy Restrictions
To ensure zero execution mismatch during playback:
- **No Selenium Prefixes in Puppeteer**: Chrome DevTools Recorder/Puppeteer agents are strictly forbidden from using Selenium-style selector strategy prefixes (like `id=`, `name=`, `css=`, `xpath=`, or `linkText=`) under any circumstances (neither in interactive tool calls nor in the final submitted JSON). Standard CSS selectors must be used directly without strategy prefixes (e.g. `#username`, `.btn`).
- **Selector Execution Adapter**: Interactive browser tools must implement a dynamic selector adapter (e.g., `toPlaywrightSelector`) that maps pure Chrome DevTools Recorder selectors into native Playwright targets (translating `xpath/path` -> `xpath=path` and `aria/label` -> `text=label`) during session playback.

---

## Frontend Aesthetic: "Genesis-Dark" via Mantine v7
 
TestState uses a systematic, high-density dark theme built on **Mantine v7**. Direct inline styling and custom utility CSS classes are deprecated; developers should use Mantine's built-in props and semantic components to preserve layout spacing and visual hierarchy.
 
## 1. Design System & Components
Layouts must follow these Mantine structural guidelines:

- **Spacing & Layouts**: Use `<Stack>` (vertical) and `<Group>` (horizontal) components with default gaps to maintain consistent spacing. Avoid custom margins or paddings.
- **Grids**: Use `<SimpleGrid>` with responsive `cols` property for dashboard widgets, stats lists, and card grids.
- **Naming**: **No abbreviations.** Prop and field names must be fully descriptive: use `description` instead of `desc`, `iterations` instead of `iter`, etc.

## 2. Formatting Utilities & Status Badges
To keep UI elements consistent, formatting logic is centralized in [format.js](file:///home/hsgamer/Projects/TestState/implementation/server/teststate-cms/src/main/webui/src/utils/format.js).

### A. Status Badges
Always use the centralized helpers to style and display execution states:
```javascript
import { getStatusColor, getCleanStatus } from '../utils/format';

<Badge color={getStatusColor(status)} variant="filled">
  {getCleanStatus(status)}
</Badge>
```
- **`getCleanStatus`**: Removes verbose gRPC prefixes (`TEST_STATE_`, `STEP_STATUS_`, `TRANSLATION_STATE_`) for user-friendly badge labels.
- **`getStatusColor`**: Standardizes colors dynamically (`green` for success/completion, `red` for failure/error, `blue` for running/pending/negotiation, `gray` for unknown/unspecified).

### B. Display Duration
All duration values (seconds string with `"s"` suffix or numeric milliseconds) must be formatted using the centralized helper:
```javascript
import { getDisplayDuration } from '../utils/format';

<Text>{getDisplayDuration(duration)}</Text> // Renders consistently in milliseconds (e.g., "150ms")
```

## 3. Form Standards
Forms must utilize Mantine input fields (e.g., `<TextInput>`, `<NumberInput>`, `<Textarea>`) arranged within a `<Stack>`. Group primary buttons using a right-aligned `<Group>` component.

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
