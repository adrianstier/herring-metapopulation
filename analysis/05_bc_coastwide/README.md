# `analysis/05_bc_coastwide/` — BC-coastwide hierarchical metapopulation

Extension of the section-level M1 herring metapopulation analysis from Haida Gwaii (11 sections) to all 8 DFO stock-area codes across British Columbia (~100 sections). Fits hierarchical M1 (baseline), M3 (Gompertz density-dependence), M5 (predator-mediated), catch-pressure sensitivities using public CSAS Appendix B assessment catch tables, and marginalized M1/M3 geometry-repair candidates.

## Layout

```
05_bc_coastwide/
├── scripts/
│   ├── 00_data_acquisition.R         download Open Data catch + refresh spawn
│   ├── 01_assemble_bc_spawn.R        filter 31k-row CSV → tidy panel
│   ├── 02_assemble_bc_catch.R        Open Data section-level roe catch
│   ├── 02b_csas_appendix_crosscheck.R CSAS 2018 Appendix B catch tables
│   ├── 03_assemble_bc_predator_covs.R pull from sibling repo
│   ├── 04_assemble_distance_matrix.R within-stock-area distance matrices
│   ├── 05_prepare_stan_data.R        Stan data list
│   ├── 06_fit_m1_bc.R                cloud — M1 baseline
│   ├── 06b_fit_m1_bc_catch_pressure.R cloud — M1 + lagged catch pressure
│   ├── 06d_fit_m1_bc_marginal.R      cloud — marginalized M1 repair
│   ├── 07_fit_m3_bc.R                cloud — M3
│   ├── 07b_fit_m3_bc_catch_pressure.R cloud — M3 + lagged catch pressure
│   ├── 07d_fit_m3_bc_marginal.R      cloud — marginalized M3 repair
│   ├── 08_fit_m5_bc.R                cloud — M5
│   ├── 09_diagnostics.R              MCMC + PPC
│   ├── 09c_marginal_repair_readout.R focused marginalized repair comparison
│   ├── 10_comparative_areas.R        HG vs SoG vs WCVI
│   ├── 11_bc_portfolio.R             coastwide portfolio metrics
│   ├── 12_manuscript_figures.R       5 figures + tables
│   ├── 13_fit_bc_kfold.R             robust CV refit for high Pareto-k
│   └── 14_collect_bc_kfold.R         collect robust CV outputs
├── stan/                             BC Stan models (separate from inst/stan/)
├── output/                           gitignored posterior artifacts
└── docs/                             cross-refs to spec + plan
```

## Specs and plans

- Design spec: [`docs/superpowers/specs/2026-05-21-bc-coastwide-expansion-design.md`](../../docs/superpowers/specs/2026-05-21-bc-coastwide-expansion-design.md)
- Implementation plan: [`docs/superpowers/plans/2026-05-21-bc-coastwide-expansion.md`](../../docs/superpowers/plans/2026-05-21-bc-coastwide-expansion.md)

## Talk firewall

This workstream reads from the core pipeline (`R/`, `Data/`, `Output/`, sibling predator repo) and writes only to `Data/processed/bc_*` (force-tracked manifests) and `analysis/05_bc_coastwide/output/` (gitignored). Does not modify the core M1_stier_11 baseline.

## Outputs (populated as pipeline runs)

