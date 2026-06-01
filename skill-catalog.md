# Skill Catalog

This catalog centralizes durable summaries for reusable skill packages so
package-level README files can stay short.

| Folder | Package | Purpose |
| --- | --- | --- |
| [`blueprint_support_skill`](../mn-skills/blueprint_support_skill/README.md) | `mirrorneuron-blueprint-support-skill` | Shared MirrorNeuron blueprint logging, progress, quick-test, and manifest helpers. |
| [`client_report_skill`](../mn-skills/client_report_skill/README.md) | `mirrorneuron-client-report-skill` | Reusable client report outline, Markdown rendering, and quality review helpers. |
| [`code_generation_skill`](../mn-skills/code_generation_skill/README.md) | `mirrorneuron-code-generation-skill` | Reusable code/script specification, safe filename, and Python skeleton helpers. |
| [`document_reading_skill`](../mn-skills/document_reading_skill/README.md) | `mirrorneuron-document-reading-skill` | Reusable document reading, normalization, outline, and chunking helpers. |
| [`email_delivery_skill`](../mn-skills/email_delivery_skill/README.md) | `mirrorneuron-email-delivery-skill` | Reusable email and Slack delivery helpers with dry-run support for MirrorNeuron blueprints. |
| [`email_receive_agentmail_skill`](../mn-skills/email_receive_agentmail_skill/README.md) | `mirrorneuron-email-receive-agentmail-skill` | MirrorNeuron skill package for polling and replying to AgentMail inbox messages. |
| [`email_send_resend_skill`](../mn-skills/email_send_resend_skill/README.md) | `mirrorneuron-email-send-resend-skill` | MirrorNeuron skill package for sending email through Resend. |
| [`external_rate_limit_skill`](../mn-skills/external_rate_limit_skill/README.md) | `mirrorneuron-external-rate-limit-skill` | MirrorNeuron skill package for throttling external API and function calls. |
| [`first_draft_slides_skill`](../mn-skills/first_draft_slides_skill/README.md) | `mirrorneuron-first-draft-slides-skill` | Reusable helpers for turning briefs and sections into first-draft slide outlines. |
| [`generate_fake_data_skill`](../mn-skills/generate_fake_data_skill/README.md) | `mirrorneuron-generate-fake-data-skill` | Generate batch or streaming fake data from JSON specs for MirrorNeuron blueprints. |
| [`implementation_plan_skill`](../mn-skills/implementation_plan_skill/README.md) | `mirrorneuron-implementation-plan-skill` | Reusable implementation plan, milestone, dependency, and risk register helpers. |
| [`litellm_communicate_skill`](../mn-skills/litellm_communicate_skill/README.md) | `mirrorneuron-litellm-communicate-skill` | Shared LiteLLM-compatible LLM wrapper for MirrorNeuron blueprints. |
| [`llm_ocr_skill`](../mn-skills/llm_ocr_skill/README.md) | `mirrorneuron-llm-ocr-skill` | Shared local LLM OCR helpers using Docker Model Runner and LightOnOCR. |
| [`market_research_skill`](../mn-skills/market_research_skill/README.md) | `mirrorneuron-market-research-skill` | Reusable market research brief, source synthesis, and outline helpers. |
| [`marketing_email_skill`](../mn-skills/marketing_email_skill/README.md) | `mirrorneuron-marketing-email-skill` | Reusable deterministic email draft, rendering, and quality-check helpers. |
| [`meeting_summary_skill`](../mn-skills/meeting_summary_skill/README.md) | `mirrorneuron-meeting-summary-skill` | Reusable meeting transcript parsing, action extraction, and summary formatting helpers. |
| [`pdf_extract_skill`](../mn-skills/pdf_extract_skill/README.md) | `mirrorneuron-pdf-extract-skill` | MirrorNeuron skill package for extracting text from PDF files. |
| [`process_map_skill`](../mn-skills/process_map_skill/README.md) | `mirrorneuron-process-map-skill` | Reusable process map node, edge, gap, and Mermaid flowchart helpers. |
| [`slack_communicate_skill`](../mn-skills/slack_communicate_skill/README.md) | `mirrorneuron-slack-communicate-skill` | Reusable Slack OAuth bot message helper for MirrorNeuron blueprints. |
| [`spreadsheet_analysis_skill`](../mn-skills/spreadsheet_analysis_skill/README.md) | `mirrorneuron-spreadsheet-analysis-skill` | Reusable CSV/table profiling, numeric summary, and data quality helpers. |
| [`text_analysis_skill`](../mn-skills/text_analysis_skill/README.md) | `mirrorneuron-text-analysis-skill` | MirrorNeuron skill package for deterministic text splitting, classification, and chunk aggregation. |
| [`vendor_comparison_skill`](../mn-skills/vendor_comparison_skill/README.md) | `mirrorneuron-vendor-comparison-skill` | Reusable vendor comparison matrix, weighted scoring, and recommendation helpers. |
| [`web_fetch_skill`](../mn-skills/web_fetch_skill/README.md) | `mirrorneuron-web-fetch-skill` | MirrorNeuron skill package for fetching web pages and optional screenshots. |
| [`websocket_stream_skill`](../mn-skills/websocket_stream_skill/README.md) | `mirrorneuron-websocket-stream-skill` | MirrorNeuron skill package for declaring WebSocket stream inputs and outputs. |

## Maintenance Notes

- Keep package names aligned with each `pyproject.toml`.
- Keep skill usage instructions in `SKILL.md`.
- Keep cross-skill guidance in [Blueprints and Skills](blueprints-and-skills.md).
