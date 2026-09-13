# Deposit Cleanup And Comprehensive Analysis Plan

Generated: 2026-07-31

Last manual update: 2026-09-11

Purpose: define what belongs in a clean analysis deposit, what was removed as
live-coding debris, and what still has to happen before the project is a
comprehensive, reviewer-ready analysis rather than a strong but still evolving
modeling workspace.

## Current Cleanup State

At the 2026-07-31 cleanup pass, the repository had a clean git working tree
apart from the cleanup edits. As of 2026-08-25, the working tree contains
active coastwide/GRIT analysis additions and should not be treated as a clean
deposit until those source changes are reviewed and committed or excluded. The
active organization is:

- core modeling pipeline: `R/`, `Code/`, `Code/probes/`, `inst/stan/`,
  `_targets.R`, `tests/`;
- derivative workstreams: `analysis/00_core_model/`, `analysis/01_ews/`,
  `analysis/02_resilience/`, `analysis/03_bioeconomics/`,
  `analysis/05_bc_coastwide/`;
- talk-only workspace: `analysis/04_talks/2026-royalsociety/`, firewalled from
  the model pipeline;
- cold storage: `_archive/` and `Code/archive/`;
- generated outputs and model fits: `Output/`, `Data/processed/`, and cloud
  products, mostly gitignored.

Removed from the local working tree on 2026-07-31:

- `.superpowers/` brainstorming server artifacts;
- `.worktrees/` local development worktree scaffold;
- `logs/`;
- `cloud/logs/`;
- talk deck runtime dependencies: `analysis/04_talks/2026-royalsociety/Talk_Materials/deck_build/node_modules/`;
- talk deck local photo imports: `analysis/04_talks/2026-royalsociety/Talk_Materials/deck_build/photos/`;
- Python `__pycache__/` directories and scratch QA JPGs.

These removals do not delete tracked source, model code, data provenance, or
published-analysis artifacts. They remove runtime/cache/live-coding material
that should not be part of a clean deposit.

## Deposit Boundary

For a paper/reviewer/archive deposit, include:

- `README.md`, `REPO_STRUCTURE.md`, `AGENTS.md`, `CLAUDE.md` only if the
  recipient needs agent/project state;
- `_targets.R`, `R/`, `Code/00_*.R` through `Code/06*.R`, `Code/probes/` needed
  to regenerate the promoted diagnostics, `inst/stan/`, and `tests/`;
- `Data/raw/` files that are legally shareable and needed for reproduction;
- source/provenance docs in `docs/`, especially
  `docs/data-dictionary.md`, `docs/stan-model-map.md`,
  `docs/talk-model-claim-control-sheet.md`,
  `docs/herring-non-recovery-hypotheses.md`, predator/Doherty source maps, and
  this file;
- small generated diagnostic tables that are intentionally force-tracked or
  required as examples.

Exclude from a clean paper deposit unless there is a specific reason:

- `analysis/04_talks/2026-royalsociety/` and any presentation decks, videos,
  attendee dossiers, trip dossiers, or build assets;
- `_archive/` and `Code/archive/` except for a small provenance index if needed;
- `Output/` model fits, posterior samples, generated figures, and logs;
- `Data/processed/*.rds`, smoke fits, exact re-LOO fits, and other large
  regenerable products;
- `cloud/logs/`, AWS job status, EC2 scratch, and local SSO/runtime files;
- local sibling repo checkouts or absolute-path-only resources.

The talk workspace should remain in this working repo for context, but it is
not part of the analysis deposit. A release/archive step should either exclude
it explicitly or build a clean source bundle from the deposit boundary above.

## Comprehensive Analysis Status

### 1. Promoted Baseline

Status: strong; saved-fit reproduction runner added, with explicit opt-in
local full-refit mode.

`m1_stier_11` remains the promoted practical baseline: ambiguous zeros, all 11
sections fit, two-era survey catchability, exact re-LOO resolved the one high
Pareto-k point, and no held branch has improved calibration enough to replace
it.

Completed hardening:

- `run_promoted_analysis.R --mode=minimal` regenerates the core promoted
  `m1_stier_11` fit-quality, portfolio, 9-focal, and positive-spawn caveat
  outputs from saved fit artifacts without refitting Stan.
- `run_promoted_analysis.R --mode=ledgers` runs the same saved-fit refresh and
  then refreshes the model-branch status and decision ledgers.
