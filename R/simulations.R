#' Simulate Thurstonian IRT data
#'
#' @param npersons Number of persons.
#' @param ntraits Number of traits.
#' @param lambda Item factor loadings.
#' @param gamma Baseline attractiveness parameters of the
#'   first item versus the second item in the pairwise comparisons.
#'   Can be thought of as intercept parameters.
#' @param psi Optional item uniquenesses. If not provided,
#'   they will be computed as \code{psi = 1 - lambda^2} in which
#'   case lambda are taken to be the standardized factor loadings.
#' @param Phi Optional trait correlation matrix from which to sample
#'   person factor scores. Only used if \code{eta} is not provided.
#' @param eta Optional person factor scores. If provided, argument
#'   \code{Phi} will be ignored.
#' @param family Name of assumed the response distribution. Either
#'   \code{"bernoulli"}, \code{"cumulative"}, or \code{"gaussian"}.
#' @param nblocks_per_trait Number of blocks per trait.
#' @param nitems_per_block Number of items per block.
#' @param comb_blocks Indicates how to combine traits to blocks.
#'   \code{"fixed"} implies a simple non-random design that may combine
#'   certain traits which each other disproportionally often. We thus
#'   recommend to use a \code{"random"} block design (the default) that
#'   combines all traits with all other traits equally often on average.
#'
#' @return A \code{data.frame} of the same structure
#' as returned by \code{\link{make_TIRT_data}}. Parameter values
#' from which the data were simulated are stored as attributes
#' of the returned object.
#'
#' @examples
#' # simulate some data
#' sdata <- sim_TIRT_data(
#'   npersons = 100,
#'   ntraits = 3,
#'   nblocks_per_trait = 4,
#'   gamma = 0,
#'   lambda = c(runif(6, 0.5, 1), runif(6, -1, -0.5)),
#'   Phi = diag(3)
#' )
#'
#' # take a look at the data
#' head(sdata)
#' str(attributes(sdata))
#'
#' \donttest{
#' # fit a Thurstonian IRT model using lavaan
#' fit <- fit_TIRT_lavaan(sdata)
#' print(fit)
#' }
#'
#' @importFrom stats sd setNames
#' @importFrom rlang .data
#' @export
sim_TIRT_data <- function(npersons, ntraits, lambda, gamma,
                          psi = NULL, Phi = NULL, eta = NULL,
                          family = "bernoulli",
                          nblocks_per_trait = 5, nitems_per_block = 3,
                          comb_blocks = c("random", "fixed")) {
  # prepare data in long format to which responses may be added
  if ((ntraits * nblocks_per_trait) %% nitems_per_block != 0L) {
    stop("The number of items per block must divide ",
         "the number of total items.")
  }
  family <- check_family(family)
  comb_blocks <- match.arg(comb_blocks)
  nblocks <- ntraits * nblocks_per_trait / nitems_per_block
  nitems <- nitems_per_block * nblocks
  ncomparisons <- (nitems_per_block * (nitems_per_block - 1)) / 2
  data <- tibble::tibble(
    person = rep(1:npersons, ncomparisons * nblocks),
    block = rep(1:nblocks, each = npersons * ncomparisons),
    comparison = rep(rep(1:ncomparisons, each = npersons), nblocks)
  )
  # select traits for each block
  trait_combs <- make_trait_combs(
    ntraits, nblocks_per_trait, nitems_per_block,
    comb_blocks = comb_blocks
  )
  items_per_trait <- vector("list", ntraits)
  for (i in seq_len(nblocks)) {
    traits <- trait_combs[i, ]
    trait1 <- rep_comp(traits, 1, nitems_per_block)
    trait2 <- rep_comp(traits, 2, nitems_per_block)
    fblock <- (i - 1) * nitems_per_block
    item1 <- match(trait1, traits) + fblock
    item2 <- match(trait2, traits) + fblock
    sign1 <- sign(lambda[item1])
    sign2 <- sign(lambda[item2])
    comparison <- data[data$block == i, ]$comparison
    data[data$block == i, "itemC"] <- comparison + fblock
    data[data$block == i, "trait1"] <- trait1[comparison]
    data[data$block == i, "trait2"] <- trait2[comparison]
    data[data$block == i, "item1"] <- item1[comparison]
    data[data$block == i, "item2"] <- item2[comparison]
    data[data$block == i, "sign1"] <- sign1[comparison]
    data[data$block == i, "sign2"] <- sign2[comparison]
    # save item numbers per trait
    for (t in unique(trait1)) {
      items_per_trait[[t]] <- union(
        items_per_trait[[t]], item1[match(t, trait1)]
      )
    }
    for (t in unique(trait2)) {
      items_per_trait[[t]] <- union(
        items_per_trait[[t]], item2[match(t, trait2)]
      )
    }
  }

  # prepare parameters
  if (is.null(eta)) {
    eta <- sim_eta(npersons, Phi)
  }
  if (length(gamma) == 1L) {
    gamma <- rep(gamma, ncomparisons * nblocks)
  }
  if (!is.list(lambda) && length(lambda) == 1L) {
    lambda <- rep(lambda, nitems)
  }
  if (is.null(psi)) {
    message("Computing standardized psi as 1 - lambda^2")
    psi <- lambda2psi(lambda)
  } else if (!is.list(psi) && length(psi) == 1L) {
    psi <- rep(psi, nitems)
  }
  if (NROW(gamma) != ncomparisons * nblocks) {
    stop("gamma should contain ", ncomparisons * nblocks, " rows.")
  }
  if (sum(lengths(lambda)) != nitems) {
    stop("lambda should contain ", nitems, " values.")
  }
  if (sum(lengths(psi)) != nitems) {
    stop("psi should contain ", nitems, " values.")
  }
  dim_eta_exp <- c(length(unique(data$person)), ntraits)
  if (!is_equal(dim(eta), dim_eta_exp)) {
    stop("eta should be of dimension (", dim_eta_exp[1],
         ", ", dim_eta_exp[2], ").")
  }
  if (family == "cumulative") {
    stopifnot(NCOL(gamma) > 1L)
    data$gamma <- gamma[data$itemC, , drop = FALSE]
  } else {
    stopifnot(NCOL(gamma) == 1L)
    data$gamma <- as.vector(gamma)[data$itemC]
  }
  if (is.list(lambda)) {
    if (length(lambda) != ntraits) {
      stop("lambda should contain ", ntraits, " list elements.")
    }
    lambda_order <- order(unlist(items_per_trait))
    lambda <- unlist(lambda)[lambda_order]
  }
  data$lambda1 <- lambda[data$item1]
  data$lambda2 <- lambda[data$item2]
  if (is.list(psi)) {
    if (length(psi) != ntraits) {
      stop("psi should contain ", ntraits, " list elements.")
    }
    psi_order <- order(unlist(items_per_trait))
    psi <- unlist(psi)[psi_order]
  }
  data$psi1 <- psi[data$item1]
  data$psi2 <- psi[data$item2]
  for (p in seq_len(npersons)) {
    take <- data$person == p
    pdat <- data[take, ]
    data[take, "eta1"] <- eta[p, pdat$trait1]
    data[take, "eta2"] <- eta[p, pdat$trait2]
  }

  data$mu <- mean_response(data, family = family)
  data$response <- sim_response(data$mu, family = family)
  structure(data,
    npersons = npersons, ntraits = ntraits, nblocks = nblocks,
    nitems = nitems, nblocks_per_trait = nblocks_per_trait,
    nitems_per_block = nitems_per_block,
    signs = sign(lambda), lambda = lambda, psi = psi, eta = eta,
    traits = paste0("trait", seq_len(ntraits)),
    family = family, ncat = NCOL(data$gamma) + 1,
    class = c("TIRTdata", class(data))
  )
}

