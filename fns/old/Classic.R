#' ###############
#' Updating first implementation of Classic EM
#' to utilise maximum parameter difference rather than log-likelihood
#' as this should save computation time.
#' ###############

tr <- function(x) sum(diag(x))
ll <- function(X, Y, Z, beta, var.0, var.1){ 
  V <- c(var.1) * tcrossprod(Z) + c(var.0) * diag(length(Y)) # sigma.u * ZZt + sigma.eIn
  V.sqrt <- chol(V)
  detV <- sum(log(diag(V.sqrt))) * 2
  # X, beta and residuals
  Xb <- X %*% beta
  resid <- Y - Xb
  temp <- sum(forwardsolve(l = t(V.sqrt), x = resid) ^ 2)
  return(
    -0.5*length(Y)*log(2*pi) -0.5 * temp - 0.5 * detV
  )
}

# Define EM function ------------------------------------------------------
em <- function(X,Y,Z, init.beta = beta0, init.var.0 = var.0, init.var.1 = var.1,
                       tol = 1e-3, maxiter = 2000, history = F){
  message("EM Algorithm ----\nDimensions: ", nrow(Y), " x ", ncol(X)-1, 
          "\nInitial estimates: beta =  ", init.beta, "\nsigma0 = ", sqrt(init.var.0),"; sigma1 = ", sqrt(init.var.1),
          "tol = ", tol, " maximum iterations = ", maxiter)
  
  diff <- 100
  iter <- 0
  
  var.0 <- init.var.0; var.1 <- init.var.1; beta = init.beta
  
  if(!"matrix" %in% class(beta)){
    beta <- matrix(beta, ncol = 1)
  }
  
  params <- c(t(beta), var.0, var.1)
  if(history) iter.hist <- data.frame(iter, t(params))

  n <- length(Y); q1 <- ncol(Z)
  
  t0 <- proc.time()[3]
  # Begin while loop
  while(diff > tol & iter <= maxiter){
    
    # E step ----
    # Covariance stuff
    V <- c(var.1) * tcrossprod(Z) + c(var.0) * diag(n)
    Vinv <- solve(V)
    V.sqrt <- chol(V)
    # X %*% beta and resulting residuals
    XtX <- crossprod(X)
    Xb <- X %*% beta
    resid <- Y-Xb
    # Calculate expectations uiuiT (call this u.0 (ie eps) and u.1)
    z <- forwardsolve(t(V.sqrt), Z)
    u.0 <- c(var.0)^2 * crossprod(resid, Vinv) %*% Vinv %*% resid +
      tr(c(var.0) * diag(n) - c(var.0)^2 * Vinv)
    u.1 <- c(var.1)^2 * crossprod(resid, Vinv) %*% tcrossprod(Z) %*% Vinv %*% resid +
      tr(c(var.1) * diag(q1) - c(var.1)^2 * crossprod(z))
    
    w <- Xb + c(var.0) * Vinv %*% resid
    
    # M step ----
    var.0.new <- u.0/n
    var.1.new <- u.1/q1
    beta.new <- solve(XtX) %*% crossprod(X,w)
    
    # New parameter set
    params.new <- c(t(beta.new), var.0.new, var.1.new)
    diffs <- abs(params.new-params)
    diff <- max(diffs)
    print(params)
    print(params.new) 
    print(diffs)
    print(diff)
    
    message("Iteration ", iter, " largest difference = ", diff)
    
    # Set new parameters
    var.0 <- var.0.new
    var.1 <- var.1.new
    beta <- beta.new
    iter <- iter + 1
    params <- c(t(beta), var.0, var.1) # 60 minutes before realised this was missing !
    
    # Record history if needed
    if(history) iter.hist <- rbind(iter.hist, c(iter, t(params.new)))
  }
  t1 <- proc.time()[3]
  message("EM Complete after ", iter, " iterations, this took ", round(t1-t0,2), " seconds.")
  if(history){
    rtn <- list(beta = beta, sigma.0 = sqrt(var.0), sigma.1 = sqrt(var.1), iter.hist = iter.hist,
                time = t1-t0, iter = iter, ll = ll(X,Y,Z,beta,var.0,var.1))
  }else{
    rtn <- list(beta = beta, sigma.0 = sqrt(var.0), sigma.1 = sqrt(var.1),
                time = t1-t0, iter = iter, ll = ll(X,Y,Z,beta,var.0,var.1))
  }
  rtn
}