| File | Description | Produced by |
|---|---|---|
| `Data/processed/bc_spawn_by_section_year.csv` | Section-year spawn panel (8 stock areas, 1951–2025) | `scripts/01` |
| `Data/raw/dfo-catch/bc_commercial_catch_OPEN_DATA.csv` | Raw DFO Open Data Portal catch | `scripts/00` |
| `Data/processed/bc_catch_by_section_year_gear.csv` | Tidy section-year-gear catch panel | `scripts/02` |
| `Data/processed/bc_catch_csas_appendix.csv` | CSAS 2018/028 Appendix B.1-B.7 stock-area catch, 1951-2017 | `scripts/02b` |
| `Data/processed/bc_pre_roe_catch_assessment_tables.csv` | Pre-roe subset of CSAS Appendix catch, 1951-1971 | `scripts/02b` |
| `Data/raw/dfo-catch/csas-2018-028/csas_2018_028_Table_B_*_raw_excerpt.txt` | Raw text excerpts for Appendix B.1-B.7 | `scripts/02b` |
| `Output/diagnostics/bc_catch_csas_concordance.md` | CSAS extraction checks + Open Data diagnostic concordance | `scripts/02b` |
| `Output/diagnostics/bc_catch_csas_open_data_concordance.csv` | Gear-level roe-catch overlap diagnostic, 1972-2017 | `scripts/02b` |
| `Data/processed/bc_catch_pressure_stock_area_year.csv` | Stock-area annual catch-pressure covariate for Stan sensitivities | `scripts/05` |
| `Output/diagnostics/bc_catch_pressure_for_stan.md` | Catch-pressure source rule and scaling report | `scripts/05` |
| `Data/processed/bc_predator_covariates.csv` | Year-by-stock-area predator covariates | `scripts/03` |
| `Data/processed/bc_predator_covariates_provenance.md` | Per-species spatial-resolution notes | `scripts/03` |
| `Data/processed/bc_distance_within_stock_area.rds` | Within-area distance matrices | `scripts/04` |
| `Data/processed/bc_fishery_events.csv` | Anchor years for closures per stock area | committed seed |
| `Data/processed/bc_stan_data.rds` | Stan data list for M1/M3/M5 and catch-pressure sensitivities | `scripts/05` |
| `analysis/05_bc_coastwide/output/m{1,3,5}_bc_fit.rds` | Production fits (cloud) | `scripts/06`–`08` |
| `analysis/05_bc_coastwide/output/m{1,3}_bc_geom_fit.rds` | Conservative geometry-repair candidate fits | `scripts/06c`, `scripts/07c` |
| `analysis/05_bc_coastwide/output/m{1,3}_bc_marginal_fit.rds` | Marginalized state-space geometry-repair candidate fits | `scripts/06d`, `scripts/07d` |
| `analysis/05_bc_coastwide/output/m{1,3}_bc_catch_pressure_fit.rds` | Production catch-pressure sensitivity fits | `scripts/06b`, `scripts/07b` |
| `analysis/05_bc_coastwide/output/m1_bc_subset_HG_WCVI_fit.rds` | Integration-test subset fit | `scripts/06` |
| `Output/diagnostics/bc_coastwide_mcmc_diagnostics.md` | R̂ / ESS / divergent transitions | `scripts/09` |
| `Output/diagnostics/bc_coastwide_loo_table.csv` | Positive-observation PSIS-LOO across M1/M3/M5 | `scripts/09` |
| `Output/diagnostics/bc_coastwide_high_pareto_points.csv` | Positive-observation cells with Pareto k > 0.7 | `scripts/09` |
| `Output/diagnostics/bc_coastwide_positive_spawn_calibration.csv` | Positive-spawn RMSE/bias by model, stock area, and period | `scripts/09` |
| `Output/diagnostics/bc_coastwide_model_status_table.{csv,md}` | Coastwide branch status and claim gate | `scripts/09` |
| `Output/diagnostics/bc_catch_pressure_model_readout.{csv,md}` | Claim-gated readout for CSAS catch-pressure branches | `scripts/09b` |
| `Output/diagnostics/bc_marginal_repair_readout.{csv,md}` | Claim-gated readout for marginalized state-space repair branches | `scripts/09c` |
| `Output/diagnostics/bc_comparative_areas.{csv,md}` | Recovery curves per stock area | `scripts/10` |
| `Output/diagnostics/bc_portfolio_metrics.{csv,md}` | Synchrony / CV-ratio / occupancy | `scripts/11` |
| `Output/figures/bc_coastwide_fig{1..5}.{pdf,png}` | 5 manuscript figures | `scripts/12` |
| `Output/figures/legends/bc_coastwide_fig{1..5}_legend.md` | Companion legends | `scripts/12` |
| `Output/diagnostics/bc_coastwide_kfold_summary.{csv,md}` | Robust K-fold comparison for `m1_bc` versus `m3_bc` | `scripts/14` |

## Running the pipeline

