using Random: shuffle!
using Random
import Statistics: quantile

export LocalPermutationTest
export LocalPermutationTestResult
export pvalue

# `LocalPermutationClosenessSearch`and its subtypes is just for internal use.
# The `LocalPermutationTest` as given in Runge et al. (2018) uses neighbor searches,
# for determining closeness. This limits the usefulness of the test mostly to continuous
# data. It is possible to extend the test for discrete/mixed data, but then other
# "closeness schemes" must be applied. By dispatching on `LocalPermutationClosenessSearch`
# internally, we don't need to introduce breaking changes later when other search types
# are introduced.
"""
The supertype of all types indicating a way of determining "closeness" for the
local permutation algorithm.
"""
abstract type LocalPermutationClosenessSearch end

"""
    NeighborCloseness <: LocalPermutationClosenessSearch

Determine closeness between points for [`LocalPermutationTest`](@ref) using nearest neighbors
searches.
"""
struct NeighborCloseness <: LocalPermutationClosenessSearch end

"""
    LocalPermutationTest <: IndependenceTest
    LocalPermutationTest(measure, [est];
        kperm::Int = 5,
        nshuffles::Int = 100,
        rng = Random.default_rng(),
        replace = true,
        w::Int = 0)

`LocalPermutationTest` is a generic conditional independence test (Runge, 2018)[^Runge2018]
for assessing whether two variables `X` and `Y` are conditionally independendent given a
third variable `Z` (all of which may be multivariate).

When used with [`independence`](@ref), a [`LocalPermutationTestResult`](@ref) is returned.

## Description

This is a generic one-sided hypothesis test that checks whether `X` and `Y`
are independent (given `Z`, if provided) based on resampling from a null distribution
assumed to represent independence between the variables. The null distribution is generated
by repeatedly shuffling the input data in some way that is intended
to break any dependence between `x` and `y`, but preserve dependencies between `x` and `z`.

The algorithm is as follows:

1. Compute the original conditional independence statistic `I(X; Y | Z)`.
2. Allocate a scalar valued vector `Î` with space for `nshuffles` elements.
3. For `k ∈ [1, 2, …, nshuffles]`, repeat
    * For each `zᵢ ∈ Y`, let `nᵢ` be time indices of the `kperm` nearest neighbors of `zᵢ`,
        excluding the `w` nearest neighbors of `zᵢ` from the neighbor query (i.e `w` is
        the Theiler window).
    * Let `xᵢ⋆ = X[j]`, where `j` is randomly sampled from `nᵢ` with replacement.
        This way, `xᵢ` is replaced with `xⱼ` only if `zᵢ ≈ zⱼ` (`zᵢ` and `zⱼ` are close).
        Repeat for `i = 1, 2, …, n` and obtain the shuffled `X̂ = [x̂₁, x̂₂, …, x̂ₙ]`.
    * Compute the conditional independence statistic `Iₖ(X̂; Y | Z)`.
    * Let `Î[k] = Iₖ(X̂; Y | Z)`.
6. Compute the p-value as `count(Î[k] .<= I) / nshuffles)`.

In additional to the conditional variant from Runge (2018), we also provide a pairwise
version, where the shuffling procedure is identical, except neighbors in `Y` are used
instead of `Z` and we `I(X; Y)` and `Iₖ(X̂; Y)` instead of `I(X; Y | Z)` and
`Iₖ(X̂; Y | Z)`.

## Compatible measures

| Measure                       | Pairwise | Conditional | Requires `est` |
| ----------------------------- | :------: | :---------: | :------------: |
| [`PartialCorrelation`](@ref)  |    ✖    |     ✓      |       No       |
| [`DistanceCorrelation`](@ref) |    ✖    |     ✓      |       No       |
| [`CMIShannon`](@ref)          |    ✖    |     ✓      |      Yes       |
| [`TEShannon`](@ref)           |    ✓    |     ✓      |      Yes       |
| [`PMI`](@ref)                 |    ✖    |     ✓      |      Yes       |

The `LocalPermutationTest` is only defined for conditional independence testing.
Exceptions are for measures like [`TEShannon`](@ref), which use conditional
measures under the hood even for their pairwise variants, and are therefore
compatible with `LocalPermutationTest`.

The nearest-neighbor approach in Runge (2018) can be reproduced by using the
[`CMIShannon`](@ref) measure with the [`FPVP`](@ref) estimator.

## Examples

- [Example using `CMIShannon`](@ref example_localpermtest_cmishannon).
- [Example using `TEShannon`](@ref example_localpermtest_teshannon).

[^Runge2018]: Runge, J. (2018, March). Conditional independence testing based on a
    nearest-neighbor estimator of conditional mutual information. In International
    Conference on Artificial Intelligence and Statistics (pp. 938-947). PMLR.

"""
struct LocalPermutationTest{M, EST, C, R} <: IndependenceTest{M}
    measure::M
    est::EST
    rng::R
    kperm::Int
    nshuffles::Int
    replace::Bool
    closeness_search::C
    w::Int # Theiler window
    function LocalPermutationTest(measure::M, est::EST = nothing;
            rng::R = Random.default_rng(),
            kperm::Int = 10,
            replace::Bool = true,
            nshuffles::Int = 100,
            closeness_search::C = NeighborCloseness(),
            w::Int = 0) where {M, EST, C, R}
        new{M, EST, C, R}(measure, est, rng, kperm, nshuffles, replace, closeness_search, w)
    end