- `run_promoted_analysis.R --mode=refit` is the explicit local full-refit path:
  it runs `Code/03_fit_m1_stier_11.R` and then refreshes the promoted
  diagnostics/ledgers. This is slow and should not be the reviewer default when
  saved artifacts are restored.
- every non-dry run writes
  `Output/diagnostics/promoted_analysis_sessionInfo.txt`.

Remaining work:

- do not treat `_targets.R` as the promoted manuscript-driver entrypoint until
  it is rebuilt around `m1_stier_11`; for now, use `run_promoted_analysis.R`;
- add a GRIT/AWS full-refit wrapper only if reviewers need a cloud-native
  promoted-baseline refit rather than local `--mode=refit`;
- keep the README runtime note current: saved-fit reuse is the standard
  reviewer refresh, while local/cloud refits are deliberate long-running jobs.

### 2. Claim Concordance

Status: reviewer-control layer added on 2026-08-04; still needs manuscript
sentence-by-sentence use during writing.

The repo has strong guardrails (`model_decision_ledger`,
`talk-model-claim-control-sheet`, promoted-baseline evidence packages), but it
now also has a manuscript-grade concordance table and statistical-model
inventory:

- `docs/CONCORDANCE_AUDIT.md`;
- `docs/statistical_model_inventory.md`;
- `docs/statistical_model_inventory.tsv`;
- `tools/check_model_inventory.py`;
- `Output/diagnostics/statistical_model_inventory_check.csv`.

Remaining work:

- table every headline number: biomass, occupied sections, synchrony, Simpson
  effective sections, section recovery ratios, fishing pressure, PDO screen,
  predator screens, heatwave/bloom screens, and DFO comparison values;
- during manuscript drafting, ensure every sentence that uses those numbers
  points to the concordance row or adds a row;
- flag any manuscript/talk sentence that implies causality from a screen.

### 3. Data Provenance

Status: usable, with a first deposit-facing manifest; not archive-complete.

Raw DFO spawn/catch/environmental/predator products have substantial provenance
documentation. Processed files are intentionally regenerable. The predator and
Doherty bridges correctly record missing machine-readable inputs.

Completed hardening:

- `tools/build_data_manifest.R` writes `docs/data_manifest.tsv` and
  `docs/data_manifest.md`, covering `Data/raw/` plus selected maintained
  `Data/processed/` products with checksums and conservative access labels.

Remaining work:

- refresh the manifest immediately before deposit and review every
  `legacy_local_review_required`, `project_derived_review_required`, and
  `request_or_permission_required` row;
- decide whether large raw files such as predator ZIPs and PDF assessment
  extracts belong in the repository archive, Drive, or a data repository;
- keep DFO/Hakai/BioChem plankton and exact HG biological inputs as
  `data_blocked` until machine-readable extracts arrive.

### 4. Model Branch Completeness

Status: comprehensive enough for the current biomass/portfolio story; not
comprehensive for every mechanism.

Completed/held branches cover observation structure, site growth, distance
covariance, predator pressure/demand, Doherty-style proxy screens, timing and
substrate screens, density-dependence screens, and bottom-up heatwave/bloom
screens.

Remaining science gates:

- do not promote predator causality without a section-year exposure product
  that survives detrending, section controls, and future-lag negative controls;
- do not promote heatwave/Blob causality unless a pulse/step or bottom-up
  mediator adds explanatory power beyond PDO, fishing history, and pre-existing
  portfolio erosion;
- do not fit a full catch-at-age/Doherty-style branch until exact HG
  age/weight/length inputs, effective sample sizes, and predator selectivity
  assumptions are acquired and audited;
- do not treat bottom-up energy as solved until in-situ zooplankton biomass,
  prey quality, or a defensible lower-trophic model product is linked.

### 4b. BC Coastwide Extension

Status: repaired GRIT full-fit round, local pull, and post-fit readout complete
as of 2026-09-11. M3 remains the strongest current coastwide candidate by
full-fit calibration, but K-fold does not promote it as a clear predictive
winner over M1 and all current full coastwide branches fail the sampler/LOO
gate. M1 remains baseline context, and M5 is failed as a predator branch.

Work completed on 2026-07-31:

- updated `analysis/05_bc_coastwide/scripts/00_data_acquisition.R` to resolve
  the Open Canada `Herring Roe Fishery Catch Data` package
  (`71c25df1-0577-43f7-b9f8-95cc321e7cbc`) and combine the eight stock-area CSV
  resources;
