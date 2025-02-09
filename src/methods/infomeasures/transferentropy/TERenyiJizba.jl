export TERenyiJizba

"""
    TERenyiJizba() <: TransferEntropy

The Rényi transfer entropy from Jizba et al. (2012)[^Jizba2012].

## Usage

- Use with [`independence`](@ref) to perform a formal hypothesis test for pairwise
    and conditional dependence.
- Use with [`transferentropy`](@ref) to compute the raw transfer entropy.

## Description

The transfer entropy from source ``S`` to target ``T``, potentially
conditioned on ``C`` is defined as

```math
\\begin{align*}
TE(S \\to T) &:= I_q^{R_J}(T^+; S^- | T^-) \\\\
TE(S \\to T | C) &:= I_q^{R_J}(T^+; S^- | T^-, C^-),
\\end{align*},
```
where ``I_q^{R_J}(T^+; S^- | T^-)`` is Jizba et al. (2012)'s definition of
conditional mutual information ([`CMIRenyiJizba`](@ref)).
The variables ``T^+``, ``T^-``,
``S^-`` and ``C^-`` are described in the docstring for [`transferentropy`](@ref).

## Compatible estimators

Jizba's formulation of Renyi-type transfer entropy can currently be estimated using
selected probabilities estimators and differential entropy estimators, which
under the hood compute the transfer entropy as Jizba's formulation of Rényi conditional
mutual information.

| Estimator                        | Type                                   | Principle           | [`TERenyiJizba`](@ref) |
| -------------------------------- | -------------------------------------- | ------------------- | :--------------------: |
| [`CountOccurrences`](@ref)       | [`ProbabilitiesEstimator`](@ref)       | Frequencies         |           ✓           |
| [`ValueHistogram`](@ref)         | [`ProbabilitiesEstimator`](@ref)       | Binning (histogram) |           ✓           |
| [`LeonenkoProzantoSavani`](@ref) | [`DifferentialEntropyEstimator`](@ref) | Nearest neighbors   |           ✓           |

[^Jizba2012]:
    Jizba, P., Kleinert, H., & Shefaat, M. (2012). Rényi’s information transfer between
    financial time series. Physica A: Statistical Mechanics and its Applications, 391(10),
    2971-2989.
"""
struct TERenyiJizba{E <: Renyi, EMB} <: TransferEntropy{E, EMB}
    e::E
    embedding::EMB
    function TERenyiJizba(; base = 2, q = 1.5, embedding::EMB = EmbeddingTE()) where EMB
        e = Renyi(; base = base, q = q)
        return new{typeof(e), EMB}(e, embedding)
    end
    function TERenyiJizba(e::E; embedding::EMB = EmbeddingTE()) where {E <: Renyi, EMB}
        return new{E, EMB}(e, embedding)
    end
end