sim_eta <- function(npersons, Phi) {
  mu <- rep(0, nrow(Phi))
  mvtnorm::rmvnorm(npersons, mu, Phi)
}

sim_response <- function(mu, family = "bernoulli", disp = 20) {
  # Args:
  #   mu: vector or matrix of means / category probabilities
  #   disp: dispersion parameter for beta models
  stopifnot(NCOL(mu) > 0L)
  if (NCOL(mu) == 1L) {
    stopifnot(family %in% c("bernoulli", "beta", "gaussian"))
    if (family == "bernoulli") {
      out <- stats::rbinom(length(mu), size = 1, prob = mu)
    } else if (family == "beta") {
      # mean parameterization of the beta distribution
      out <- stats::rbeta(length(mu), mu * disp, (1 - mu) * disp)
      # truncate distribution at the extremes
      out[out < 0.001] <- 0.001
      out[out > 0.999] <- 0.999
    } else if (family == "gaussian") {
      out <- stats::rnorm(length(mu), mu)
    }
  } else {
    stopifnot(family %in% "cumulative")
    cats <- seq_len(NCOL(mu)) - 1
    out <- apply(mu, 1, function(p) sample(cats, 1, prob = p))
  }
  out
}

#' @importFrom stats pnorm
mean_response <- function(data, family) {
  # compute category probabilities
  ncat <- NCOL(data$gamma) + 1
  stopifnot(ncat > 1L)
  if (ncat == 2L) {
    stopifnot(family %in% c("bernoulli", "beta", "gaussian"))
    out <- with(data,
      (-gamma + lambda1 * eta1 - lambda2 * eta2) /
        sqrt(psi1^2 + psi2^2)
    )
    if (family %in% c("bernoulli", "beta")) {
      out <- pnorm(out)
    }
  } else {
    stopifnot(family %in% "cumulative")
    sum_psi <- with(data, sqrt(psi1^2 + psi2^2))
    mu <- with(data, lambda1 * eta1 - lambda2 * eta2) / sum_psi
    out <- matrix(ncol = ncat, nrow = length(mu))
    std_gamma <- data$gamma / sum_psi
    out[, 1] <- pnorm(std_gamma[, 1] - mu)
    out[, ncat] <- 1 - pnorm(std_gamma[, ncat - 1] - mu)
    for (i in seq_len(ncat)[-c(1, ncat)]) {
      out[, i] <- pnorm(std_gamma[, i] - mu) -
        pnorm(std_gamma[, i - 1] - mu)
    }
  }
  out
}