```bash
# Phase 1: data acquisition (local)
Rscript analysis/05_bc_coastwide/scripts/00_data_acquisition.R
Rscript analysis/05_bc_coastwide/scripts/01_assemble_bc_spawn.R
Rscript analysis/05_bc_coastwide/scripts/02_assemble_bc_catch.R
Rscript analysis/05_bc_coastwide/scripts/02b_csas_appendix_crosscheck.R

# Phase 2: covariates + distance + Stan data (local)
Rscript analysis/05_bc_coastwide/scripts/03_assemble_bc_predator_covs.R
Rscript analysis/05_bc_coastwide/scripts/04_assemble_distance_matrix.R
Rscript analysis/05_bc_coastwide/scripts/05_prepare_stan_data.R

# Phase 3: integration-test subset locally (smoke)
HERRING_SMOKE=1 SUBSET=HG_WCVI Rscript analysis/05_bc_coastwide/scripts/06_fit_m1_bc.R
HERRING_SMOKE=1 SUBSET=HG_WCVI Rscript analysis/05_bc_coastwide/scripts/06b_fit_m1_bc_catch_pressure.R
HERRING_SMOKE=1 SUBSET=HG_WCVI Rscript analysis/05_bc_coastwide/scripts/07b_fit_m3_bc_catch_pressure.R
Rscript -e 'testthat::test_file("tests/testthat/test-bc-coastwide.R", reporter = "minimal")'

# Phase 4: full BC production fits on UCSB GRIT
bash hpc/submit_grit_bc_deps.sh
bash hpc/submit_grit_bc_coastwide.sh all

# Optional Phase 4b: full catch-pressure sensitivities on UCSB GRIT
bash hpc/submit_grit_bc_coastwide.sh catch

# Optional Phase 4c: conservative geometry-repair candidates
bash hpc/submit_grit_bc_coastwide.sh geom

# Optional Phase 4d: marginalized state-space geometry-repair candidates
bash hpc/submit_grit_bc_coastwide.sh marginal

# Phase 5: pull fits + post-fit analysis (local, after GRIT completes)
bash hpc/pull_grit_bc_coastwide_results.sh
Rscript analysis/05_bc_coastwide/scripts/09_diagnostics.R
Rscript analysis/05_bc_coastwide/scripts/09b_catch_pressure_readout.R
Rscript analysis/05_bc_coastwide/scripts/09c_marginal_repair_readout.R
Rscript analysis/05_bc_coastwide/scripts/10_comparative_areas.R
Rscript analysis/05_bc_coastwide/scripts/11_bc_portfolio.R
Rscript analysis/05_bc_coastwide/scripts/12_manuscript_figures.R

# Phase 6: robust comparison if PSIS-LOO has high Pareto-k cells
bash hpc/submit_grit_bc_kfold.sh 5
bash hpc/pull_grit_bc_kfold_results.sh

# Optional: resubmit one failed fold without duplicating the whole CV grid
bash hpc/submit_grit_bc_kfold.sh 5 m1_bc 1
```

AWS Batch remains a fallback if GRIT is unavailable or backlogged, but the
default production path for `m1_bc`, `m3_bc`, and `m5_bc` is now
`hpc/submit_grit_bc_coastwide.sh`.

The full-fit and K-fold Slurm wrappers check for required R packages but do not
install or compile packages inside model jobs. As of 2026-08-28 they use a
scratch-backed, version-matched user R library, ignore inherited
`R_LIBS_USER`/site-library contamination, put run directories on
`/home/hpc-scratch/$USER`, and exclude `hpc-13.grit.ucsb.edu`, which had a
node-specific RStan/library mismatch during the fold-1 recovery. If the package
gate fails, run `hpc/submit_grit_bc_deps.sh` to repair the GRIT user library
before resubmitting science fits. The GRIT transfer helpers use `rsync -e ssh`
instead of `scp`, which failed on the home-backed staging path after the
2026-08-28 quota cleanup. Before launching several production jobs at once,
clear old remote duplicates from `/home/astier/herring-bc-stage/results/` or
stage full-fit objects somewhere with more backed-up space.

