# Statistical Model Inventory

Generated: 2026-08-04

Last manual update: 2026-09-11

This is the durable branch-to-claim inventory for the maintained analysis. The
machine-readable table is `docs/statistical_model_inventory.tsv`; the validator
is `tools/check_model_inventory.py`.

## Scope

The inventory is organized at the model-family or repeated-screen level. It is
not a row for every historical exploratory `lm()` or archived Stan variant.
Archived code remains useful provenance, but the inventory gate is for current
paper/talk claims and maintained diagnostics. The active scan now covers `Code/`,
`R/`, and maintained `analysis/` folders while explicitly excluding
`Code/archive/`.

The current row classes are:

- `primary`: promoted inference model.
- `support`: current supporting model or candidate extension.
- `sensitivity`: fitted branch used only to bracket interpretation.
- `diagnostic`: post-fit screen, EWS, portfolio, valuation, or claim gate.
- `exploratory`: source-traceable design/proxy work that is not promoted.
- `retired`: failed, stale, archived, or likelihood-incompatible model.

## Current Read

- `m1_stier_11` remains the only promoted Haida Gwaii population baseline.
- `m3_bc` is the current coastwide candidate by full-fit calibration, but the
  completed robust K-fold comparison is positive but uncertain; do not promote
  it as a clear predictive winner over `m1_bc`.
- `m1_bc_geom` and `m3_bc_geom` are conservative geometry-repair candidates
  added after the 2026-09-11 full-fit refresh showed low E-BFMI and unstable
  PSIS in the original coastwide M1/M3 fits. They remove unused range
  parameters and simplify initial-state/scale geometry. They are diagnostic
  candidates only until smoke tests, full post-fit gates, and robust CV clear.
- `m1_bc_marginal` and `m3_bc_marginal` are stronger geometry-repair
  candidates that integrate over latent section-year states with a Kalman
  filter and sample latent states in generated quantities. Local subset and
  all-area pilots cleared the hard HMC geometry gate, and full GRIT production
  fits now clear the sampler and PSIS-LOO gates. Within this repaired family,
  `m3_bc_marginal` is the statistically usable coastwide sensitivity, but it is
  a geometry/LOO repair rather than a new biological mechanism.
- Public CSAS Appendix B catch tables are now represented by the
  `bc_catch_pressure_sensitivity` row. Those branches are negative
  sensitivities: they do not materially improve M1/M3 inference and both fail
  the E-BFMI sampler gate.
- `m5_bc` is retired/failed for predator inference in the current coastwide
  round.
- Predator, heatwave/bottom-up, and Doherty-style rows are context or data-gated
  until their covariate products and model diagnostics clear stricter gates.

## Validation

Run:

```bash
python3 tools/check_model_inventory.py \
  --root . \
  --inventory docs/statistical_model_inventory.tsv \
  --output Output/diagnostics/statistical_model_inventory_check.csv \
  --role-column attribution_role \
  --scan-dir Code \
  --scan-dir R \
  --scan-dir inst/stan \
  --scan-dir analysis/01_ews \
  --scan-dir analysis/02_resilience \
  --scan-dir analysis/03_bioeconomics \
  --scan-dir analysis/05_bc_coastwide \
  --ignore-dir Code/archive \
  --status primary --status support --status sensitivity \
  --status diagnostic --status exploratory --status figure_only \
  --status retired
```

The scan is broad enough to catch maintained active scripts with statistical
calls, but it deliberately excludes cold archive code. Archive branches should
be represented only when they are used for a current manuscript or talk claim.

## Maintenance Rule

Any new fitted Stan branch, robust CV refit, promoted diagnostic screen, or
manuscript-visible model comparison must add or update a row in
`docs/statistical_model_inventory.tsv` before the result is used in prose or
figures.
