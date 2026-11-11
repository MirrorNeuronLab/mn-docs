# Skill Catalog

## Current contract requirement

Skill identities use the current hyphenated distribution-derived name. Dotted aliases and generated legacy-name metadata are removed. Code search traces use Tree-sitter; the old regex trace backend is unsupported.

This is the internal inventory of reusable Python skill packages in `mn-skills/`. It is intentionally a package catalog, not a substitute for each skill's README, `SKILL.md`, tests, dependency metadata, or security review.

## Source and maintenance

The authoritative package metadata is each package's `pyproject.toml`; behavior and required credentials are defined by its source, tests, README, and `SKILL.md` where present. Update this inventory when adding, removing, or renaming a package.

## Packages

| Folder                               | Python package                                    |
| ------------------------------------ | ------------------------------------------------- |
| `actor_review_skill`                 | `mirrorneuron-actor-review-skill`                 |
| `autonomous_research_skill`          | `mirrorneuron-autonomous-research-skill`          |
| `beam_analysis_skill`                | `mirrorneuron-beam-analysis-skill`                |
| `client_report_skill`                | `mirrorneuron-client-report-skill`                |
| `code_generation_skill`              | `mirrorneuron-code-generation-skill`              |
| `code_search_skill`                  | `mirrorneuron-code-search-skill`                  |
| `computer_use_skill`                 | `mirrorneuron-computer-use-skill`                 |
| `docs_to_markdown_skill`             | `mirrorneuron-docs-to-markdown-skill`             |
| `email_delivery_skill`               | `mirrorneuron-email-delivery-skill`               |
| `email_receive_agentmail_skill`      | `mirrorneuron-email-receive-agentmail-skill`      |
| `email_send_resend_skill`            | `mirrorneuron-email-send-resend-skill`            |
| `evidence_engine_skill`              | `mirrorneuron-evidence-engine-skill`              |
| `first_draft_slides_skill`           | `mirrorneuron-first-draft-slides-skill`           |
| `folder_files_skill`                 | `mirrorneuron-folder-files-skill`                 |
| `generate_fake_data_skill`           | `mirrorneuron-generate-fake-data-skill`           |
| `graph_analysis_skill`               | `mirrorneuron-graph-analysis-skill`               |
| `implementation_plan_skill`          | `mirrorneuron-implementation-plan-skill`          |
| `live_video_analysis_skill`          | `mirrorneuron-live-video-analysis-skill`          |
| `macos_logs_skill`                   | `mirrorneuron-macos-logs-skill`                   |
| `market_research_skill`              | `mirrorneuron-market-research-skill`              |
| `marketing_email_skill`              | `mirrorneuron-marketing-email-skill`              |
| `meeting_summary_skill`              | `mirrorneuron-meeting-summary-skill`              |
| `nvidia_ocr_skill`                   | `mirrorneuron-nvidia-ocr-skill`                   |
| `nvidia_transcribe_skill`            | `mirrorneuron-nvidia-transcribe-skill`            |
| `opencode_skill`                     | `mirrorneuron-opencode-skill`                     |
| `process_map_skill`                  | `mirrorneuron-process-map-skill`                  |
| `public_research_orchestrator_skill` | `mirrorneuron-public-research-orchestrator-skill` |
| `scoring_framework_skill`            | `mirrorneuron-scoring-framework-skill`            |
| `slack_communicate_skill`            | `mirrorneuron-slack-communicate-skill`            |
| `spreadsheet_analysis_skill`         | `mirrorneuron-spreadsheet-analysis-skill`         |
| `static_code_analysis_skill`         | `mirrorneuron-static-code-analysis-skill`         |
| `temporal_graph_skill`               | `mirrorneuron-temporal-graph-skill`               |
| `text_analysis_skill`                | `mirrorneuron-text-analysis-skill`                |
| `vendor_comparison_skill`            | `mirrorneuron-vendor-comparison-skill`            |
| `web_browser_skill`                  | `mirrorneuron-web-browser-skill`                  |
| `web_report_skill`                   | `mirrorneuron-web-report-skill`                   |

Runtime infrastructure is maintained as independent SDK component packages:
`mn-python-sdk-common`, `mn-python-sdk-web-ui`, `mn-python-sdk-models`,
`mn-python-sdk-rag`, `mn-python-sdk-mcp`, `mn-python-sdk-collaboration`, and
`mn-python-sdk-job-response`. See [Python SDK](SDK.md#optional-components).
MCP usage and work-packet authoring retain instruction-only Agent Skills.

## Document processing

`docs_to_markdown_skill` owns complete local Markdown conversion, embedded PDF
extraction, lazy OCR and document-intake helpers. Import it through
`mn_docs_to_markdown_skill`. The NVIDIA OCR skill provides a separate
SDK-managed inference service for text and bounding boxes. SourceCorpus
retrieval and indexing remain SDK-owned.
[Markdown conversion](../mn-skills/docs_to_markdown_skill/SKILL.md) ·
[NVIDIA OCR](../mn-skills/nvidia_ocr_skill/README.md)

## Browser skills

`web_browser_skill` is the unified local browser package. It returns
readability-extracted plain text or Markdown, selects bounded local HTTP extraction or the native
agent-browser CLI internally, and exposes a policy-governed ref-based actuator
with isolated sessions, approval gates, audits, and bounded artifacts. All
browser consumers should use `web_browser_skill`; workflows remain the planner.

## Add or change a skill

1. Create or update the package `pyproject.toml`, source, README, and tests.
2. Document required local binaries, external services, environment variables, files, and network destinations.
3. Keep secrets out of package defaults and blueprint payloads; use narrowly scoped environment access.
4. Run the package's focused test suite.
5. Update this catalog, [Blueprints and Skills](blueprints-and-skills.md), and the affected blueprint documentation when the contract changes.

## Related pages

- [Blueprints and Skills](blueprints-and-skills.md)
- [Security Model](security.md)
- [Testing](testing.md)
