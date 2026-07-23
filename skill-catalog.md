# Skill Catalog

This is the internal inventory of reusable Python skill packages in `mn-skills/`. It is intentionally a package catalog, not a substitute for each skill's README, `SKILL.md`, tests, dependency metadata, or security review.

## Source and maintenance

The authoritative package metadata is each package's `pyproject.toml`; behavior and required credentials are defined by its source, tests, README, and `SKILL.md` where present. Update this inventory when adding, removing, or renaming a package.

## Packages

| Folder | Python package |
| --- | --- |
| `actor_review_skill` | `mirrorneuron-actor-review-skill` |
| `blueprint_support_skill` | `mirrorneuron-blueprint-support-skill` |
| `client_report_skill` | `mirrorneuron-client-report-skill` |
| `code_generation_skill` | `mirrorneuron-code-generation-skill` |
| `document_reading_skill` | `mirrorneuron-document-reading-skill` |
| `email_delivery_skill` | `mirrorneuron-email-delivery-skill` |
| `email_receive_agentmail_skill` | `mirrorneuron-email-receive-agentmail-skill` |
| `email_send_resend_skill` | `mirrorneuron-email-send-resend-skill` |
| `evidence_engine_skill` | `mirrorneuron-evidence-engine-skill` |
| `external_rate_limit_skill` | `mirrorneuron-external-rate-limit-skill` |
| `first_draft_slides_skill` | `mirrorneuron-first-draft-slides-skill` |
| `generate_fake_data_skill` | `mirrorneuron-generate-fake-data-skill` |
| `implementation_plan_skill` | `mirrorneuron-implementation-plan-skill` |
| `live_video_analysis_skill` | `mirrorneuron-live-video-analysis-skill` |
| `llm_ocr_skill` | `mirrorneuron-llm-ocr-skill` |
| `market_research_skill` | `mirrorneuron-market-research-skill` |
| `marketing_email_skill` | `mirrorneuron-marketing-email-skill` |
| `mcp_client_skill` | `mirrorneuron-mcp-client-skill` |
| `meeting_summary_skill` | `mirrorneuron-meeting-summary-skill` |
| `pdf_extract_skill` | `mirrorneuron-pdf-extract-skill` |
| `process_map_skill` | `mirrorneuron-process-map-skill` |
| `public_research_orchestrator_skill` | `mirrorneuron-public-research-orchestrator-skill` |
| `rag_skill` | `mirrorneuron-rag-skill` |
| `scoring_framework_skill` | `mirrorneuron-scoring-framework-skill` |
| `slack_communicate_skill` | `mirrorneuron-slack-communicate-skill` |
| `spreadsheet_analysis_skill` | `mirrorneuron-spreadsheet-analysis-skill` |
| `text_analysis_skill` | `mirrorneuron-text-analysis-skill` |
| `vendor_comparison_skill` | `mirrorneuron-vendor-comparison-skill` |
| `web_browser_skill` | `mirrorneuron-web-browser-skill` |
| `web_ui_skill` | `mirrorneuron-web-ui-skill` |
| `websocket_stream_skill` | `mirrorneuron-websocket-stream-skill` |

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
