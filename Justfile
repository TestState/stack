import? 'implementation/client/agents.just'

set shell := ["bash", "-c"]

# Project Roots
node_client  := "implementation/client/client-node"
java_client  := "implementation/client/client-java"
cms          := "implementation/server/teststate-cms"
gen_cli      := "implementation/client/cli"
client_root  := "implementation/client"
spec         := justfile_directory() + "/specification"

# Discovery: List all agent directories (excludes SDKs and CLI)
clients := `find implementation/client -maxdepth 1 -type d | sed 's|implementation/client/||' | grep -vE "^implementation/client$|^client-|^cli" | tr '\n' ' '`

# Default Build
all: refresh-agents build-cms build-sdk build-all-clients

# --- Build Recipes ---

build-cms:
    mvn -f {{cms}} clean compile

run-cms:
    mvn -f {{cms}} quarkus:dev

force := "false"

build-node-client:
    @if [ "$FORCE" = "true" ] || [ "{{force}}" = "true" ] || [ ! -d "{{node_client}}/dist" ]; then \
        export SPECIFICATION_DIR="{{spec}}"; \
        cd {{node_client}} && npm install && npm run build; \
    else \
        echo "[Just] Node SDK already built, skipping..."; \
    fi

build-java-client:
    @if [ "$FORCE" = "true" ] || [ "{{force}}" = "true" ] || ! ls {{java_client}}/target/teststate-client-java-*.jar >/dev/null 2>&1; then \
        mvn -f {{java_client}} clean install -Dspecification.dir="{{spec}}"; \
    else \
        echo "[Just] Java SDK already built, skipping..."; \
    fi

build-sdk: build-node-client build-java-client

build-gen-cli:
    cd {{gen_cli}} && npm install && npm run build

# --- Generic Client Recipes ---

# List discovered agent clients
list-clients:
    @echo "Discovered Agents:"
    @printf "  - %s\n" {{clients}}

# Build a specific client by name
build-client name:
    @echo "[Just] Building client: {{name}}"
    @if [ -f "{{client_root}}/{{name}}/package.json" ]; then \
        if [ "{{name}}" != "client-node" ]; then \
            just build-node-client; \
        fi; \
        cd {{client_root}}/{{name}} && npm install && npm run build; \
    elif [ -f "{{client_root}}/{{name}}/pom.xml" ]; then \
        just build-java-client; \
        mvn -f {{client_root}}/{{name}}/pom.xml clean compile -Dspecification.dir="{{spec}}"; \
    else \
        echo "Error: Unsupported project type in {{name}}"; exit 1; \
    fi

# Build all discovered clients
build-all-clients:
    @printf "%s\n" {{clients}} | xargs -I {} just build-client {}

# Run a specific client
# Usage: just run-client <name> [args...]
run-client name *args:
    @echo "[Just] Running client: {{name}}"
    @export CLIENT_DIR="{{client_root}}/{{name}}"; \
    if [ -f "$CLIENT_DIR/.env" ]; then \
        echo "[Just] Loading $CLIENT_DIR/.env"; \
        set -o allexport; source "$CLIENT_DIR/.env"; set +o allexport; \
    fi; \
    if [ -f "$CLIENT_DIR/package.json" ]; then \
        cd $CLIENT_DIR && npm start -- {{args}}; \
    elif [ -f "$CLIENT_DIR/pom.xml" ]; then \
        mvn -f $CLIENT_DIR/pom.xml exec:java -Dexec.args="{{args}}"; \
    else \
        echo "Error: Unsupported project type in {{name}}"; exit 1; \
    fi

# Install Playwright browsers for a specific client
install-playwright name:
    mvn -f {{client_root}}/{{name}}/pom.xml exec:java -Dexec.mainClass="com.microsoft.playwright.CLI" -Dexec.args="install"

# --- Generator & Maintenance ---

# Generate a new client project
# Usage: just gen-client <name> [options]
gen-client name *args: build-gen-cli
    cd {{client_root}} && node cli/dist/index.js {{name}} {{args}}
    just refresh-agents

# Refresh dynamic agent recipes for tab completion
refresh-agents: build-gen-cli
    cd {{client_root}} && node cli/dist/index.js --refresh

# --- Utility ---

clean:
    mvn -f {{cms}} clean
    mvn -f {{java_client}} clean
    @for client in {{clients}}; do \
        if [ -f "{{client_root}}/$$client/pom.xml" ]; then \
            mvn -f {{client_root}}/$$client clean; \
        elif [ -f "{{client_root}}/$$client/package.json" ]; then \
            rm -rf {{client_root}}/$$client/{dist,node_modules}; \
        fi; \
    done
    rm -rf {{node_client}}/{dist,node_modules,src/generated}
    rm -rf .docker/