- updated catch parsing to handle bilingual/encoding-shifted DFO headers and
  map public stock-area names to model codes (`HG`, `PRD`, `CC`, `SoG`,
  `WCVI`, `A27`, `A2W`, `NA`);
- updated predator covariate assembly to use the current sibling-repo mammal
  files under `/Users/adrianstier/pacific-herring-predators/data/processed/mammals/`;
- fixed the `NA` stock-area-code convention so it is not parsed as missing in
  coastwide Stan data;
- generated `Data/processed/bc_stan_data.rds` with 101 sections, 75 years,
  8 stock areas, and 3,697 positive spawn observations;
- added GRIT submission helpers in `hpc/` and submitted full `SUBSET=ALL`
  jobs:
  `m1_bc` = GRIT job 1067628, `m3_bc` = 1067630, `m5_bc` = 1067632;
- pulled the completed GRIT fit artifacts to
  `analysis/05_bc_coastwide/output/` on 2026-08-03;
- fixed the harmless Slurm logging bug that caused those completed runs to
  exit with Slurm state `FAILED` after copying the fit files;
- ran `09_diagnostics.R`, `10_comparative_areas.R`, `11_bc_portfolio.R`, and
  `12_manuscript_figures.R`;
- rendered `Output/figures/bc_coastwide_fig1` through `fig5` as PDF/PNG with
  companion legends.

Current fit readout after the 2026-09-11 pull:

| Model | GRIT job | Runtime | LOO elpd | Sampler read |
|---|---:|---:|---:|---|
| `m1_bc` | 1092235 | 00:42:15 | -6360.16 | sampler gate failed: max Rhat 1.027, min ESS 205, all four chains low E-BFMI |
| `m3_bc` | 1092237 | 00:31:01 | -6282.69 | calibration-supported sensitivity, but sampler gate failed: max Rhat 1.020, min ESS 146, all four chains low E-BFMI |
| `m5_bc` | 1092239 | 08:31:42 | -9697.67 | failed: max Rhat 14.85, min ESS 2.0, 10,000 max-treedepth hits |

Interpretation: the coastwide density-dependent branch (`m3_bc`) improves
full-fit calibration and positive-observation PSIS elpd over the M1 coastwide
baseline, but PSIS is not reliable enough for promotion because high Pareto-k
cells are widespread and the full fits fail the sampler gate. The predator
branch (`m5_bc`) is not interpretable as evidence for predator effects in this
round; use it only as a negative geometry/calibration result.

2026-08-04 post-fit gate update:

- `analysis/05_bc_coastwide/scripts/09_diagnostics.R` now filters LOO to
  positive observations, records Pareto-k counts, writes positive-spawn
  calibration by model/stock area/period, and writes
  `Output/diagnostics/bc_coastwide_model_status_table.{csv,md}`;
- `m3_bc` has better coastwide positive-spawn calibration than `m1_bc`
  (`0.316` versus `0.399` log10 RMSE), but PSIS-LOO is not promotion-grade
  because high Pareto-k cells are diffuse (`m3_bc`: `493` cells > `0.7`,
  `43` cells > `1`; `m1_bc`: `200` cells > `0.7`, `20` cells > `1`);
- exact re-LOO is not a sensible path for hundreds of cells, so a 5-fold robust
  CV for `m1_bc` and `m3_bc` was submitted to GRIT and completed:
  `m1_bc` jobs `1069811`, `1069775`, `1069777`, `1069779`, `1069781`; `m3_bc`
  jobs `1069783`, `1069785`, `1069787`, `1069789`, `1069791`;
- original `m1_bc` fold-1 jobs `1069773`, `1069798`, and `1069806` failed
  during package/library setup on GRIT, including two failures on
  `hpc-13.grit.ucsb.edu`; completed replacement job `1069811` excludes `hpc-13`.
  These are wrapper/node setup failures, not failed biological model fits;
- robust K-fold outputs are in `Output/diagnostics/bc_coastwide_kfold_summary.md`:
  all folds completed, sampler diagnostics were acceptable, `m3_bc` elpd was
  `24.9` higher than `m1_bc` with approximate SE `92.3`, and held-out RMSE was
  `0.621` versus `0.626` log10 units. This is positive but uncertain, so
  `m3_bc` remains a calibration-supported candidate rather than a promoted
  coastwide extension;
