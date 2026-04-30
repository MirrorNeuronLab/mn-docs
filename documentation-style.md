# Documentation Style

Use this guide when adding or changing pages in `mn-docs`.

## Tone

- Clear
- Practical
- Friendly
- Direct

Avoid vague sentences such as "configure it as needed." Say what to configure, where to configure it, and how to verify it worked.

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
mn validate mn-blueprints/general_test_message_flow
```

Include the working directory when it matters:

```bash
cd MirrorNeuron
mix test
```

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
Warning: `--purge-local` can delete Redis data. Use it only for disposable test state.
```

## Examples

Prefer examples from checked-in blueprints:

- `mn-blueprints/general_test_message_flow`
- `mn-blueprints/general_python_defined_basic`
- `mn-blueprints/general_stream_live_backpressure_deamon`
- `mn-blueprints/general_prime_sweep_scale`

## Links

End each page with the next useful page. Good docs should help readers continue without guessing.

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
