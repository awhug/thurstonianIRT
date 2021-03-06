% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/data-helpers.R
\name{make_sem_data}
\alias{make_sem_data}
\title{Prepare data for Thurstonian IRT models fitted with
lavaan or Mplus}
\usage{
make_sem_data(data)
}
\arguments{
\item{data}{An object of class \code{'TIRTdata'}. see
\code{\link{make_TIRT_data}} for documentation on how to create one.}
}
\value{
A \code{data.frame} ready to be passed to \pkg{lavaan}
or \pkg{Mplus}.
}
\description{
Prepare data for Thurstonian IRT models fitted with
lavaan or Mplus
}
\examples{
# simulate some data
sdata <- sim_TIRT_data(
  npersons = 100,
  ntraits = 3,
  nblocks_per_trait = 4,
  gamma = 0,
  lambda = c(runif(6, 0.5, 1), runif(6, -1, -0.5)),
  Phi = diag(3)
)

# create data ready for use in SEM software
sem_data <- make_sem_data(sdata)
head(sem_data)

}