- `analysis/05_bc_coastwide/scripts/10_comparative_areas.R`,
  `11_bc_portfolio.R`, and `12_manuscript_figures.R` now default to
  `BC_MODEL_ID=m3_bc`;
- `12_manuscript_figures.R` no longer creates a predator driver-decomposition
  figure from failed `m5_bc`; Figure 5 is now a model-comparison/status gate.

2026-08-04 catch-table acquisition update:

- `analysis/05_bc_coastwide/scripts/02b_csas_appendix_crosscheck.R` now extracts
  DFO CSAS Research Document 2018/028 Appendix B.1-B.7 catch tables for HG,
  PRD, CC, SoG, WCVI, A27, and A2W;
- generated `Data/processed/bc_catch_csas_appendix.csv` with 1,407 rows
  (7 stock areas x 67 years x 3 gears), `Data/processed/bc_pre_roe_catch_assessment_tables.csv`
  for 1951-1971, raw table excerpts under
  `Data/raw/dfo-catch/csas-2018-028/`, and
  `Output/diagnostics/bc_catch_csas_concordance.md`;
- the extraction checks preserve source document, source table, source URL,
  extraction method, extraction notes, and model-use status. HG 1956 Gear1
  catch is 77,461 t, matching the expected historical record-scale check.
- `analysis/05_bc_coastwide/scripts/05_prepare_stan_data.R` now creates
  `Data/processed/bc_catch_pressure_stock_area_year.csv` and adds
  `catch_pressure` plus `catch_tonnes_area_year` to `bc_stan_data.rds`;
- new sensitivity branches
  `analysis/05_bc_coastwide/scripts/06b_fit_m1_bc_catch_pressure.R` and
  `analysis/05_bc_coastwide/scripts/07b_fit_m3_bc_catch_pressure.R` use
  stock-area catch pressure lagged into next-year latent growth. They do not
  distribute historical Gear1 catch to sections;
- local HG+WCVI smoke fits completed for both catch-pressure branches on
  2026-08-04. Full GRIT fits were submitted on 2026-08-10:
  `m1_bc_catch_pressure` job `1074404` on `hpc-09.grit.ucsb.edu` and
  `m3_bc_catch_pressure` job `1074406` on `hpc-17.grit.ucsb.edu`;
- both catch-pressure jobs completed with Slurm exit code `0`; outputs were
  pulled to `analysis/05_bc_coastwide/output/` and diagnostics were refreshed;
- `Output/diagnostics/bc_catch_pressure_model_readout.md` is the claim-gated
  readout. After the 2026-09-11 full-fit refresh, catch pressure does not
  materially improve the non-catch branches: `m1_bc_catch_pressure - m1_bc`
  has delta elpd `-1.70` and delta RMSE `+0.0009` log10;
  `m3_bc_catch_pressure - m3_bc` has delta elpd `+1.62` and delta RMSE
  `-0.0022` log10. Both catch-pressure branches fail the E-BFMI sampler gate,
  with all four chains below `0.3`.

Remaining work:

- do not promote the current catch-pressure branches or use them as causal
  fishing-effect evidence;
- if catch pressure becomes central, reparameterize/repair geometry first and
  then rerun robust CV rather than interpreting the current low-E-BFMI fits;
- for the current manuscript/talk, report the catch-table result as a negative
  sensitivity: public assessment catch tables do not rescue or overturn the
  coastwide M1/M3 inference.

2026-09-11 GRIT rerun checkpoint:

- dependency preflight job `1092201` completed successfully in `00:20:36` using
  the scratch-backed R package cache at
  `/home/hpc-scratch/astier/herring-bc-r-cache`;
- full `SUBSET=ALL` coastwide rerun jobs completed with Slurm exit code `0`:
  `m1_bc` job `1092235` on `hpc-08.grit.ucsb.edu`, `m3_bc` job `1092237` on
  `hpc-09.grit.ucsb.edu`, and `m5_bc` job `1092239` on
  `hpc-07.grit.ucsb.edu`;
- results were pulled with `hpc/pull_grit_bc_coastwide_results.sh`; `m1_bc`,
  `m3_bc`, and `m5_bc` fit artifacts were refreshed locally, while the
  catch-pressure fit artifacts were not present in the rerun result directory
  and remain the earlier Aug 10 sensitivity fits;
