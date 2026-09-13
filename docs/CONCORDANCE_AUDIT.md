# Concordance Audit

Generated: 2026-09-13

Purpose: keep manuscript/talk claims aligned with the maintained model outputs.
This is a claim-control layer, not a replacement for
`Output/diagnostics/model_decision_ledger.md`.

## Current Decision

The paper baseline remains `m1_stier_11`. The repaired BC coastwide extension
now has a statistically usable marginalized sensitivity (`m3_bc_marginal`).
The original full-state `m3_bc` remains useful provenance, but it should no
longer carry the coastwide transfer claim because the full-state M1/M3 fits had
low E-BFMI and unstable PSIS-LOO.

The completed 5-fold robust CV for the original `m1_bc` versus `m3_bc` ran on
GRIT on 2026-08-04:

- `m1_bc` folds 1-5: jobs `1069811`, `1069775`, `1069777`, `1069779`, `1069781`
- `m3_bc` folds 1-5: jobs `1069783`, `1069785`, `1069787`, `1069789`, `1069791`

Job `1069773` was the original `m1_bc` fold-1 submission. It failed during
unused package installation on GRIT and was superseded by replacement job
`1069811`; do not count `1069773`, `1069798`, or `1069806` as model fits.

`m3_bc` K-fold elpd was `24.9` higher than `m1_bc`, but the approximate
contrast SE was `92.3`; held-out RMSE improved only from `0.626` to `0.621`
log10 units. That result motivated a stronger geometry repair, not promotion
of the original full-state branch.

The 2026-09-11 marginalized repair integrated the latent section-year states by
Kalman filtering and sampled comparable latent states in generated quantities.
Full GRIT production fits completed for `m1_bc_marginal` and `m3_bc_marginal`.
Both clear sampler and PSIS gates. Within this repaired family,
`m3_bc_marginal` beats `m1_bc_marginal` by elpd `+134.2` with SE `19.0`, and
has coastwide positive-spawn RMSE `0.333` versus `0.405` log10 units. Treat
`m3_bc_marginal` as the current usable coastwide sensitivity, not as a new
biological mechanism or as a replacement for `m1_stier_11`.

The 2026-08-10 catch-pressure GRIT run completed but did not change this:
catch-pressure branches failed the E-BFMI sampler gate and had negligible
calibration changes. Do not use `m5_bc` for any predator claim.

## Claim Table

