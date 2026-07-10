# Choose a Checked-In Blueprint

This is the detailed internal catalog guide for selecting, validating, and maintaining blueprints under `otterdesk-blueprints/`. It is not a promise that every listed blueprint will run on every developer machine.

## Reader and outcome

- **Reader:** evaluator, blueprint author, operator, or contributor selecting a checked-in workflow.
- **Outcome:** choose a blueprint that matches the task, trust boundary, data classification, and available resources; validate it before launch.
- **Page type:** how-to guide.
- **Sources of truth:** each blueprint folder's `manifest.json`, `config/`, `README.md`, `SPEC.md`, test suite, and `mn blueprint validate` behavior.

## Before you begin

- Start the runtime and inspect it with `mn runtime health`.
- Read the folder's manifest, payloads, runner declarations, model/service requirements, and `pass_env` entries.
- Use sample, mock, quick-test, or dry-run configuration where the blueprint provides it.
- Do not supply private, regulated, or production data until you have reviewed the blueprint's data movement and output skills.

## Local catalog

| Folder | Primary use | Resource or integration boundary | Human-control boundary |
| --- | --- | --- | --- |
| [`drug_discovery_research_assistant`](../otterdesk-blueprints/drug_discovery_research_assistant/README.md) | Early discovery research and candidate-review packets. | Model and research integrations are configuration-dependent. | Does not perform clinical, regulatory, or wet-lab validation. |
| [`financial_advisor`](../otterdesk-blueprints/financial_advisor/README.md) | Household finance, tax, and portfolio review packets. | Handles financial documents and can use local model profiles. | Does not file, trade, move money, pay bills, or open accounts. |
| [`generic_customer_service_voice_coworker`](../otterdesk-blueprints/generic_customer_service_voice_coworker/README.md) | Local voice customer-service experience. | Requires eligible NVIDIA hardware and declared ASR, TTS, HTTPS/WebRTC, and model services. | Escalation policy and operator review define handoff behavior. |
| [`medical_deid_record_intake_assistant`](../otterdesk-blueprints/medical_deid_record_intake_assistant/README.md) | PHI/PII detection and de-identification review. | Handles local document folders and can use local OCR/model services. | Privacy-officer review is required before release or downstream use. |
| [`personal_legal_assistant`](../otterdesk-blueprints/personal_legal_assistant/README.md) | Invoice, bill, and contract review. | Processes local legal/payable documents. | Does not give legal advice, sign documents, post invoices, or send payment instructions. |
| [`property_deal_research_assistant`](../otterdesk-blueprints/property_deal_research_assistant/README.md) | Real-estate opportunity research and comparison. | Inputs can include local notes and external research configured by the blueprint. | Produces review material, not acquisition decisions. |
| [`safety_video_analyser`](../otterdesk-blueprints/safety_video_analyser/README.md) | Batch review of local workplace footage. | Requires NVIDIA CUDA placement for visual analysis. | Does not certify safety or trigger operations by itself. |
| [`vc_assistant`](../otterdesk-blueprints/vc_assistant/README.md) | Startup-document research and score-only reports. | Uses local document processing and may perform configured public research. | Does not decide whether to invest, pass, watch, or reject. |
| [`video_watch_assistant`](../otterdesk-blueprints/video_watch_assistant/README.md) | Monitoring an approved local or mapped video stream. | Requires NVIDIA CUDA placement and a reviewed stream/alert configuration. | Writes observations and status; alert delivery is configuration-dependent. |

## Validate a local folder

From the workspace root:

```bash
mn blueprint validate otterdesk-blueprints/<blueprint_folder>
```

Replace `<blueprint_folder>` with one of the table entries. Validation must exit successfully before a normal launch. It checks the bundle and declared requirements, but it does not prove that model output is correct, external credentials are authorized, or an external service will behave as expected.

## Launch and inspect

```bash
mn runtime start
mn blueprint run --folder otterdesk-blueprints/<blueprint_folder>
```

Record `<job_id>` and `<run_id>` returned by the command, then inspect both layers:

```bash
mn job status <job_id>
mn job monitor <job_id>
mn blueprint logs <run_id>
```

For a catalog-managed blueprint, list the active catalog before launching an ID:

```bash
mn blueprint list
mn blueprint run <blueprint_id>
```

The active catalog is configured by `MN_BLUEPRINT_SOURCE`, `MN_BLUEPRINT_REPO`, and `MN_BLUEPRINT_LOCAL`. The default source contract lives in `mn-python-sdk/mn_sdk/blueprint_source.py`; see [Environment Variables](env_variables.md) for operator-facing configuration.

## Maintain a blueprint example

When you add or alter a blueprint:

1. Update the folder `README.md`, `SPEC.md`, manifest, configuration, and any sample-input description together.
2. State runner, model, service, device, input, output, external-network, and human-control requirements explicitly.
3. Keep sample inputs synthetic or otherwise safe to redistribute.
4. Add or update a focused validation/test command in the blueprint README.
5. Update this table and `mn-doc-site/content/docs/examples.mdx` if the user-facing catalog changes.

## Related pages

- [Quickstart](quickstart.md)
- [Blueprint Standard](blueprint-standard.md)
- [Resources and Devices](resources-and-devices.md)
- [Model Runtime](model-runtime.md)
- [Security Model](security.md)
