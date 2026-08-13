# Java Modernization Routing Skill Benchmark Report

**Skill:** `java-modernize-routing`

**Purpose:** Evaluate whether introducing the routing skill reliably recommends the GitHub Copilot modernization extension for supported Java modernization requests, avoids unrelated requests, and adds an acceptable token cost.

## 1. Benchmark Setup

The benchmark exercised the skill through GitHub Copilot CLI using six models:

- `gpt-5.6-sol`
- `gpt-5.5`
- `gpt-5.4`
- `gpt-5.3-codex`
- `grok-4.5`
- `gemini-3.1-pro-preview`

Each model ran the same 26 cases three times, producing 78 runs per model and 468 runs overall. All runs completed without infrastructure failures.

The suite contains 8 expected-positive cases covering Java/JDK, Spring Framework, Spring Boot, Jakarta EE, and CVE modernization requests, including mixed requests. Its 18 expected-negative cases cover unrelated Maven and Gradle work, Azure migration, ordinary dependency upgrades, feature development, tests, refactoring, build wrappers, and unsupported Ant and npm projects. Maven and Gradle are the only supported project types.

Each case runs in an isolated copy of a realistic Maven, Gradle, Ant, or npm fixture. The runner injects the repository version of the skill, confirms that Copilot CLI discovers it, and exposes only the tools required by the routing workflow.

Accuracy metrics use the following definitions:

- Precision: `TP / (TP + FP)`
- Recall: `TP / (TP + FN)`
- Accuracy: `(TP + TN) / all completed runs`
- False-positive rate: `FP / (FP + TN)`

Token totals come from OTel `chat` spans emitted by Copilot CLI 1.0.79; parent agent spans are excluded to prevent double counting.

## 2. Skill Accuracy

### Results by Model

| Model | TP | TN | FP | FN | Precision | Recall | Accuracy | False-positive rate |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `gpt-5.6-sol` | 23 | 53 | 1 | 1 | 95.83% | 95.83% | 97.44% | 1.85% |
| `gpt-5.5` | 24 | 54 | 0 | 0 | 100.00% | 100.00% | 100.00% | 0.00% |
| `gpt-5.4` | 15 | 54 | 0 | 9 | 100.00% | 62.50% | 88.46% | 0.00% |
| `gpt-5.3-codex` | 24 | 51 | 3 | 0 | 88.89% | 100.00% | 96.15% | 5.56% |
| `grok-4.5` | 24 | 44 | 10 | 0 | 70.59% | 100.00% | 87.18% | 18.52% |
| `gemini-3.1-pro-preview` | 24 | 31 | 23 | 0 | 51.06% | 100.00% | 70.51% | 42.59% |

### Model Observations

**`gpt-5.6-sol`** had one false negative on a mixed Java-upgrade request and one false positive on an unsupported Ant Jakarta migration. Precision, recall, and accuracy were all at least 95.83%.

**`gpt-5.5`** was the only model with perfect results across all 78 runs. It recognized every eligible case, including mixed requests, and rejected all unsupported projects and topics.

**`gpt-5.4`** had no false positives but missed nine eligible runs, mostly CVE remediation plus some Jakarta, Spring Framework, and mixed Spring requests. It avoids unwanted routing at the cost of lower recall.

**`gpt-5.3-codex`** detected every eligible request, with three false positives: two unsupported Ant modernization cases and one H2 dependency upgrade. Accuracy was strong, with limited over-routing beyond the declared scope.

**`grok-4.5`** detected every eligible request but produced ten false positives across unsupported Ant and npm projects and unrelated Maven and Gradle work. It over-routed less than Gemini, but its 18.52% false-positive rate remains significant.

**`gemini-3.1-pro-preview`** detected every eligible request but produced 23 false positives across unsupported Ant and npm projects and unrelated Maven and Gradle work. It provides complete coverage but does not reliably enforce project and topic boundaries.

## 3. Token Cost Estimate

The skill description is approximately 77 input tokens, and the full `SKILL.md` is approximately 647 input tokens. The observed post-load increase of 613-694 tokens confirms that **one full skill load costs approximately 650 input tokens**.

A typical successful route uses three model calls: load the skill, validate the project, and present the choice. The direct skill-text input is therefore approximately:

```text
3 x 77 description tokens + 2 x 647 full-skill tokens = 1,525 input tokens
```

Later turns use prompt caching, so billed cost may be lower than the raw 1,525-token estimate. OTel reports cache usage for the complete call and cannot isolate the cached portion belonging specifically to the skill.

### Results by Model

The table uses true-positive runs only because they demonstrably loaded and followed the skill through the routing choice.

| Model | TP samples | Post-load input increase | Direct skill input | Routing cache rate | Skill loads per TP |
| --- | ---: | ---: | ---: | ---: | ---: |
| `gpt-5.6-sol` | 23 | 627 | 1,616 | 66.2% | 1.17 |
| `gpt-5.5` | 24 | 613 | 1,585 | 58.7% | 1.04 |
| `gpt-5.4` | 15 | 616 | 1,477 | 59.8% | 1.13 |
| `gpt-5.3-codex` | 24 | 684 | 1,525 | 55.7% | 1.96 |
| `grok-4.5` | 24 | 694 | 1,525 | 69.2% | 2.92 |
| `gemini-3.1-pro-preview` | 24 | 659 | 1,525 | 35.7% | 2.71 |

Direct skill cost is stable at approximately 1.5K raw input tokens per successful route. The main model-dependent difference is repeated loading: the GPT-5.4/5.5/5.6 models generally load the skill once, while GPT-5.3 Codex, Grok, and Gemini reload it more often. Overall routing input is approximately 21K-24K tokens, but most of that is system instructions, tool definitions, and conversation history rather than skill content.

## 4. Conclusion

Across all 468 runs, the skill achieved **89.96% overall accuracy, 78.36% precision, and 93.06% recall**. Results varied by model from 70.51% to 100% accuracy, with `gpt-5.5` correctly handling all 78 runs. The main accuracy risk is model consistency: weaker results came from either missed eligible requests or over-routing to unsupported projects and topics.

Direct token overhead is modest: the description adds about **77 input tokens per model call**, one full skill load adds about **650 input tokens**, and a typical three-call routing sequence carries about **1.5K raw input tokens** attributable to the skill. Later calls can reuse the description and skill body through prompt caching, so billed cost may be lower than the raw total. Overall, model consistency and repeated skill loading are greater concerns than direct token cost.