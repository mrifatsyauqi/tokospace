# Documentation

This folder contains the approved source-of-truth documentation for the Tokospace project.

## Core Documents

| Document | Description |
|---|---|
| [`tokospace-PRD.md`](./tokospace-PRD.md) | Product Requirements Document — feature scope, functional/non-functional requirements, business rules |
| [`tokospace-design-brief.md`](./tokospace-design-brief.md) | Design system, tokens, page breakdowns, component specs |
| [`tokospace-tech-spec.md`](./tokospace-tech-spec.md) | Technical specification — stack, monorepo architecture, infrastructure, deployment, security |
| [`tokospace-master-plan.md`](./tokospace-master-plan.md) | Development master plan — stage-by-stage build order, dependencies, repository/deployment strategy |
| [`tokospace-prompt-development.md`](./tokospace-prompt-development.md) | Ready-to-use Claude Code prompts, one per development stage |

## Architecture Decision Records

| ADR | Decision |
|---|---|
| [`adr/0001-gcp-cloud-sql-hosting-migration.md`](./adr/0001-gcp-cloud-sql-hosting-migration.md) | Target: Google Compute Engine + Cloud SQL for PostgreSQL + Google Cloud Storage (replacing R2) + Secret Manager for production credentials. Decision only — not yet implemented in the repository, see the ADR's Current State section |
| [`adr/0002-tenant-rls-session-context.md`](./adr/0002-tenant-rls-session-context.md) | `SET LOCAL` inside an explicit transaction as the mandatory tenant-context pattern for the future Tenant module |

## Repository Architecture

Tokospace uses a **single monorepo**:

```text
tokospace/
├── apps/
│   ├── api/                 # Laravel 11 backend
│   └── web/                 # Next.js 15 frontend
├── docs/                    # Product and technical source of truth
├── infra/                   # Docker/Nginx/operational configuration
├── packages/                # Shared generated contracts/types when needed
└── .github/workflows/       # Independent API/Web CI/CD
```

The monorepo does not mean a single runtime or deployment. `apps/api` targets Google Compute Engine (with Google Cloud SQL for PostgreSQL as the managed database) — approved per ADR-0001 but not yet implemented, see its Current State section — and `apps/web` deploys to Vercel through independent pipelines.

## Document Authority

- **PRD** → business requirements and acceptance criteria
- **Tech Spec** → technical architecture and infrastructure
- **Design Brief** → visual and interaction decisions
- **Master Plan** → development sequence and dependencies
- **Prompt Development** → AI execution instructions

If a change affects architecture or scope, record it through an ADR and update the relevant authority document before implementation continues.
