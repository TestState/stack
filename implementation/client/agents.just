# Generated Agents Justfile - DO NOT EDIT MANUALLY

build-ai-translation-agent:
    just build-client ai-translation-agent

run-ai-translation-agent *args:
    just run-client ai-translation-agent {{args}}

build-junit-agent:
    just build-client junit-agent

run-junit-agent *args:
    just run-client junit-agent {{args}}

build-manual-java-agent:
    just build-client manual-java-agent

run-manual-java-agent *args:
    just run-client manual-java-agent {{args}}

build-puppeteer-replay-agent:
    just build-client puppeteer-replay-agent

run-puppeteer-replay-agent *args:
    just run-client puppeteer-replay-agent {{args}}

build-selenium-junit-agent:
    just build-client selenium-junit-agent

run-selenium-junit-agent *args:
    just run-client selenium-junit-agent {{args}}

build-side-agent:
    just build-client side-agent

run-side-agent *args:
    just run-client side-agent {{args}}

