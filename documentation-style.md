# Documentation Style

Use this guide when adding or changing pages in `mn-docs`.

## Tone

- Clear
- Practical
- Friendly
- Direct

Avoid vague sentences such as "configure it as needed." Say what to configure,
where to configure it, and how to verify it worked.

## Page Types

MirrorNeuron docs use four page types:

| Type | Purpose | Examples |
| --- | --- | --- |
| Tutorial | Walk through a complete path | [Quickstart](quickstart.md) |
| How-to guide | Solve one task | [Redis High Availability](redis-ha.md), [Cluster Guide](cluster.md) |
| Reference | Provide exact facts | [CLI Reference](cli.md), [Environment Variables](env_variables.md), [API](api.md) |
| Explanation | Explain design and tradeoffs | [Runtime Architecture](runtime-architecture.md), [Security Model](security.md) |

## Page Titles

Use action titles for guides.

Good:

- Start a two-box cluster
- Configure Redis Sentinel HA
- Create a Python-defined blueprint

Avoid:

- Cluster
- Redis stuff
- Python

## Commands

Always use fenced code blocks:

```bash
mn blueprint run --folder otterdesk-blueprints/tax_form_ocr_capture_assistant
```

Include the working directory when it matters:

```bash
cd MirrorNeuron
mix test
```

Use current CLI command names. Prefer `mn blueprint run` for blueprint launches.

## Expected Output

Show expected output after important commands:

```text
PONG
```

For commands with noisy logs, show the stable success marker:

```text
All selected test suites passed.
```

## Warnings

Use warnings for security, data loss, public network exposure, and irreversible cleanup.

Example:

```md
Warning: `mn job clear` affects persisted Redis job records. Use a test namespace when experimenting.
```

## Examples

Prefer examples from checked-in OtterDesk blueprints:

- `otterdesk-blueprints/tax_form_ocr_capture_assistant`
- `otterdesk-blueprints/portfolio_risk_review_assistant`
- `otterdesk-blueprints/video_watch_assistant`
- `otterdesk-blueprints/gtm_ai_workflow`
- `otterdesk-blueprints/personal_financial_advisor`

Use catalog-only ids when documenting the cached blueprint library.

## Folder README Standard

Most folder-level `README.md` files should stay quick. Put durable detail in
`mn-docs` and link to it.

Exception: blueprint folders, including `otterdesk-blueprints`, should stay
self-contained. Their README files may include local catalog, input/output,
safety, and validation detail because users often inspect a blueprint folder
without opening the central docs.

A quick README should include:

- one-sentence purpose;
- one or two safe first commands;
- the smallest useful validation command;
- links to the detailed guide, API reference, architecture page, or local spec.

Do not duplicate long environment-variable tables, architecture explanations,
release procedures, or troubleshooting sections in non-blueprint component
READMEs. Move that material to a durable page such as
[Component Guide](component-guide.md), [Environment Variables](env_variables.md),
[Runtime Architecture](runtime-architecture.md), or
[Troubleshooting](troubleshooting.md).

## Links

End each page with the next useful page. Good docs should help readers continue
without guessing.

## Docs PR Checklist

- [ ] The page has one clear purpose.
- [ ] Commands are copy-pasteable from the stated working directory.
- [ ] Important commands include expected output.
- [ ] Security implications are called out.
- [ ] Links are relative and point to existing pages.
- [ ] Troubleshooting was updated if the change addresses a repeated failure.

## Recommended CI Checks

- Markdown lint.
- Broken link checker.
- Spellcheck with project-specific vocabulary.
- Docs build check.
- Example command smoke tests for fast, non-destructive examples.

## Related Pages

- [Contributing](contributing.md)
- [Testing](testing.md)
- [Troubleshooting](troubleshooting.md)
