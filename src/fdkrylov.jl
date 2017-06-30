
export dgmres


"""
`dirder(x,w,f,f0)`

Finite difference directional derivative, approximate f'(x) w

### Inputs
* x, w = point and direction
* f = function
* f0 = f(x), in nonlinear iterations f(x) has usually been computed
                before the call to dirder

### Output
* `z`: approximation to `f'(x) w`

based on a code by C. T. Kelley, April 1, 2003
"""
function dirder(x, w, f, f0; h = 1e-7)
   # initialise difference increment
   epsnew = h
   n = length(x)
   # scale the step
   if norm(w) == 0
      return zeros(n)
   end
   # Now scale the difference increment.
   xs = dot(x, w) / norm(w)
   if xs != 0.0
      epsnew *= max(abs(xs), 1.0) * sign(xs)
   end
   epsnew /= norm(w)
   f1 = f(x + epsnew * w)
   return (f1 - f0) / epsnew
end



"""
`function givapp(c, s, vin, k) -> vrot`

Apply a sequence of k Givens rotations, used within gmres codes.
"""
function givapp(c, s, vin, k)
   vrot = copy(vin)                   # TODO: can we do this in-place?
   for i = 1:k
      w1 = c[i] * vrot[i] - s[i] * vrot[i+1]
      # Here's a modest change that makes the code work in complex
      # arithmetic. Thanks to Howard Elman for this.
      # w2 = s(i)*vrot(i)+c(i)*vrot(i+1);
      w2 = s[i] * vrot[i] + c[i]' * vrot[i+1]
      vrot[i:i+1] = [w1, w2]
   end
   return vrot
end



"""
`function dgmres(f0, f, xc, errtol, kmax, [reorth, xinit]) -> x, error, total_iters`

GMRES linear equation solver for use in Newton-GMRES solver

### Input Parameters

* f0 : function at current point, f(xc)
* f : nonlinear function the format for f is  function fx = f(x)
              Note that for Newton-GMRES we incorporate any
              preconditioning into the function routine
* xc : current point
* errtol : relative residual reduction factor
* kmax : max number of iterations
* reorth : reorthogonalization method
      - 1 -- Brown/Hindmarsh condition (default)
      - 2 -- Never reorthogonalize (not recommended)
      - 3 -- Always reorthogonalize (not cheap!)
* xinit : initial iterate. xinit = zeros(f0) is the default. This
              is a reasonable choice unless restarted GMRES
              will be used as the linear solver.

### Output Parameters

* x : solution
* error : vector of residual norms for the history of the iteration
* total_iters : number of iterations
"""
function dgmres(f0, f, xc, errtol, kmax, reorth = 1, x = zeros(f0))
   # The right side of the linear equation for the step is -f0.
   b = - f0
   n = length(b)
   r = - dirder(xc, x, f, f0) - f0

   h = zeros(kmax, kmax)
   v = zeros(n, kmax)
   c = zeros(kmax+1)
   s = zeros(kmax+1)
   rho = norm(r)
   g = rho * eye(kmax+1, 1)
   errtol = errtol * norm(b)
   error = Float64[]

   # Test for termination on entry.
   push!(error, rho)
   total_iters = 0
   if (rho < errtol)
      # early termination
      return x, error, total_iters
   end

   v[:,1] = r / rho
   beta = rho
   k = 0

   # GMRES iteration
   while rho > errtol && k < kmax
      k = k+1;

      # Call directional derivative function.
      v[:, k+1] = dirder(xc, v[:,k], f, f0)
      normav = norm(v[:,k+1])

      # Modified Gram-Schmidt
      for j = 1:k
         h[j, k] = dot(v[:,j], v[:,k+1])
         v[:, k+1] = v[:,k+1] - h[j,k] * v[:,j]
      end
      h[k+1,k] = norm(v[:,k+1])
      normav2 = h[k+1,k]

      # Reorthogonalize?
      if  ((reorth == 1) && (normav + .001 * normav2 == normav)) || (reorth ==  3)
         for j = 1:k
            hr = dot(v[:,j], v[:,k+1])
            h[j,k] = h[j,k] + hr
            v[:,k+1] = v[:,k+1] - hr * v[:,j]
         end
         h[k+1, k] = norm(v[:,k+1])
      end

      # Watch out for happy breakdown.
      if h[k+1,k] != 0
         v[:,k+1] = v[:,k+1] / h[k+1,k]
      end

      # Form and store the information for the new Givens rotation.
      if k > 1
         h[1:k,k] = givapp(c[1:k-1], s[1:k-1], h[1:k,k], k-1)
      end

      # Don't divide by zero if solution has  been found.
      nu = norm(h[k:k+1,k])
      if nu != 0
         # c[k] = h[k,k]/nu
         c[k] = conj(h[k,k] / nu)
         s[k] = -h[k+1,k] / nu;
         h[k,k] = c[k] * h[k,k] - s[k] * h[k+1,k]
         h[k+1,k] = 0
         g[k:k+1] = givapp(c[k], s[k], g[k:k+1], 1)
      end

      # Update the residual norm.
      rho = abs(g[k+1])
      push!(error, rho)
   end # end of the main while loop

   # At this point either k > kmax or rho < errtol.
   # It's time to compute x and leave.
   y = h[1:k,1:k] \ g[1:k]
   total_iters = k
   x = x + v[1:n, 1:k] * y

   return x, error, total_iters, total_iters 
end






# function [step, errstep, total_iters, f_evals] = ...
#     dkrylov(f0, f, x, params, lmeth)
# % Krylov linear equation solver for use in nsoli
# %
# % C. T. Kelley, April 1, 2003
# %
# %
# % This code comes with no guarantee or warranty of any kind.
# %
# % function [step, errstep, total_iters, f_evals]
# %                              = dkrylov(f0, f, x, params, lmeth)
# %
# %
# % Input:  f0 = function at current point
# %         f = nonlinear function
# %              the format for f is  function fx = f(x)
# %              Note that for Newton-GMRES we incorporate any
# %              preconditioning into the function routine.
# %         x = current point
# %         params = vector to control iteration
# %              params(1) = relative residual reduction factor
# %              params(2) = max number of iterations
# %              params(3) = max number of restarts for GMRES(m)
# %              params(4) (Optional) = reorthogonalization method in GMRES
# %                   1 -- Brown/Hindmarsh condition (default)
# %                   2 -- Never reorthogonalize (not recommended)
# %                   3 -- Always reorthogonalize (not cheap!)
# %
# %         lmeth = method choice
# %              1 GMRES without restarts (default)
# %              2 GMRES(m), m = params(2) and the maximum number
# %                   of restarts is params(3)
# %              3 Bi-CGSTAB
# %              4 TFQMR
# %
# % Output: x = solution
# %         errstep = vector of residual norms for the history of
# %                 the iteration
# %         total_iters = number of iterations
# %
# %
#
# %
# # % initialization
# %
# lmaxit = params(2);
# restart_limit = 20;
# if length(params) >= 3
#     restart_limit = params(3);
# end
# if lmeth == 1, restart_limit = 0; end
# if length(params) == 3
# %
# % default reorthogonalization
# %
#      gmparms = [params(1), params(2), 1];
# elseif length(params) == 4
# %
# % reorthogonalization method is params(4)
# %
#      gmparms = [params(1), params(2), params(4)];
# else
#      gmparms = [params(1), params(2)];
# end
#
# %
# % compute the step using a GMRES routine especially designed
# % for this purpose
# %


   #  [step, errstep, f_evals] = dgmres(f0, f, x, gmparms);
