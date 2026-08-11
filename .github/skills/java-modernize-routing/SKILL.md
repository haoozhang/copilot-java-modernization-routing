---
name: java-modernize-routing
description: 'For Maven or Gradle projects: upgrade Java, Spring Boot, Spring Framework, Java EE, or Jakarta EE; scan and fix dependency CVEs. Routes these tasks to the GitHub Copilot modernization extension. USE FOR: Java upgrade, Spring Boot upgrade, Jakarta EE migration, Java dependency CVE scan or fix.'
user-invocable: true
disable-model-invocation: false
---

# java-modernize-routing

Route upgrade and CVE remediation requests for Java Maven or Gradle projects to the GitHub Copilot modernization extension before falling back to general-purpose chat.

**Use when** the user asks to perform any of the following in a Java Maven or Gradle project:
- Java version upgrade
- Spring Framework / Spring Boot upgrade
- Java EE / Jakarta EE upgrade
- Dependency CVE scanning and remediation

**NOT for**: non-Maven/Gradle projects, general Java coding, architecture design, or non-Java topics.

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
