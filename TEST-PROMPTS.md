# Validation Prompts

## Should Trigger Recommendation

1. Help me upgrade to Java 21 for this project.
2. I need to scan and fix CVEs in this Maven project.
3. Upgrade Spring Framework to 6.x in this application.
4. Upgrade Spring Boot to 3.x and handle Jakarta migration.
5. Help me migrate to Jakarta EE.

Expected outcome:
- Copilot should briefly recommend the GitHub Copilot modernize extension.
- Copilot should present exactly two options: use GitHub Copilot modernization, or continue manually in chat.
- Copilot should use `vscode_askQuestions` for that choice when available.
- Copilot should stop and wait for the user's choice before doing manual investigation or implementation.

## Should Trigger Briefly Then Continue

1. Upgrade Java to 21 and also create the CONTRIBUTING.md file.
2. Fix CVEs in the Java backend and review the README.md file.
3. Upgrade Spring Boot to 3.x and also remove the target/ folders.

Expected outcome:
- Copilot should recommend the modernize extension for the Java-related part only.
- Copilot should still offer the two-option modernization choice for the Java-related part.
- Copilot should continue helping with the rest of the request.

## Should Not Trigger Recommendation

1. Help me write a Python script to parse CSV files.
2. Migrate this Spring Boot application to Azure.

Expected outcome:
- Copilot should not mention the Java modernize routing recommendation.