- local post-fit scripts `09_diagnostics.R`, `09b_catch_pressure_readout.R`,
  `10_comparative_areas.R`, `11_bc_portfolio.R`, and
  `12_manuscript_figures.R` completed on 2026-09-11.
- after local verification, duplicate full-fit `.rds` objects were removed
  from `/home/astier/herring-bc-stage/results/`, reducing the remote result
  directory from 7.3 GB to 1.2 MB while preserving session summaries and K-fold
  material.

2026-09-11 geometry-repair update:

- tested a fully non-centered M1 smoke locally; it compiled and ran but failed
  the treedepth gate, so the non-centered branch was not retained as an active
  model path;
- added conservative geometry-repair candidate branches `m1_bc_geom` and
  `m3_bc_geom` with Stan files
  `analysis/05_bc_coastwide/stan/herring_metapop_bc_m1_geom.stan` and
  `analysis/05_bc_coastwide/stan/herring_metapop_bc_m3_geom.stan`;
- added fit scripts `analysis/05_bc_coastwide/scripts/06c_fit_m1_bc_geom.R`
  and `analysis/05_bc_coastwide/scripts/07c_fit_m3_bc_geom.R`, plus GRIT
  wrapper support via `hpc/submit_grit_bc_coastwide.sh geom`;
- these branches keep centered latent states, remove the unused range parameter,
  simplify the initial-state hierarchy, and tighten scale priors;
- local HG+WCVI subset smokes compiled and removed divergence/treedepth
  pressure, but both retained `geom` branches still failed the E-BFMI gate
  (`m1_bc_geom` min E-BFMI `0.119`, `m3_bc_geom` min E-BFMI `0.199`), so do
  not submit full GRIT `geom` fits without another parameterization change or
  clearer pilot gate.

2026-09-11 stronger marginal-state repair update:

- added marginalized state-space repair branches `m1_bc_marginal` and
  `m3_bc_marginal`, with Stan files
  `analysis/05_bc_coastwide/stan/herring_metapop_bc_m1_marginal.stan` and
  `analysis/05_bc_coastwide/stan/herring_metapop_bc_m3_marginal.stan`;
- these branches integrate over section-year latent states using a Kalman
  filter rather than sampling every `z[s, t]`; generated quantities use
  forward-filtering backward-sampling so downstream calibration/portfolio code
  can still extract latent `z` draws;
- local HG+WCVI subset and all-area pilots passed the hard HMC geometry gate:
  zero divergences, zero max-treedepth hits, and every chain E-BFMI > `0.3`.
  The all-area pilot minima were `0.990` for `m1_bc_marginal` and `0.966` for
  `m3_bc_marginal`;
- all-area pilots are saved with explicit `_ALL_pilot_` names so
  `09_diagnostics.R` will not mistake them for full production fits;
- GRIT wrapper support was added via
  `bash hpc/submit_grit_bc_coastwide.sh marginal`;
- full GRIT production fits completed on 2026-09-11:
  `m1_bc_marginal` job `1102352` in `00:08:57` and `m3_bc_marginal` job
  `1102355` in `00:15:08`;
- both production fits passed the sampler and PSIS-LOO gates: Rhat near `1.00`,
  no divergences, no max-treedepth hits, E-BFMI near `1`, and zero Pareto-k
  cells above `0.7`;
- within the marginalized repair family, `m3_bc_marginal` beats
  `m1_bc_marginal` by elpd `+134.2` with SE `19.0`, and improves coastwide
  positive-spawn RMSE from `0.405` to `0.333` log10 units;
- this repairs the coastwide sampler/LOO issue. The current read is:
  `m3_bc_marginal` is the statistically usable coastwide sensitivity, but it is
  still a state-space geometry/LOO repair, not a new biological mechanism;
- after local verification, duplicate remote marginal `.rds` fit objects were
  pruned from `/home/astier/herring-bc-stage/results/`, reducing the remote
  result directory to `1.3M` while preserving marginal session-info files.

2026-09-13 manuscript-gate update:

- added `Code/probes/07bx_manuscript_model_evidence_table.R`, which writes the
  cross-analysis claim gate
  `Output/diagnostics/manuscript_model_evidence_table.{csv,md}`;
- added `Code/probes/07by_bottomup_covariate_model_readiness.R`, which writes
  `Output/diagnostics/bottomup_covariate_model_readiness.{csv,md}`;