2026-09-11 GRIT rerun checkpoint: dependency preflight job `1092201`
completed successfully in `00:20:36` after using the scratch-backed R library
at `/home/hpc-scratch/astier/herring-bc-r-cache`. The repaired full-fit
wrapper then ran `m1_bc` job `1092235` on `hpc-08.grit.ucsb.edu`, `m3_bc` job
`1092237` on `hpc-09.grit.ucsb.edu`, and `m5_bc` job `1092239` on
`hpc-07.grit.ucsb.edu`; all three completed with Slurm exit code `0`. Results
were pulled with `hpc/pull_grit_bc_coastwide_results.sh` and downstream
readouts were refreshed with scripts `09` through `12`. The pull copied fresh
full-fit `m1_bc`, `m3_bc`, and `m5_bc` artifacts; the catch-pressure fit
objects were not present in the GRIT rerun result directory, so the current
catch-pressure readout still uses the earlier Aug 10 catch-pressure fits
contrasted against the refreshed M1/M3 full fits.
After local verification, the duplicate full-fit `.rds` objects were pruned
from `/home/astier/herring-bc-stage/results/`, reducing the remote result
directory from 7.3 GB to 1.2 MB while preserving session summaries and K-fold
material.

## Current model-use gate

As of the 2026-09-11 full-fit refresh, `m3_bc` still has the best coastwide
positive-spawn calibration (`0.317` versus `0.400` log10 RMSE for `m1_bc`) and
higher full-fit PSIS elpd than `m1_bc`, but all coastwide branches fail the
sampler/LOO gate. Robust 5-fold CV completed earlier and was positive but
uncertain for `m3_bc` (`+24.9` elpd, approximate SE `92.3`; held-out RMSE
`0.621` versus `0.626` log10). Treat `m3_bc` as a coastwide
candidate/sensitivity, not a promoted extension. `m5_bc` failed badly
(max Rhat `14.85`, min ESS `2.0`, `10,000` treedepth hits) and must not be
used as predator-effect evidence.
The immediate repair path tested `m1_bc_geom` and `m3_bc_geom`: conservative
state-space variants that keep centered latent states but remove the unused
range parameter, simplify the initial-state hierarchy, and tighten scale priors.
A fully non-centered smoke was tested locally and failed the treedepth gate, so
it was not retained as an active branch. The retained `geom` branches compiled
and removed divergence/treedepth pressure in HG+WCVI subset smokes, but both
still failed the E-BFMI gate (`Output/diagnostics/bc_geometry_repair_smoke.md`).
Do not submit full GRIT `geom` fits until another parameterization change or
pilot gate clears E-BFMI.
The stronger repair path is now `m1_bc_marginal` and `m3_bc_marginal`, which
integrate over the latent section-year states with a Kalman filter and use FFBS
in generated quantities for downstream `z` summaries. Local HG+WCVI and
all-area pilots pass the hard HMC geometry gate: zero divergences, zero
max-treedepth hits, and every chain E-BFMI > `0.3`
(`Output/diagnostics/bc_marginal_repair_smoke.md`). Full GRIT production fits
completed on 2026-09-11: `m1_bc_marginal` job `1102352` completed in
`00:08:57`, and `m3_bc_marginal` job `1102355` completed in `00:15:08`. Both
production fits pass the sampler gate and PSIS-LOO gate: Rhat near `1.00`, no
divergences, no max-treedepth hits, E-BFMI near `1`, and zero Pareto-k cells
above `0.7`. Within the marginalized repair family, `m3_bc_marginal` is better
than `m1_bc_marginal` by elpd `+134.2` with SE `19.0`, and by positive-spawn
calibration (`0.333` versus `0.405` log10 RMSE). Treat `m3_bc_marginal` as the
current statistically usable coastwide sensitivity. It is still a sampler/LOO
repair of the coastwide comparison, not a new biological mechanism.
As of the 2026-08-10 GRIT run, both catch-pressure branches completed
(`m1_bc_catch_pressure` job `1074404`, `m3_bc_catch_pressure` job `1074406`),
but both fail the E-BFMI sampler gate and are sensitivity-only. They use
stock-area annual pressure lagged into next-year growth; they do not allocate
historical reduction/other catch to sections. The practical readout is in
`Output/diagnostics/bc_catch_pressure_model_readout.md`: catch pressure leaves
the M1/M3 inference essentially unchanged.
