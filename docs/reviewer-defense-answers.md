# Reviewer Defense Answers

Last updated: 2026-09-13

Purpose: compact, claim-gated answers to the recurring questions that should
come up in manuscript review, seminars, or the Royal Society/tipping-points
framing. This document summarizes maintained outputs; it is not a substitute
for the generated diagnostic files named below.

## Current Model Hierarchy

- `m1_stier_11` is the only promoted Haida Gwaii population baseline.
- `m3_bc_marginal` is the current statistically usable coastwide
  transfer/generality sensitivity.
- Predator, catch-pressure, heatwave, satellite Chl-a, and EWS products are
  supporting diagnostics or held sensitivities unless their own gate says
  otherwise.

Primary generated table: `Output/diagnostics/manuscript_model_evidence_table.md`.

## Isn't It Just Predators?

Answer: no current model supports a promoted predator coefficient. Predation is
plausible ecological context, but the present predator products do not clear
the causal/model-readiness gates.

Evidence:

- HG predator branches are held because calibration gains are negligible or
  data products are not cleanly exogenous.
- `m5_bc` fails coastwide sampler diagnostics and cannot support predator
  attribution.
- Prototype exposure products are useful for data design, not mechanism
  attribution.

Allowed wording: "Predation is plausible context and a priority data target,
but no predator coefficient is currently promoted."

Do not say: "Predators explain failed recovery."

Next analysis needed: effort-corrected section-year predator exposure,
especially humpbacks, with future-lag negative controls and section controls.

## Did It Really Not Recover?

Answer: aggregate biomass partly recovered after fishery closure, but the
spatial portfolio did not. The service-relevant result is incomplete and uneven
recovery, not complete collapse.

Evidence:

- Recent biomass is higher than the roe-fishery median, but occupied sections
  and effective section counts remain low.
- Recent biomass is concentrated in a few places; the maintained portfolio
  output reports Simpson effective sections around `3.26`.

Allowed wording: "Closure improved aggregate biomass, but recovery is
spatially concentrated and the portfolio remains eroded."

Do not say: "Nothing recovered anywhere."

Next analysis needed: scenario simulations that ask which section recovery
patterns restore portfolio metrics, not just total biomass.

## Is This Loss Or Spatial Reshuffling?

Answer: both can be true. Some biomass may be redistributed, but a spatial
portfolio service is still degraded when spawning becomes concentrated in fewer
sections or loses local reliability.

Evidence:

- Section-level posterior states and raw location-transition screens show
  persistent depletion in several local places while other sections carry more
  of the recent biomass.
- The portfolio metrics quantify concentration and synchrony rather than only
  total abundance.

Allowed wording: "The biological signal is not simply coastwide loss; it is
portfolio erosion through spatial concentration and uneven local recovery."

Do not say: "Reshuffling means no loss of service."

Next analysis needed: spatial-management portfolio scenarios from posterior
states.

## Is Non-Recovery The Blob Or Bottom-Up Energy?

Answer: the Blob likely added climate stress to an already eroded portfolio,
but current model evidence does not make it the promoted recovery mechanism.
Satellite Chl-a does not show a clean bloom-intensity failure explaining adult
biomass recovery.

Evidence:

- Lag-1 PDO is the strongest maintained climate screen and is already in
  `m1_stier_11`.
- The 2014-2016 MHW pulse has weak adjusted adult-growth signal.
- Satellite bloom phenology rows are `weak_screen_only`.

Allowed wording: "The unresolved bottom-up test is prey quality and secondary
production, not just whether the ocean was warm or whether satellite Chl-a was
low."

Do not say: "The Blob caused the failed recovery."

Next analysis needed: DFO BioChem/IOS or comparable Haida Gwaii/Hecate Strait
zooplankton biomass, community, size, and prey-quality covariates.

## Are The EWS Claims Rigorous?

Answer: use the EWS outputs as diagnostic evidence, not proof of a tipping
point. The claim-safe result is narrower than "we detected a tipping point."

Evidence:

- Current EWS claim-control files separate observed and latent layers.
- Observed aggregate variance has the strongest pre-collapse warning-signal
  support under the specified detrending/window choice.

Allowed wording: "Some warning indicators are consistent with loss of
resilience, but EWS alone does not prove a tipping mechanism."

Do not say: "EWS proves an alternative stable state."

Next analysis needed: keep EWS in the supplement or as supporting evidence
unless tied to a formal pre-registered diagnostic claim.

## Hysteresis Or Slow Transient?

Answer: current reversibility diagnostics are mechanism-indeterminate. They
support a non-retracing social-ecological recovery narrative, but they do not
prove a fold bifurcation or exclude a slow transient.

Allowed wording: "The recovery path is consistent with hysteresis-like
non-reversibility, but model evidence does not uniquely distinguish hysteresis
from slow transient dynamics or composite-driver residuals."

Next analysis needed: explicit driver-state scenarios and counterfactual
posterior simulations.

## Zero And Model Rigor

Answer: zeros remain ambiguous in the promoted baseline because many no-spawn
or no-record cells are not clean absence surveys. Treating them as informative
nondetections is a sensitivity, not the biological default.

Evidence:

- The maintained survey-coverage output separates positive, zero-record, and
  missing/unsurveyed cells.
- Detection-aware legacy branches have different likelihood units and should
  not be compared directly by raw LOOIC with positive-only models.

Allowed wording: "The promoted model avoids forcing no-survey or ambiguous-zero
cells to push biomass downward."

Do not say: "All zeros are true absences."

Next analysis needed: survey-effort/access metadata if reviewers demand an
informative nondetection model.

## Generality And Transfer

Answer: `m3_bc_marginal` is now the usable coastwide sensitivity. It supports
the claim that the portfolio logic is not only a Haida Gwaii artifact, but it
does not replace the HG baseline or add a new mechanism.

Evidence:

- `m3_bc_marginal` clears HMC and PSIS gates.
- It improves positive-spawn calibration over the marginalized M1 comparator.

Allowed wording: "The coastwide marginalized sensitivity supports transfer of
the spatial portfolio framing across BC stock areas."

Do not say: "`m3_bc_marginal` is the new promoted biological model."

Next analysis needed: robust CV only if reviewers require a second validation
layer after the clean PSIS-LOO repair.

## Ecosystem-Service Valuation

Answer: dollars are not the sole metric because the service tip includes
spatial access, reliability, cultural use, optionality, and governance capacity.

Allowed wording: "The service loss is an erosion of options and reliable local
access, not only a change in landed value."

Do not say: "The value of the portfolio is fully captured by landed revenue."

Next analysis needed: link portfolio scenarios to access/reliability metrics
before monetary valuation.
