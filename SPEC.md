# MirrorNeuron Documentation Repository Specification

## Purpose

`mn-docs` is the detailed internal, operator, integrator, and contributor
documentation source for the MirrorNeuron ecosystem. It explains current
product contracts owned by other repositories and provides canonical task,
reference, architecture, security, and troubleshooting pages.

This specification governs this documentation repository only. Documentation
describes product behavior; it does not create behavior that code does not have.

## Reader Outcomes

The documentation must let:

- evaluators decide whether the product fits a workload and risk model;
- developers install and verify a safe first workflow;
- blueprint authors understand manifest, bundle, skill, and runtime boundaries;
- operators diagnose failures and choose a safe next action; and
- contributors locate the owning component and validate focused changes.

## Canonical Topology

`index.md` is the navigation source. Canonical detailed ownership is:

- concepts: `core-concepts.md`;
- CLI: `cli.md`;
- REST/streaming API: `api.md`;
- configuration: `env_variables.md`;
- blueprint and bundle formats: `blueprint-standard.md`, `bundle.md`;
- runtime/cluster/reliability: the corresponding architecture pages;
- security: `security.md`; and
- recovery: `troubleshooting.md` and `redis-ha.md`.

Pages with a different reader task link to these sources instead of maintaining
competing copies of a full contract.

## Evidence Contract

Product claims are grounded, in order, in public schemas/contracts, automated
tests, implementation, release artifacts, and reproducible runtime evidence.
Commands and exact output are verified against the current owning component.
Unsupported or unverified claims are labeled as such, not stated as guarantees.

Maturity, performance, privacy, reliability, compatibility, and platform
support claims require an explicit implementation or release source.

## Page Requirements

Every substantial page has one primary type: tutorial, how-to, reference,
explanation, troubleshooting, migration, or decision record. It defines its
audience, outcome, prerequisites, scope, and exclusions.

Runnable procedures include:

- the working directory and required services/environment;
- exact commands with defined placeholders;
- the observable verification condition;
- side effects and security implications; and
- cleanup or rollback where state changes.

References define fields/options, defaults, constraints, side effects, errors,
and small valid examples. Troubleshooting begins with an observable symptom and
uses read-only diagnostics before mutation.

## Safety and Synchronization

Warnings precede destructive, secret-bearing, network-exposing, trust-changing,
or unreviewed-code operations. Examples contain no real credentials or private
data.

When a user-visible fact changes, the detailed page here and the corresponding
public documentation-site page are updated together when both are in scope.
README files in component repositories remain concise entrypoints and link to
the canonical detail here.

## Compatibility

Stable anchors and internal links are part of the documentation interface.
Renaming a page or heading requires updating all incoming links or providing an
appropriate redirect in the publishing layer. Removed product behavior is not
left as an unqualified current procedure.

## Acceptance

A documentation change is complete when local links and Markdown syntax pass,
diagrams render, relevant product behavior has been checked at the owning
source, unsafe operations include warnings/recovery, and untested limitations
are recorded. `documentation-style.md` is the detailed normative authoring
standard.
