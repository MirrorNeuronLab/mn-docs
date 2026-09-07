# Skill Catalog

This is the internal inventory of reusable Python skill packages in `mn-skills/`. It is intentionally a package catalog, not a substitute for each skill's README, `SKILL.md`, tests, dependency metadata, or security review.

## Source and maintenance

The authoritative package metadata is each package's `pyproject.toml`; behavior and required credentials are defined by its source, tests, README, and `SKILL.md` where present. Update this inventory when adding, removing, or renaming a package.

## Packages

| Folder | Python package |
| --- | --- |
| `actor_review_skill` | `mirrorneuron-actor-review-skill` |
| `autonomous_research_skill` | `mirrorneuron-autonomous-research-skill` |
| `client_report_skill` | `mirrorneuron-client-report-skill` |
| `code_generation_skill` | `mirrorneuron-code-generation-skill` |
| `document_reading_skill` | `mirrorneuron-document-reading-skill` |
| `email_delivery_skill` | `mirrorneuron-email-delivery-skill` |
| `email_receive_agentmail_skill` | `mirrorneuron-email-receive-agentmail-skill` |
| `email_send_resend_skill` | `mirrorneuron-email-send-resend-skill` |
| `evidence_engine_skill` | `mirrorneuron-evidence-engine-skill` |
| `first_draft_slides_skill` | `mirrorneuron-first-draft-slides-skill` |
| `generate_fake_data_skill` | `mirrorneuron-generate-fake-data-skill` |
| `graph_analysis_skill` | `mirrorneuron-graph-analysis-skill` |
| `implementation_plan_skill` | `mirrorneuron-implementation-plan-skill` |
| `live_video_analysis_skill` | `mirrorneuron-live-video-analysis-skill` |
| `llm_ocr_skill` | `mirrorneuron-llm-ocr-skill` |
| `market_research_skill` | `mirrorneuron-market-research-skill` |
| `marketing_email_skill` | `mirrorneuron-marketing-email-skill` |
| `meeting_summary_skill` | `mirrorneuron-meeting-summary-skill` |
| `pdf_extract_skill` | `mirrorneuron-pdf-extract-skill` |
| `process_map_skill` | `mirrorneuron-process-map-skill` |
| `public_research_orchestrator_skill` | `mirrorneuron-public-research-orchestrator-skill` |
| `scoring_framework_skill` | `mirrorneuron-scoring-framework-skill` |
| `slack_communicate_skill` | `mirrorneuron-slack-communicate-skill` |
| `spreadsheet_analysis_skill` | `mirrorneuron-spreadsheet-analysis-skill` |
| `text_analysis_skill` | `mirrorneuron-text-analysis-skill` |
| `vendor_comparison_skill` | `mirrorneuron-vendor-comparison-skill` |
| `web_browser_skill` | `mirrorneuron-web-browser-skill` |

Runtime infrastructure is maintained as independent SDK component packages:
`mn-python-sdk-common`, `mn-python-sdk-web-ui`, `mn-python-sdk-models`,
`mn-python-sdk-rag`, `mn-python-sdk-mcp`, `mn-python-sdk-collaboration`, and
`mn-python-sdk-job-response`. See [Python SDK](SDK.md#optional-components).
MCP usage and work-packet authoring retain instruction-only Agent Skills.

## Browser skills

`web_browser_skill` is the unified local browser package. It returns
readability-extracted plain text or Markdown, selects w3m or the native
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
