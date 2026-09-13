# BC Predator Covariates — Provenance and Spatial Resolution

Generated: 2026-07-31 13:21:23

Source repo: ` /Users/adrianstier/pacific-herring-predators `

## Per-species notes

| Species | Source file | Native resolution | Used in model as |
|---|---|---|---|
| harbour_seal | `/Users/adrianstier/pacific-herring-predators/data/processed/mammals/harbour_seal_BC_interpolated_along_Olesiuk_2010_curve_1965-2019.csv` | BC-wide year | Stock-area-level covariate (replicated across sections within a stock area is identical) |
| steller | `/Users/adrianstier/pacific-herring-predators/data/processed/mammals/ssl_bc_breeding_summed_annual_2026.csv` | BC-wide year | Stock-area-level covariate (same; non-pup count preferred when available) |
| humpback | `/Users/adrianstier/pacific-herring-predators/data/processed/mammals/cheeseman_2024_humpback_BC_annual_indiv_encounters.csv` | BC-wide year | Stock-area-level covariate (same; BC unique individuals preferred when available) |

**Implication:** in scripts/08_fit_m5_bc.R, predator covariates enter as
year-by-stock-area effects, not section-by-year. Section-level predator
variation will be added in a later iteration if section-resolved data
becomes available from the sibling repo's consumption-budget products.
