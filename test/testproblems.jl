
# Define Test Problems
# ====================

tests = []

# [1] some random 2D problem
f1(x) = [x[1] + x[2] + x[1]^2, x[2] + x[1]*x[2]]
df1(x) = ForwardDiff.jacobian(f1, x)
init1() = [1.0,1.0]
randinit1() = rand(2)
push!(tests, (f1, df1, init1, randinit1, "toy2d"))


# [2] Chandrasekhar H-equation; cf http://www4.ncsu.edu/~ctk/newton/Chapter3/heq.m
c, n = 0.9, 100
gr = ((1:n) - 0.5) / n
A_heq = gr * ones(n)'
A_heq = (0.5 * c / n) * A_heq ./ (A_heq+A_heq')
f2(x) = x - ones(n) ./ (ones(n) - (A_heq * x))
df2(x) = ForwardDiff.jacobian(f2, x)
init2() = ones(n)
randinit2() = ones(n) + 0.1 * (rand(n) - 0.5)
push!(tests, (f2, df2, init2, randinit2, "H-equation"))
