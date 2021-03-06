#' #########
#' Bernhardt.R
#' Proof of concept for the approach taken by P. Bernhardt (2015)
#' Applied to a simple LME model, so may not be super useful.
#' #########

rm(list=ls())
library(lme4)
setwd("~/Documents/PhD/EM-Algorithm/fns/")
source("simlong.R")

# 1. Using all data, get initial estimates for \bm{\theta}
x <- simlong(num_subj = 100, num_times = 5)
X <- x$X; Y <- x$Y; Z <- x$Z
beta0 <- x$lmer.fit@beta
var.0.init <- sd(x$Y - x$X %*% beta0)^2 # instead of just getting out of lmer.fit
var.1.init <- as.numeric(summary(x$lmer.fit)$varcor[1])
theta0 <- c(beta0, var.0.init, var.1.init)

# 2. Maximise u1u1t using stats::optim
tr <- function(x) sum(diag(x))

n <- length(Y); q <- ncol(Z)
u1u1 <- function(theta){
  beta <- matrix(theta[1:3], ncol = 1)
  V <- c(theta[5]) * tcrossprod(Z) + c(theta[4]) * diag(n)
  V.inv <- solve(V)
  V.sqrt <- chol(V)
  Xb <- X %*% beta
  resid <- Y-Xb
  z <- forwardsolve(t(V.sqrt), Z)
  c(theta[5])^2 * crossprod(resid, V.inv) %*% tcrossprod(Z) %*% V.inv %*% resid +
    tr(c(theta[5]) * diag(q) - c(theta[5])^2 * crossprod(z))
}

# Constraints
ui <- cbind(c(38, -12, 1.2, 0, 0),
            c(42, -8,  1.8, 4, 2))

# Constraints
bounds <- matrix(c(
  38,42,
  -12,-8,
  1.2,1.8,
  0,4,
  0,2
), nc=2, byrow=TRUE)
colnames(bounds) <- c("lower", "upper")

# Convert the constraints to the ui and ci matrices
nn <- nrow(bounds)
ui <- rbind( diag(nn), -diag(nn) )
ci <- c( bounds[,1], -bounds[,2] )

# Remove the infinite values
i <- as.vector(is.finite(bounds))
ui <- ui[i,]
ci <- ci[i]

constrOptim(theta0, u1u1, grad = NULL,
            ui = ui, ci = ci)

# Don't think you need this.
u0u0 <- function(theta){
  n <- length(Y); q <- ncol(Z)
  beta <- matrix(theta[1:3], ncol = 1)
  V <- c(theta[5]) * tcrossprod(Z) + c(theta[4]) * diag(n)
  V.inv <- solve(V)
  # X %*% beta and resulting residuals
  Xb <- X %*% beta
  resid <- Y-Xb
  # Calculate expectations u0u0t
  
  c(theta[4])^2 * crossprod(resid, V.inv) %*% V.inv %*% resid +
    tr(c(theta[4]) * diag(n) - c(theta[4])^2 * V.inv)
}
X <- x$X; Y <- x$Y; Z <- x$Z
u0u0(theta0)

optim(par = theta0, u0u0, method = "L-BFGS-B",#, lower = c(35, -15, 1, 0.1, 0.1), upper = c(45, -5, 2, 3, 1),
      control = list(fnscale = -1, REPORT = 1))
# Not working properly with/out bounds on optim

# Since beta a good estimate, try and just estimate variance terms?
theta <- c(var.0.init, var.1.init)
n <- length(Y); q <- ncol(Z)

u0u0.vars <- function(theta){
  V <- c(theta[2]) * tcrossprod(Z) + c(theta[1]) * diag(n)
  V.inv <- solve(V)
  Xb <- X %*% beta0
  resid <- Y - Xb
  c(theta[1])^2 * crossprod(resid, V.inv) %*% V.inv %*% resid +
    tr(c(theta[1]) * diag(n) - c(theta[1])^2 * V.inv)
}

optim(theta, u0u0.vars, method = "L-BFGS-B", control = list(trace = 3, fnscale = -1),
      lower = c(0,0))
constrOptim(theta, u0u0.vars, grad = NULL,
            ui = diag(2), ci = c(0,0))
