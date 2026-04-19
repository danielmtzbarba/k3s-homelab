# Infrastructure

For this project stage, use:

```text
infra/
└── terraform/
    ├── bootstrap/
    └── server/
```

This is the right layout for now.

Why:

- `infra/terraform/server/` is tool-first and scales cleanly
- `infra/server/terraform/` is awkward once you add shared network, state, or more environments
- a flat first stack is easier to understand than early modules

## Production-Oriented Rule

Use this progression:

1. `infra/terraform/bootstrap/`
2. `infra/terraform/server/`
3. `infra/terraform/worker/`
4. modules only after repetition becomes real

Do not start with deep nesting for a single VM lab.
