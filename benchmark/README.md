# Copilot CLI Routing Benchmark

This benchmark measures whether Copilot CLI recommends the GitHub Copilot
modernization extension for an eligible prompt in a supported workspace. The
main oracle is a structured call to a local mock of `vscode_askQuestions`, not
response wording.

## Run

Prerequisites:

- PowerShell 7 or Windows PowerShell 5.1
- Node.js
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
.\benchmark\Run-Benchmark.ps1 -ThrottleLimit 4
```

The default model is `auto`, which works across Copilot plans. For comparisons,
pass the same explicit model to every run so model selection does not become an
uncontrolled variable.

`ThrottleLimit` defaults to `2` and accepts values from 1 through 32. Pass
`-ThrottleLimit 1` for serial execution. Parallel runs use an isolated
PowerShell process for every active case so workspaces, CLI state, and OTel
destinations cannot overlap. Higher concurrency can increase Copilot service
throttling and machine resource usage. Keep the same throttle and explicit
model when comparing benchmark runs.

## Components

### `cases.json`

The benchmark manifest. Every case has a stable ID, a fixture, a prompt, and
`expectedRecommendation`. This is the source of truth for scoring.

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
the same model and restricted tool set. The runner also injects the local mock
MCP server with `--additional-mcp-config`.

The runner sets `COPILOT_OTEL_FILE_EXPORTER_PATH` separately for each process.
Response text is retained for diagnosis but never used as the oracle.
`actualRecommendation` is true only when a structured `tool.execution_start`
event calls the mock MCP server's `vscode_askQuestions` tool with arguments
that satisfy the full recommendation contract.

The runner delegates each case to `Invoke-BenchmarkCase.ps1` and starts at most
`ThrottleLimit` workers at once. Workers write their own `result.json`; the
runner sorts those results back into manifest and repetition order before
creating the summary and report. A worker failure is recorded as an
`infrastructure-error` without discarding other case results.

### `mock-mcp/server.mjs`

A zero-dependency stdio MCP server that exposes the same question input schema
used by VS Code. It validates that the model sends exactly one question with:

- `allowFreeformInput: false`
- exactly two ordered options: `Use GitHub Copilot modernization extension`
	and `Continue in the current chat`
- `recommended: true` on the extension option
- no multi-select behavior

A valid call deterministically answers `Continue in the current chat`, so the
benchmark verifies the recommendation without handing execution to an external
agent. Invalid calls return a tool error and remain invalid in benchmark
scoring even if the model retries.

### `New-BenchmarkReport.ps1`

The reporter compares `expectedRecommendation` with `actualRecommendation` and
calculates precision, recall, accuracy, and false-positive rate.

The reporter also aggregates the `gen_ai.usage.input_tokens`,
`gen_ai.usage.output_tokens`, and total-token OTel attributes when emitted by
the installed CLI version. Total-token average, P50, P95, and maximum values
expose cost and routing-run variability.

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

For every completed case, the behavior oracle is:

```text
passed = expectedRecommendation == actualRecommendation
```

`actualRecommendation` is true only for a question call that satisfies the full
contract. The aggregate recommendation metrics are:

- Precision: valid positive recommendations / valid positives plus any
	negative recommendation attempts, `TP / (TP + FP)`
- Recall: valid positive recommendations / all expected positive cases,
	`TP / (TP + FN)`
- Accuracy: correct cases / completed cases,
	`(TP + TN) / (TP + TN + FP + FN)`
- False-positive rate: recommendation attempts in negative cases / all
	expected negative cases, `FP / (FP + TN)`

CLI failures are reported separately and excluded from the confusion matrix.
Use repetitions greater than one when comparing skill-description changes,
because model routing is probabilistic.

Copilot CLI may also discover a user-installed skill with the same name. The
runner requires a repository-scoped project skill in every prepared workspace;
repository scope takes precedence when the skill tool loads its instructions.
