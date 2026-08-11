# Validation Prompts

## Should Trigger in Maven or Gradle Projects

Workspace fixture: Open a Java project that uses Maven or Gradle.

### Direct Requests

1. Help me upgrade this project to Java 21.
2. I need to scan and fix dependency CVEs in this project.
3. Upgrade Spring Framework to 6.x.
4. Upgrade this application to Spring Boot 3.x and handle the Jakarta migration.
5. Help me migrate this application to Jakarta EE.

Expected outcome:
- Copilot should briefly recommend the GitHub Copilot modernization extension.
- Copilot should present exactly two options: use GitHub Copilot modernization, or continue manually in chat.
- Copilot should use `vscode_askQuestions` for that choice when available.
- Copilot should stop and wait for the user's choice before doing manual investigation or implementation.

### Mixed Requests

1. Upgrade this project to Java 21 and also create the CONTRIBUTING.md file.
2. Fix dependency CVEs in the Java backend and review the README.md file.
3. Upgrade this application to Spring Boot 3.x and also remove generated build folders.

Expected outcome:
- Copilot should recommend the modernize extension for the Java-related part only.
- Copilot should still offer the two-option modernization choice for the Java-related part.
- Copilot should continue helping with the rest of the request.

## Should Not Trigger in Maven or Gradle Projects

Workspace fixture: Open a Java project that uses Maven or Gradle.

1. Help me write a Python script to parse CSV files.
2. Migrate this Spring Boot application to Azure.
3. Fix the SQL injection vulnerability in this Spring controller.
4. Upgrade the Jackson dependency to the latest version.
5. Why is this Spring Boot test failing?
6. Review the authentication code in this Java application for security issues.
7. Fix CVEs in this Node.js project.
8. Rewrite this Java 8 code using Java 21 syntax, but do not install any extensions.
9. Upgrade Gradle to the latest version.
10. Upgrade Maven to the latest version.

Expected outcome:
- Copilot should not mention the Java modernize routing recommendation.
- Copilot should continue handling the request in the current chat.

## Should Not Trigger in Non-Maven/Gradle Projects

Workspace fixtures: Run these prompts in Java projects that use Ant or Bazel, and in a Node.js project that uses npm.

1. Upgrade this project to Java 21.
2. Upgrade Spring Boot to 3.x.
3. Migrate this application from Java EE to Jakarta EE.
4. Scan and fix dependency CVEs in this project.

Expected outcome:
- Copilot should not mention the Java modernize routing recommendation.
- Copilot should continue handling the request in the current chat.