- current model hierarchy is now explicit: `m1_stier_11` remains the only
  promoted Haida Gwaii baseline; `m3_bc_marginal` is the statistically usable
  coastwide transfer/generality sensitivity; predator, catch-pressure,
  heatwave, and satellite Chl-a products remain held, failed, or context-only;
- the bottom-up decision is also explicit: do not launch a new heatwave, SST,
  or satellite Chl-a Stan branch from the present screens. A real bottom-up
  model is data-blocked by the need for in-situ zooplankton biomass/community
  or prey-quality covariates.

### 5. Reproducibility

Status: navigable but not clone-to-figure complete.

The project has `here()`-based paths, tests, a target graph, model scripts, and
clear docs. It does not yet pass the strict clone-to-figure standard because
large fits and generated diagnostics are local/ignored, root-level environment
locking is incomplete, and the current promoted diagnostic suite is spread
across many `Code/probes/` scripts.

Remaining work:

- add or refresh root `renv.lock` / environment documentation;
- keep `Output/diagnostics/promoted_analysis_sessionInfo.txt` refreshed with
  each promoted-baseline runner execution;
- treat `run_promoted_analysis.R --mode=minimal` as the saved-fit
  reproducibility mode and `--mode=refit` as the explicit full local refit
  mode;
- scratch-clone saved-fit reproduction passed on 2026-08-28 from
  `/private/tmp/herring-minimal-repro-UXKKBM/repo` after applying the staged
  source patch and restoring/linking
  `Data/processed/jags_model_inputs_v2.RData` plus
  `Data/processed/m1_stier_11_fit.rds`;
- keep the coastwide GRIT wrappers in fail-fast mode: as of 2026-08-28 the
  full-fit and K-fold wrappers use a scratch-backed, version-matched user R
  library, ignore inherited site-library contamination, put run directories on
  `/home/hpc-scratch/$USER`, exclude `hpc-13.grit.ucsb.edu`, and fail before
  sampling when required packages are missing; dependency repair is separated
  into `hpc/submit_grit_bc_deps.sh`; the submit/pull helpers use `rsync`
  rather than `scp` because `scp` failed against the home-backed GRIT staging
  path even after old duplicate full-fit objects were removed;
- rerun the scratch-clone test immediately before deposit from the final
  committed source state;
- ensure tests cover the current data schema, zero-treatment contract, and
  model input dimensions.

### 6. Paper-Scope Analysis Gaps

The project is already strong for the central claim:

> Haida Gwaii herring recovery is spatially uneven; biomass alone hides
> portfolio erosion, persistent local depletion, and reduced section diversity.

For a comprehensive paper, the remaining gaps are:

1. Finalize manuscript figures and captions from `m1_stier_11`, with explicit
   11-section versus 9-focal reporting.
2. Consolidate the positive-spawn fit caveat into methods/results language so
   early surface-era magnitudes are not overread.
3. Move `Output/diagnostics/manuscript_model_evidence_table.md` into the
   supplement/manuscript table set, or regenerate it at render time from
   `Code/probes/07bx_manuscript_model_evidence_table.R`.
4. Add an appendix that explains zero treatment and why detection-aware zeros
   are sensitivity analyses, not the baseline.
5. Decide whether EWS, reversibility/hysteresis, and bioeconomics are part of
   this paper, a companion supplement, or separate follow-on analyses.
6. Complete the data request path for DFO biological inputs and DFO/IOS
   zooplankton; do not let those missing data block the portfolio paper unless
   the manuscript makes mechanistic claims about age structure or bottom-up
   prey quality.

## Recommended Next Work Order

1. Use `docs/CONCORDANCE_AUDIT.md` as the manuscript claim ledger and add a
   row for every headline number before it enters prose.
2. Decide how full promoted-baseline refitting should be exposed: update
   `_targets.R`, add a GRIT/AWS-backed refit mode, or document saved-fit reuse
   as the reviewer default.
3. Review `docs/data_manifest.tsv` access labels and decide which
   review-required raw files can enter a public archive.
4. Run root tests and a scratch-clone minimal reproduction.
5. Only after Gates 1-4, package a clean archive excluding talk, cloud logs,
   cold archives, and generated fits.

## Bottom Line

The project is not missing another broad model branch. It is missing a tighter
finish: one-command reproduction of the promoted baseline, claim concordance,
data-manifest cleanup, and a clear boundary between the central portfolio paper
and unresolved mechanism programs such as predators, age structure, and
bottom-up plankton.