# Update all submodules to their latest remote versions and commit
update-submodules:
    @echo "[Just] Updating all submodules..."
    git submodule update --remote --merge
    @if [ -n "$(git status --porcelain implementation/ specification/)" ]; then \
        echo "[Just] Committing submodule updates..."; \
        git add implementation/ specification/; \
        git commit -m "chore: update all submodules to latest remote versions"; \
        echo "[Just] Successfully updated and committed submodules."; \
    else \
        echo "[Just] All submodules are already up to date."; \
    fi

# --- Deployment Configuration ---

VPS_FILE := ".vps"

# --- Deployment Recipes ---

# Deploy to a VPS via SSH (Sync & Build)
# Usage: just deploy [remote_path] [user@host]
# Create a versioned deployment bundle (ZIP)
bundle:
    #!/usr/bin/env bash
    VERSION=$(grep -m1 '<version>' implementation/server/teststate-cms/pom.xml | sed 's/.*<version>\(.*\)<\/version>.*/\1/')
    OUTPUT_FILE="teststate-v${VERSION}.zip"
    echo "[Bundle] Creating v${VERSION} into ${OUTPUT_FILE}..."
    rm -f teststate-v*.zip
    git ls-files --cached --others --exclude-standard | zip "$OUTPUT_FILE" -@
    echo "[Bundle] Done! Created ${OUTPUT_FILE}"

# Deploy to a VPS via SSH (Sync & Build)
# Usage: just deploy [remote_path] [user@host]
deploy path="~/TestState" host="":
    #!/usr/bin/env bash
    VPS_FILE=".vps"
    REMOTE_PATH="{{path}}"
    HOST="{{host}}"
    if [ -z "$HOST" ] && [ -f "$VPS_FILE" ]; then HOST=$(head -n 1 "$VPS_FILE"); fi
    if [ -z "$HOST" ]; then HOST="host@ip"; fi
    
    SSH_CMD="ssh"
    RSYNC_OPTS="-avz --delete"
    if [ -f "$VPS_FILE" ]; then
        export SSHPASS=$(tail -n 1 "$VPS_FILE")
        SSH_CMD="sshpass -e ssh"
        RSYNC_OPTS="$RSYNC_OPTS -e 'sshpass -e ssh'"
    fi

    echo "[Deploy] Syncing files to $HOST:$REMOTE_PATH..."
    eval "rsync $RSYNC_OPTS --exclude-from='.dockerignore' ./ \"$HOST:$REMOTE_PATH\""
    echo "[Deploy] Building and starting services on remote..."
    $SSH_CMD "$HOST" "cd $REMOTE_PATH && docker compose up --build -d --remove-orphans"

# Deploy via ZIP bundle (Upload -> Unzip -> Build)
# Usage: just deploy-zip [remote_path] [user@host]
deploy-zip path="~/TestState" host="": bundle
    #!/usr/bin/env bash
    VPS_FILE=".vps"
    REMOTE_PATH="{{path}}"
    HOST="{{host}}"
    if [ -z "$HOST" ] && [ -f "$VPS_FILE" ]; then HOST=$(head -n 1 "$VPS_FILE"); fi
    if [ -z "$HOST" ]; then HOST="host@ip"; fi

    SSH_CMD="ssh"
    SCP_CMD="scp"
    if [ -f "$VPS_FILE" ]; then
        export SSHPASS=$(tail -n 1 "$VPS_FILE")
        SSH_CMD="sshpass -e ssh"
        SCP_CMD="sshpass -e scp"
    fi

    BUNDLE=$(ls teststate-*.zip 2>/dev/null | sort -V | tail -n 1)
    if [ -z "$BUNDLE" ]; then echo "Error: No bundle found."; exit 1; fi

    echo "[Deploy] Uploading bundle $BUNDLE to $HOST..."
    $SCP_CMD "$BUNDLE" "$HOST:$REMOTE_PATH.zip"
    echo "[Deploy] Extracting and starting on remote..."
    $SSH_CMD "$HOST" "mkdir -p $REMOTE_PATH && unzip -o $REMOTE_PATH.zip -d $REMOTE_PATH && cd $REMOTE_PATH && docker compose up --build -d --remove-orphans"

# Configure a remote Docker context (Alternative method)
# Usage: just setup-remote-context <name> <ssh-url>
setup-remote-context name url:
    docker context create {{name}} --docker "host={{url}}"
    @echo "Success! Use 'docker --context {{name}} compose up --build -d' to deploy."
