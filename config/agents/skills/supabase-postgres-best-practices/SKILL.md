---
name: supabase-postgres-best-practices
description: |
  Apply Supabase-maintained Postgres rules to database work. This includes SQL,
  schemas, migrations, constraints, indexes, RLS, privileges, connections,
  locking, batching, pagination, full-text search, JSONB, and EXPLAIN work.
  Do not use for Grafana design or unsupported operations such as pgvector,
  pg_cron, pgmq, and pg_restore.
license: MIT
metadata:
  author: supabase
  version: "1.6.0"
  organization: Supabase
  date: July 2026
  abstract: Postgres design, security, and performance rules for Supabase and other Postgres deployments.
---

# Supabase Postgres Best Practices

Postgres design, security, and performance rules maintained by Supabase.
Load only the reference files needed for the current task.

## When to Apply

Reference these guidelines when:

- writing SQL queries or designing schemas.
- implementing indexes or query optimization.
- reviewing database performance issues.
- configuring connection pooling or scaling.
- optimizing Postgres-specific features.
- working with row-level security (RLS).

## Rule Categories by Priority

| Priority | Category | Impact | Prefix |
| --- | --- | --- | --- |
| 1 | Query Performance | CRITICAL | `query-` |
| 2 | Connection Management | CRITICAL | `conn-` |
| 3 | Security & RLS | CRITICAL | `security-` |
| 4 | Schema Design | HIGH | `schema-` |
| 5 | Concurrency & Locking | MEDIUM-HIGH | `lock-` |
| 6 | Data Access Patterns | MEDIUM | `data-` |
| 7 | Monitoring & Diagnostics | LOW-MEDIUM | `monitor-` |
| 8 | Advanced Features | LOW | `advanced-` |

## How to Use

Read individual rule files for detailed explanations and SQL examples:

```text
references/query-missing-indexes.md
references/query-partial-indexes.md
references/_sections.md
```

Each rule file contains:

- a brief explanation of why it matters.
- incorrect and corrected SQL examples.
- optional `EXPLAIN` output or metrics.
- additional context and references.
- Supabase-specific notes when applicable.

## References

- [PostgreSQL documentation](https://www.postgresql.org/docs/current/)
- [Supabase documentation](https://supabase.com/docs)
- [PostgreSQL performance optimization](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [Supabase database overview](https://supabase.com/docs/guides/database/overview)
- [Supabase row-level security](https://supabase.com/docs/guides/auth/row-level-security)
