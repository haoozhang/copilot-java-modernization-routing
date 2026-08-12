# Copilot CLI Routing Benchmark

This benchmark measures one behavior: whether Copilot CLI invokes the
`java-modernize-routing` skill for a prompt in a given workspace. It does not
score response wording, question UI, extension installation, or agent handoff.

## Run

Prerequisites:

- PowerShell 7 or Windows PowerShell 5.1
- GitHub Copilot CLI authenticated and available as `copilot`
- A model available to your Copilot account

Run the complete suite:

```powershell
.\benchmark\Run-Benchmark.ps1
```

Run selected cases or repeat cases to measure routing stability:

```powershell
.\benchmark\Run-Benchmark.ps1 -CaseId maven-java-upgrade,ant-java-upgrade
.\benchmark\Run-Benchmark.ps1 -Repetitions 3 -Model <available-model-name>
```

The default model is `auto`, which works across Copilot plans. For comparisons,
pass the same explicit model to every run so model selection does not become an
uncontrolled variable.

## Components

### `cases.json`

The benchmark manifest. Every case has a stable ID, a fixture, a prompt, and
`expectedTrigger`. This is the source of truth for scoring.

### `fixtures/`

Runnable projects with business logic, tests, and external dependencies:

- Maven: a Spring Boot order API using Java EE 8, validation, JPA/H2
	persistence, and bulk/coupon pricing rules.
- Gradle: a Spring Boot inventory API using Jakarta EE 9.1, validation,
	Jackson, and atomic stock reservation that prevents overselling.
- Ant: a Java EE 8 and Apache Commons CSV sales report that calculates
	completed, refunded, and net revenue totals.
- npm: an Express and Zod shipping quote API with customer discounts and
	request-level tests through Supertest.

The Maven, Gradle, and Ant fixtures target Java 17. Their older framework and
API choices are intentional inputs for the routing scenarios rather than
recommended versions for production systems.

### `Run-Benchmark.ps1`

The runner creates an isolated workspace for each case, copies in the selected
fixture, and injects the current repository version of `SKILL.md`. It verifies
skill discovery before starting a fresh Copilot CLI process. Each process uses
the same model and restricted tool set.

The runner sets `COPILOT_OTEL_FILE_EXPORTER_PATH` separately for each process.
It marks `skillInvoked` true only when one telemetry record contains both
`github.copilot.skill.invoked` and `java-modernize-routing`. Response text is
retained for diagnosis but never used as the oracle.

### `New-BenchmarkReport.ps1`

The reporter reads `summary.json`, builds the confusion matrix, and calculates
precision, recall, accuracy, and false-positive rate. It also aggregates the
`gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens`, and total-token OTel
attributes when emitted by the installed CLI version. Total-token average,
P50, P95, and maximum values expose cost and routing-run variability.

Token totals sum only OTel spans whose `gen_ai.operation.name` is `chat`.
The parent `invoke_agent` span already aggregates its child chat spans and is
excluded to prevent double counting. Input tokens represent the complete model
context for every chat turn, including agent instructions, available tool and
skill metadata, conversation history, the prompt, and loaded skill content.
They do not represent the size or count of invoked skills.

### `results/<run-id>/`

Each run contains `summary.json`, `metrics.json`, `report.md`, and one directory
per case. Case artifacts include the prepared workspace, discovered skills,
Copilot JSONL response, stderr, and raw OTel JSONL. Results are git-ignored.

## Scoring

For every completed case:

```text
passed = expectedTrigger == skillInvoked
```

The aggregate metrics are:

- Precision: triggered positive cases / all triggered cases
- Recall: triggered positive cases / all expected positive cases
- Accuracy: correct cases / completed cases
- False-positive rate: triggered negative cases / all expected negative cases

CLI failures are reported separately and excluded from the confusion matrix.
Use repetitions greater than one when comparing skill-description changes,
because model routing is probabilistic.

Copilot CLI may also discover a user-installed skill with the same name. The
runner requires a repository-scoped project skill in every prepared workspace;
repository scope takes precedence when the skill tool loads its instructions.