make_trait_combs <- function(ntraits, nblocks_per_trait, nitems_per_block,
                             comb_blocks = c("fixed", "random"),
                             maxtrys_outer = 20, maxtrys_inner = 1e6) {
  comb_blocks <- match.arg(comb_blocks)
  stopifnot((ntraits * nblocks_per_trait) %% nitems_per_block == 0L)
  if (comb_blocks == "fixed") {
    # use comb_blocks == "random" for a better balanced design
    traits <- rep(seq_len(ntraits), nblocks_per_trait)
    out <- matrix(traits, ncol = nitems_per_block, byrow = TRUE)
  } else if (comb_blocks == "random") {
    nblocks <- (ntraits * nblocks_per_trait) %/% nitems_per_block
    traits <- seq_len(ntraits)
    out <- replicate(nitems_per_block, traits, simplify = FALSE)
    out <- as.matrix(expand.grid(out))
    rownames(out) <- NULL
    remove <- rep(FALSE, nrow(out))
    for (i in seq_len(nrow(out))) {
      if (length(unique(out[i, ])) < ncol(out)) {
        remove[i] <- TRUE
      }
    }
    out <- out[!remove, ]
    possible_rows <- seq_len(nrow(out))
    nbpt_chosen <- rep(0, ntraits)

    .choose <- function(nblocks, maxtrys) {
      # finds suitable blocks
      chosen <- rep(NA, nblocks)
      i <- ntrys <- 1
      while (i <= nblocks && ntrys <= maxtrys) {
        ntrys <- ntrys + 1
        chosen[i] <- possible_rows[sample(seq_along(possible_rows), 1)]
        traits_chosen <- out[chosen[i], ]
        nbpt_chosen[traits_chosen] <- nbpt_chosen[traits_chosen] + 1
        valid <- max(nbpt_chosen) <= min(nbpt_chosen) + 1 &&
          !any(nbpt_chosen[traits_chosen] > nblocks_per_trait)
        if (valid) {
          possible_rows <- possible_rows[-chosen[i]]
          i <- i + 1
        } else {
          # revert number of blocks per trait chosen
          nbpt_chosen[traits_chosen] <- nbpt_chosen[traits_chosen] - 1
        }
      }
      return(chosen)
    }

    i <- 1
    chosen <- rep(NA, nblocks)
    while (anyNA(chosen) && i <= maxtrys_outer) {
      i <- i + 1
      chosen <- .choose(nblocks, maxtrys = maxtrys_inner)
    }
    if (anyNA(chosen)) {
      stop("Could not find a set of suitable blocks.")
    }
    out <- out[chosen, ]
  }
  out
}

lambda2psi <- function(lambda) {
  # according to Brown et al. 2011 for std lambda
  # Ideas for lambda if unstandardized:
  # multiply std lambda with sqrt(2)
  # create simulated data based on std factor scores
  .lambda2psi <- function(x) {
    x <- as.numeric(x)
    if (any(abs(x) > 1)) {
      stop("standardized lambdas are expect to be between -1 and 1.")
    }
    1 - x^2
  }
  if (is.list(lambda)) {
    psi <- lapply(lambda, .lambda2psi)
  } else {
    psi <- .lambda2psi(lambda)
  }
  psi
}
