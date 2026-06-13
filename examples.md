# Choose A Blueprint Example

This guide helps you choose a checked-in OtterDesk blueprint for a first run,
smoke test, or runtime demonstration.

Run commands from the workspace root unless a step says otherwise.

## List Available Blueprints

```bash
mn blueprint list
```

Expected output includes:

```text
ID
Name
Job Name
```

Catalog availability depends on your cached blueprint repository. The checked-in
local catalog for this workspace is [`otterdesk-blueprints/index.json`](../otterdesk-blueprints/index.json).

## Recommended Order

| Order | Blueprint | Use it when |
| --- | --- | --- |
| 1 | `tax_form_ocr_capture_assistant` | You want a small document/OCR workflow with public sample metadata. |
| 2 | `portfolio_risk_review_assistant` | You want a finance workflow with deterministic simulation and LLM report writing. |
| 3 | `video_watch_assistant` | You want a service-style video monitoring workflow. |
| 4 | `gtm_ai_workflow` | You want a long-running GTM automation loop with CRM and outreach artifacts. |
| 5 | `personal_financial_advisor` | You want a folder-watching service with OCR, public browser research, and review-only reports. |
| 6 | `generic_customer_service_voice_coworker` | You want a local voice service backed by the NVIDIA/Spark stack. |

## 1. Tax Form OCR Capture Assistant

Path:

```text
otterdesk-blueprints/tax_form_ocr_capture_assistant
```

Use it when:

- you want a compact checked-in blueprint;
- you want document intake and OCR-style artifact output;
- you want a review-only workflow with public dataset notes.

Run:

```bash
mn blueprint run --folder otterdesk-blueprints/tax_form_ocr_capture_assistant
```

Direct runner smoke test:

```bash
cd otterdesk-blueprints/tax_form_ocr_capture_assistant
python3.11 payloads/document_workflow/scripts/run_blueprint.py --runs-root /tmp/mn-runs --run-id tax-form-demo
```

## 2. Portfolio Risk Review Assistant

Path:

```text
otterdesk-blueprints/portfolio_risk_review_assistant
```

Use it when:

- you want public market data plus deterministic risk simulation;
- you want the LLM limited to interpretation and report writing;
- you want a clear review-only human approval policy.

Run from the catalog:

```bash
mn blueprint run portfolio_risk_review_assistant
```

Run from the local folder:

```bash
mn blueprint run --folder otterdesk-blueprints/portfolio_risk_review_assistant
```

## 3. Video Watch Assistant

Path:

```text
otterdesk-blueprints/video_watch_assistant
```

Use it when:

- you want a service blueprint;
- you want visual detection events and cooldown state;
- you want to inspect live run status and service artifacts.

Run:

```bash
mn blueprint run --folder otterdesk-blueprints/video_watch_assistant --web-ui
```

Cancel the service when done:

```bash
mn job cancel <job_id>
```

## 4. GTM AI Workflow

Path:

```text
otterdesk-blueprints/gtm_ai_workflow
```

Use it when:

- you want a long-running account research and outreach loop;
- you want local CSV CRM and market-insight artifacts;
- you want to test email/inbox integrations in dry-run or test-recipient mode first.

Run:

```bash
mn blueprint run --folder otterdesk-blueprints/gtm_ai_workflow
```

Inspect run state:

```bash
mn blueprint monitor --follow
```

## 5. Personal Financial Advisor

Path:

```text
otterdesk-blueprints/personal_financial_advisor
```

Use it when:

- you want a continuous local folder-watch service;
- you want OCR plus public, privacy-safe browser research;
- you want review-only household finance reports and risk reminders.

Bounded direct runner smoke test:

```bash
cd otterdesk-blueprints/personal_financial_advisor
python3.11 payloads/document_workflow/scripts/run_blueprint.py --runs-root /tmp/mn-runs --run-id personal-finance-demo --watch --max-cycles 1
```

## 6. Pizza Order Voice AI Co-worker

Path:

```text
otterdesk-blueprints/generic_customer_service_voice_coworker
```

Use it when:

- you want a real-time voice service;
- you have the local NVIDIA/Spark stack ready;
- you want editable menu knowledge and a localhost HTTPS voice page.

Run with longer cold-start timeouts when the NVIDIA stack needs to warm up:

```bash
MN_PRE_LAUNCH_TIMEOUT_SECONDS=900 NEMOTRON_PRELAUNCH_WAIT_SECONDS=900 mn blueprint run generic_customer_service_voice_coworker
```

## Security Notes

- Review `manifest.json` before running any blueprint.
- Check `pass_env` before passing secrets.
- Use mock, sample, quick-test, and dry-run modes before external delivery.
- Treat financial, tax, legal, healthcare, and safety outputs as review-only until a qualified human approves them.
- Cancel service jobs when you are done.

## Related Pages

- [Quickstart](quickstart.md)
- [Blueprints and Skills](blueprints-and-skills.md)
- [Job Bundle Format](bundle.md)
- [Security Model](security.md)