| Claim/question | Allowed wording | Primary proof object | Key number(s) | Caveat / do not say |
|---|---|---|---|---|
| Promoted model | `m1_stier_11` is the promoted Haida Gwaii baseline. | `Output/diagnostics/latest_model_status.md`; `Output/diagnostics/model_decision_ledger.md` | max Rhat `1.001`; exact re-LOO corrected LOOIC `1953.08`; positive-spawn RMSE `0.56` | Do not replace it with held branches unless a new branch clears sampler, calibration, and robust comparison gates. |
| Did recovery occur? | Closure improved aggregate biomass but did not restore the spatial portfolio. | `Output/diagnostics/fishing_closure_response.md`; `Output/diagnostics/fishing_closure_response_summary.csv` | recent/roe biomass ratio `1.52`; occupied sections fell from `8` to `5` | Do not say "no recovery anywhere"; recovery is uneven and concentrated. |
| Portfolio erosion | Recent biomass remains concentrated in a few sections. | `Output/diagnostics/m1_stier_11_portfolio_metrics.md`; `Output/diagnostics/m1_stier_11_portfolio_recent_summary.csv` | all-11 top-three share `0.84`; Simpson effective sections `3.26`; synchrony `0.63` | Do not describe this as a formal early-warning result by itself. |
| Current biomass | The 2025 all-11 median is useful but uncertainty is dominated by sparse fit-only sections. | `Output/diagnostics/current_biomass_uncertainty_decomposition.md`; `Output/diagnostics/m1_stier_11_current_year_summary.csv` | all-11 total median `82,214` t; sum of section medians `29,851` t; top-three share `0.76` in the current-year table | Do not headline the all-11 upper interval without the Tasu/Naden tail caveat. |
| Historical fishing | Historical fishing pressure is the cleanest section-level recovery axis. | `Output/diagnostics/section_recovery_covariate_screen.md`; `Output/diagnostics/fishing_pressure_decomposition.md` | recovery versus mean historical fishing fraction rho `-0.66` | This is an n=11 descriptive axis, not a causal coefficient. |
| Predators | Predation is plausible context, but no predator coefficient is promoted. | `Output/diagnostics/model_decision_ledger.md`; `Output/diagnostics/predator_talk_brief.md`; `Output/diagnostics/bc_coastwide_model_status_table.md` | HG predator branches held; `m5_bc` max Rhat `14.85`, min ESS `2.0`, treedepth hits `10,000` | Do not say predators explain failed recovery from the current Stan branches. |
| Heatwave / Blob | The Blob likely added climate stress to an already eroded portfolio; it is not the promoted recovery mechanism. | `Output/diagnostics/heatwave_bottomup_scope.md`; `Output/diagnostics/heatwave_bottomup_signal_screen.csv` | lag-1 MHW adjusted beta approximately `0`; lag-1 PDO rho `-0.49`, detrended r `-0.42` | Do not launch or cite a full heatwave branch from the three-year pulse alone. |
| Bloom/plankton | Satellite Chl-a bloom phenology does not promote a bottom-up mechanism; zooplankton energy remains the data gap. | `Output/diagnostics/bloom_phenology_herring_screen.md`; `docs/bottom-up-plankton-data-scope.md` | annual MODIS bloom product spans `2003-2025`; all growth-screen rows are `weak_screen_only` | Do not call Chl-a a zooplankton or prey-quality test. |
| EWS rigor | There is one claim-safe EWS result: observed aggregate variance rises before the historical collapse under the specified detrending/window choice. | `Output/diagnostics/ews_claim_control.md`; `Output/diagnostics/ews_synthesis.md` | observed core9 variance tau `+0.602`, p `0.004`, power `92%` | Do not claim tipping-point proof; latent and observed layers differ. |
| Hysteresis / reversibility | Non-retracing driver-state patterns are consistent with hysteresis but do not adjudicate hysteresis versus slow transient or composite-driver residuals. | `Output/diagnostics/reversibility_synthesis.md`; `Output/diagnostics/reversibility_claim_control.md` | claim-control status is mechanism-indeterminate | Do not say a fold bifurcation or alternative stable state is proven. |
| Coastwide transfer | `m3_bc_marginal` is the current statistically usable coastwide transfer/generality sensitivity. | `Output/diagnostics/bc_marginal_repair_readout.md`; `Output/diagnostics/bc_coastwide_model_status_table.md`; `Output/diagnostics/manuscript_model_evidence_table.md` | max Rhat `1.001`; min E-BFMI `0.980`; max Pareto-k `0.381`; elpd `+134.2` versus `m1_bc_marginal` with SE `19.0`; coastwide RMSE `0.333` versus `0.405` | Do not call it a new biological mechanism or a replacement for the promoted HG baseline. |
| Coastwide pre-roe catch | Public CSAS assessment catch tables for 1951-2017 have been acquired, parsed, and run as a stock-area catch-pressure sensitivity. | `Data/processed/bc_catch_csas_appendix.csv`; `Data/processed/bc_pre_roe_catch_assessment_tables.csv`; `Data/processed/bc_catch_pressure_stock_area_year.csv`; `Output/diagnostics/bc_catch_csas_concordance.md`; `Output/diagnostics/bc_catch_pressure_for_stan.md`; `Output/diagnostics/bc_catch_pressure_model_readout.md` | 1,407 Appendix rows; HG 1956 Gear1 catch `77,461` t; pre-roe totals led by SoG `876,353` t and PRD `433,598` t; catch-pressure matrix `8 x 75`; `m1` catch delta elpd `-5.53`, delta RMSE `+0.0013`; `m3` catch delta elpd `-2.85`, delta RMSE `-0.0017`; both catch branches have all 4 chains E-BFMI `<0.3` | Do not imply the completed original `m1_bc`/`m3_bc` fits used pre-1972 assessment-table catch. Do not use the catch-pressure branches as causal fishing-effect evidence; current result is negative sensitivity only. |
| Spatial management design | Portfolio-preserving spatial design should be simulated from posterior states, not inferred from predator coefficients. | `Output/diagnostics/m1_stier_11_portfolio_metrics.md`; `Output/diagnostics/bc_portfolio_metrics.md`; future portfolio simulations | current all-11 effective sections `3.26` | Next analysis product is scenario simulation, not another predator Stan branch. |
| Ecosystem-service valuation | The service tip is not only a dollar loss; it is a loss of options, access, cultural reliability, and spatial redundancy. | `analysis/03_bioeconomics/docs/2026-05-19-herring-economics-detailed-brief.md`; `docs/statistical_model_inventory.tsv` | valuation backbone imports `m1_stier_11` biology | Do not let landed value be the sole metric for service loss. |

## Missing Or Blocked Pieces

- A real bottom-up energy model still needs in-situ zooplankton biomass,
  community composition, prey quality, or a trusted lower-trophic model product.
- A predator promotion path still needs section-year exposure, especially
  humpbacks, that survives detrending, section controls, and future-lag negative
  controls.
- A full Doherty-style HG catch-at-age predator-removal model remains blocked by
  exact age/weight/length inputs, effective sample-size metadata, and predator
  selectivity assumptions.

## Maintenance Rule

Every headline number in the manuscript should point to this file, the
statistical model inventory, or a generated diagnostic listed here. If a claim
does not fit an allowed wording row, add a row before using it.
