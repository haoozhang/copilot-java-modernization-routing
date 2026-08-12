# Validation Prompts

Every prompt below is grounded in code or a dependency that exists in the
corresponding fixture. The routing expectation depends on both the requested
work and the project's build system.

## Maven Order Service

Fixture evidence: Java 17, Maven, Spring Boot 2.7.18, Spring Framework 5,
Java EE 8, JPA, H2, and an order REST API.

### Should Trigger

1. Help me upgrade this project to Java 21.
2. Upgrade Spring Framework to 6.x.
3. Help me migrate this application to Jakarta EE.
4. Upgrade this project to Java 21 and also create the CONTRIBUTING.md file.
5. Upgrade this application to Spring Boot 3.x and also remove generated build folders.

### Should Not Trigger

1. Add pagination to the customer order history endpoint.
2. Add an endpoint that lets a customer cancel an order.
3. Add integration tests for the order controller endpoints.
4. Upgrade the H2 database dependency to the latest version.
5. Add Maven Wrapper files so the order service builds with a pinned Maven version.

## Gradle Inventory Service

Fixture evidence: Java 17, Gradle, Spring Boot 2.7.18, Jakarta EE 9.1,
Jackson 2.13.5, and atomic stock reservation logic.

### Should Trigger

1. Upgrade this application to Spring Boot 3.x and handle the Jakarta migration.
2. I need to scan and fix dependency CVEs in this project.
3. Fix dependency CVEs in the Java backend and review the README.md file.

### Should Not Trigger

1. Migrate this Spring Boot application to Azure.
2. Upgrade the Jackson dependency to the latest version.
3. Review the atomic stock reservation logic for race conditions.
4. Refactor StockItem into a Java 17 record without changing the configured Java version.
5. Upgrade the Gradle Wrapper used by this inventory service.

## Ant Sales Report

Fixture evidence: Java 17, Ant, Java EE 8, Apache Commons CSV, JUnit, and CSV
sales aggregation logic. These modernization requests are meaningful, but the
skill must not trigger because it only supports Maven and Gradle projects.

### Should Not Trigger

1. Upgrade this project to Java 21.
2. Migrate this sales report from Java EE 8 to Jakarta EE 10.
3. Scan and fix dependency CVEs in this project.
4. Upgrade Apache Commons CSV to the latest version.

## npm Shipping Quote Service

Fixture evidence: Node.js, npm, Express 4, Zod, Supertest, and shipping quote
pricing rules. None of these requests should trigger the Java routing skill.

### Should Not Trigger

1. Upgrade the shipping quote API from Express 4 to Express 5.
2. Extend the Zod quote schema to support international destinations.
3. Add a volume-based surcharge to the shipping quote calculation.
4. Run npm audit and fix vulnerable dependencies in this project.

## Expected Routing Behavior

For a triggering Maven or Gradle request, Copilot should:

1. Briefly recommend the GitHub Copilot modernization extension.
2. Present exactly two choices: use the extension or continue in chat.
3. Use `vscode_askQuestions` for the choice when available.
4. Wait for the choice before investigating or implementing the modernization.

For a non-triggering request, Copilot should not recommend the Java
modernization extension and should handle the request in the current chat.