end

Base.show(io::IO, test::LocalPermutationTest) = print(io,
    """
    `LocalPermutationTest` independence test.
    -------------------------------------
    measure:    $(test.measure)
    estimator:  $(test.est)
    rng:        $(test.rng)
    # shuffles: $(test.nshuffles)
    k (perm)    $(test.kperm)
    """
)

"""
    LocalPermutationTestResult(m, m_surr, pvalue)

Holds the result of a [`LocalPermutationTest`](@ref). `m` is the measure computed on
the original data. `m_surr` is a vector of the measure computed on permuted data, where
`m_surr[i]` is the measure compute on the `i`-th permutation. `pvalue` is the one-sided
`p`-value for the test.
"""
struct LocalPermutationTestResult{M, MS, P} <: IndependenceTestResult
    n_vars::Int # 2 vars = pairwise, 3 vars = conditional
    m::M
    m_surr::MS
    pvalue::P
    nshuffles::Int
end
pvalue(r::LocalPermutationTestResult) = r.pvalue
quantile(r::LocalPermutationTestResult, q) = quantile(r.m_surr, q)

function Base.show(io::IO, test::LocalPermutationTestResult)
    print(io,
        """\
        `LocalPermutationTest` independence test
        $(null_hypothesis_text(test::IndependenceTestResult))
        $(quantiles_text(test))
        $(pvalue_text_summary(test))
        """
        )
end

# It is possible to specialize on the measure, e.g. LocalPermutationTest{CMI}. This
# should be done for the NN-based CMI methods, so we don't have to reconstruct
# KD-trees and do marginal searches for all marginals all the time.
function independence(test::LocalPermutationTest, x, y, z)
    measure, est, nshuffles = test.measure, test.est, test.nshuffles
    X, Y, Z = StateSpaceSet(x), StateSpaceSet(y), StateSpaceSet(z)
    @assert length(X) == length(Y) == length(Z)
    N = length(X)
    Î = estimate(measure, est, X, Y, Z)
    Îs = permuted_Îs(X, Y, Z, measure, est, test)
    p = count(Î .<= Îs) / nshuffles
    return LocalPermutationTestResult(3, Î, Îs, p, nshuffles)
end

# This method takes `measure` and `est` explicitly, because for some measures
# like `TEShannon`, `test.measure` may be converted to some other measure before
# computing the test statistic.
function permuted_Îs(X, Y, Z, measure, est, test)
    rng, kperm, nshuffles, replace, w = test.rng, test.kperm, test.nshuffles, test.replace, test.w
    N = length(X)
    test.kperm < N || throw(ArgumentError("kperm must be smaller than input data length"))

    tree_z = KDTree(Z, Chebyshev())
    idxs_z = bulkisearch(tree_z, Z, NeighborNumber(kperm), Theiler(w))
    X̂ = deepcopy(X)
    Nᵢ = MVector{kperm, Int}(zeros(kperm)) # A statically sized copy
    πs = shuffle(rng, 1:N)
    Îs = zeros(nshuffles)
    for n in 1:nshuffles
        if replace
            shuffle_with_replacement!(X̂, X, idxs_z, rng)
        else
            shuffle_without_replacement!(X̂, X, idxs_z, kperm, rng, Nᵢ, πs)
        end
        Îs[n] = estimate(measure, est, X̂, Y, Z)
    end

    return Îs
end

function shuffle_with_replacement!(X̂, X, idxs, rng)
    for i in eachindex(X)
        X̂[i] = X[rand(rng, idxs[i])]
    end
end

function shuffle_without_replacement!(X̂, X, idxs, kperm, rng, Nᵢ, πs)
    N = length(X)
    selected_js = zeros(Int, N)
    shuffle!(πs)
    for i in eachindex(X)
        sample!(rng, idxs[i], Nᵢ)
        j = first(Nᵢ)
        m = 1
        while j ∈ Nᵢ && m < kperm
            m += 1
            j = Nᵢ[m]
        end
        X̂[i] = X[j]
        selected_js[i] = j
    end
end

# Concrete implementations
include("transferentropy.jl")
