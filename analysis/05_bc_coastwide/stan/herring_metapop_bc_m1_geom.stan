// ============================================================================
// herring_metapop_bc_m1_geom.stan -- Conservative geometry repair for BC M1
// analysis/05_bc_coastwide
//
// Keeps the centered latent state process, which is better suited to observed
// state-space series than a fully non-centered latent path, but removes the
// unused distance-range parameter and simplifies the initial-state hierarchy.
// ============================================================================

data {
  int<lower=1> N_sections;
  int<lower=1> N_years;
  int<lower=1> N_stock_areas;
  array[N_sections] int<lower=1, upper=N_stock_areas> stock_area_of;

  array[N_sections, N_years] real<lower=0> y;
  array[N_sections, N_years] int<lower=0, upper=1> obs_mask;

  int<lower=0> N_D;
  vector[N_D] D_blocks;
  array[N_stock_areas] int<lower=1> block_starts;
  array[N_stock_areas] int<lower=0> block_sizes;
}

transformed data {
  array[N_sections, N_years] real log_y;
  for (s in 1:N_sections)
    for (t in 1:N_years)
      log_y[s, t] = obs_mask[s, t] == 1 ? log(y[s, t]) : 0.0;
}

parameters {
  vector[N_stock_areas] r_area;
  vector<lower=0>[N_stock_areas] sigma_area;
  real<lower=0> sigma_obs;
  array[N_sections, N_years] real z;
}

model {
  r_area ~ normal(0, 0.35);
  sigma_area ~ exponential(1.5);
  sigma_obs ~ exponential(1);

  for (s in 1:N_sections) {
    int a = stock_area_of[s];
    z[s, 1] ~ normal(log(100), 2);
    for (t in 2:N_years)
      z[s, t] ~ normal(z[s, t - 1] + r_area[a], sigma_area[a]);
  }

  for (s in 1:N_sections)
    for (t in 1:N_years)
      if (obs_mask[s, t] == 1)
        log_y[s, t] ~ normal(z[s, t], sigma_obs);
}

generated quantities {
  array[N_sections, N_years] real y_rep;
  array[N_sections, N_years] real log_lik;
  for (s in 1:N_sections) {
    for (t in 1:N_years) {
      y_rep[s, t] = lognormal_rng(z[s, t], sigma_obs);
      log_lik[s, t] = obs_mask[s, t] == 1
        ? normal_lpdf(log_y[s, t] | z[s, t], sigma_obs) : 0.0;
    }
  }
}
