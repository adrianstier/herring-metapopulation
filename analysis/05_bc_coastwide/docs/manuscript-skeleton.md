# BC Coastwide Extension Manuscript Skeleton

Last updated: 2026-08-25

Purpose: keep the coastwide extension writeup aligned with the completed
diagnostics. This is a claim-safe skeleton, not a full manuscript draft.

## Current Use Class

The BC coastwide analysis is a transfer/generality sensitivity for the Haida
Gwaii portfolio result. It is not the promoted paper baseline. The promoted
Haida Gwaii model remains `m1_stier_11`.

Current coastwide wording:

> Extending the model structure across the BC coast shows that the qualitative
> portfolio problem is not unique to the Haida Gwaii model frame, but the
> coastwide branch remains a sensitivity because sampler energy and PSIS-LOO
> diagnostics are not promotion-grade.

Do not write:

> The coastwide model proves the density-dependent model is the correct
> predictive model for BC herring.

## Methods Wording

We fit coastwide state-space models to positive spawn-index observations across
101 sections and 8 DFO stock areas from 1951-2025. The baseline coastwide model
(`m1_bc`) estimates section-level latent biomass with stock-area growth
structure. The candidate density-dependent branch (`m3_bc`) adds a
stock-area-level Gompertz process. Because positive-observation PSIS-LOO had
many high Pareto-k cells, we used 5-fold masked-observation refits as the
robust comparison between `m1_bc` and `m3_bc`.

Public CSAS Appendix B catch tables were then used in two catch-pressure
sensitivities (`m1_bc_catch_pressure` and `m3_bc_catch_pressure`). These
branches use stock-area annual catch pressure lagged into next-year latent
growth. They do not allocate historical reduction/other catch to sections and
should not be described as section-level fishing reconstructions.

Primary proof objects:

- `Output/diagnostics/bc_coastwide_model_status_table.md`
- `Output/diagnostics/bc_coastwide_kfold_summary.md`
- `Output/diagnostics/bc_catch_pressure_model_readout.md`
- `Output/diagnostics/bc_catch_pressure_for_stan.md`

## Results Wording

The density-dependent coastwide branch improved full-fit positive-spawn
calibration relative to the coastwide M1 comparator (`0.316` versus `0.399`
log10 RMSE), but PSIS-LOO was not reliable enough for model promotion because
high Pareto-k cells were widespread. The 5-fold robust comparison was positive
but uncertain for `m3_bc`: held-out elpd was `24.9` higher than `m1_bc` with an
approximate SE of `92.3`, and held-out RMSE changed only from `0.626` to
`0.621` log10 units. Thus, `m3_bc` is best treated as a calibration-supported
coastwide sensitivity, not a promoted extension.

Adding public CSAS catch pressure did not materially alter that inference.
Relative to their non-catch counterparts, the catch-pressure branches had tiny
calibration changes and failed the E-BFMI sampler gate: `m1_bc_catch_pressure`
had delta elpd `-5.53` and delta RMSE `+0.0013` log10; `m3_bc_catch_pressure`
had delta elpd `-2.85` and delta RMSE `-0.0017` log10. All four chains in both
catch-pressure branches had E-BFMI below `0.3`.

Claim-safe sentence:

> Public assessment catch tables do not rescue or overturn the coastwide M1/M3
> inference; they currently function as a negative sensitivity, not as causal
> evidence for a stock-area fishing-pressure effect.

## Guardrails

- Do not promote any coastwide branch over the Haida Gwaii `m1_stier_11`
  baseline.
- Do not use `m5_bc` for predator-effect claims.
- Do not use the catch-pressure coefficient medians as evidence of a promoted
  fishing effect; the coefficient is constrained non-negative and the branches
  fail the sampler gate.
- Do not say the completed original `m1_bc` or `m3_bc` fits used pre-1972
  assessment-table catch.
- If catch pressure becomes central, repair geometry and rerun robust CV before
  interpreting it biologically.
