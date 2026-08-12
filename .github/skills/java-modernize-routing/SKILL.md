---
name: java-modernize-routing
description: 'Use only when the workspace contains a Java Maven (pom.xml) or Gradle (build.gradle/build.gradle.kts) project and the user asks to upgrade Java, Spring Boot, or Spring Framework; migrate Java EE to Jakarta EE; or scan and fix dependency CVEs. Do not invoke for any other scenario.'
user-invocable: true
disable-model-invocation: false
---

# java-modernize-routing

Route only the requests listed below, and only for Java Maven (`pom.xml`) or Gradle (`build.gradle` or `build.gradle.kts`) projects, to the GitHub Copilot modernization extension.

**Use only when** one of those build files is present and the user asks to:
- Upgrade Java
- Upgrade Spring Boot or Spring Framework
- Migrate Java EE to Jakarta EE
- Scan and fix dependency CVEs

**Do not use for any other scenario.**

## Steps

### 1 — Present options

Briefly recommend `GitHub Copilot modernization` as the more specialized workflow for this task (1–2 sentences, not a hard requirement).

Use `vscode_askQuestions` (`allowFreeformInput: false`) with two options:
1. **Use GitHub Copilot modernization extension** *(Recommended)*
2. **Continue in the current chat**

Wait for the user's choice. Do not inspect files or propose steps yet.

### 2a — User chooses the extension

1. Render the extension card:
   ````
   ```vscode-extensions
   vscjava.migrate-java-to-azure
   ```
   ````
2. Use the `install_extension` tool to ensure the extension is installed (id: `vscjava.migrate-java-to-azure`, name: `GitHub Copilot modernization extension`).
3. Route to the appropriate agent:
   - Java / Spring / Jakarta upgrade → `modernize-java-upgrade`
   - CVE remediation → `modernize-java-security`

### 2b — User chooses manual chat

Continue without friction. Do not repeat the recommendation in the same thread.
