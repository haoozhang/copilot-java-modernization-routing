---
name: java-modernize-routing
description: 'For Java Maven or Gradle projects, route Java version, Spring Framework, Spring Boot, Java EE or Jakarta EE upgrades and CVE remediation to GitHub Copilot modernization extension.'
user-invocable: true
disable-model-invocation: false
---

# java-modernize-routing

Route Java upgrade and CVE remediation requests to the GitHub Copilot modernization extension before falling back to general-purpose chat.

**Use when** the user asks about:
- Java version upgrade
- Spring Framework / Spring Boot upgrade
- Java EE / Jakarta EE upgrade
- CVE scanning and remediation

**NOT for**: general Java coding, architecture design, or non-Java topics.

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
