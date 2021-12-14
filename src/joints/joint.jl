abstract type Joint{T,N} end

### General functions
getT(joint::Joint{T}) where T = T
Base.length(joint::Joint{T,N}) where {T,N} = N
Base.zero(joint::Joint{T,N}) where {T,N} = szeros(T, N, 6)
@inline g(joint::Joint{T,N}) where {T,N} = szeros(T, N)

## Discrete-time position derivatives (for dynamics)
# Wrappers 1
@inline function ∂g∂ʳposa(joint::Joint, body1::Body, body2::Body, childid, λ, Δt)
    if body2.id == childid
        return constraintmat(joint) * ∂g∂ʳposa(joint, body1.state, body2.state, λ, Δt)
    else
        return zero(joint)
    end
end
@inline function ∂g∂ʳposb(joint::Joint, body1::Body, body2::Body, childid, λ, Δt)
    if body2.id == childid
        return constraintmat(joint) * ∂g∂ʳposb(joint, body1.state, body2.state, λ, Δt)
    else
        return zero(joint)
    end
end
@inline function ∂g∂ʳposb(joint::Joint, body1::Origin, body2::Body, childid, λ, Δt)
    if body2.id == childid
        return constraintmat(joint) * ∂g∂ʳposb(joint, body2.state, λ, Δt)
    else
        return zero(joint)
    end
end

## Discrete-time velocity derivatives (for dynamics)
# Wrappers 1
@inline function ∂g∂ʳvela(joint::Joint, body1::Body, body2::Body, childid, λ, Δt)
    if body2.id == childid
        return constraintmat(joint) * ∂g∂ʳvela(joint, body1.state, body2.state, λ, Δt)
    else
        return zero(joint)
    end
end
@inline function ∂g∂ʳvelb(joint::Joint, body1::Body, body2::Body, childid, λ, Δt)
    if body2.id == childid
        return constraintmat(joint) * ∂g∂ʳvelb(joint, body1.state, body2.state, λ, Δt)
    else
        return zero(joint)
    end
end
@inline function ∂g∂ʳvelb(joint::Joint, body1::Origin, body2::Body, childid, λ, Δt)
    if body2.id == childid
        return constraintmat(joint) * ∂g∂ʳvelb(joint, body2.state, λ, Δt)
    else
        return zero(joint)
    end
end

# @inline function offdiagonal∂damper∂ʳvel(joint::Joint, body1::Body, body2::Body, childid)
#     if body2.id == childid
#         return offdiagonal∂damper∂ʳvel(joint, body1.state, body2.state)
#     else
#         return zero(body2)
#     end
# end
# @inline function offdiagonal∂damper∂ʳvel(joint::Joint, body1::Origin, body2::Body, childid)
#     if body2.id == childid
#         return offdiagonal∂damper∂ʳvel(joint, body2.state)
#     else
#         return zero(body2)
#     end
# end

### Springs and Dampers (for dynamics)
## Wrappers 1
@inline function springforcea(joint::Joint, body1::Body, body2::Body, Δt, childid)
    if body2.id == childid
        return springforcea(joint, body1.state, body2.state, Δt)
    else
        return springforce(joint)
    end
end
@inline function springforceb(joint::Joint, body1::Body, body2::Body, Δt, childid)
    if body2.id == childid
        return springforceb(joint, body1.state, body2.state, Δt)
    else
        return springforce(joint)
    end
end
@inline function springforceb(joint::Joint, body1::Origin, body2::Body, Δt, childid)
    if body2.id == childid
        return springforceb(joint, body2.state, Δt)
    else
        return springforce(joint)
    end
end

@inline function damperforcea(joint::Joint, body1::Body, body2::Body, Δt, childid)
    if body2.id == childid
        return damperforcea(joint, body1.state, body2.state, Δt)
    else
        return damperforce(joint)
    end
end
@inline function damperforceb(joint::Joint, body1::Body, body2::Body, Δt, childid)
    if body2.id == childid
        return damperforceb(joint, body1.state, body2.state, Δt)
    else
        return damperforce(joint)
    end
end
@inline function damperforceb(joint::Joint, body1::Origin, body2::Body, Δt, childid)
    if body2.id == childid
        return damperforceb(joint, body2.state, Δt)
    else
        return damperforce(joint)
    end
end

## Wrappers 2
@inline springforce(joint::Joint{T}) where {T} = szeros(T, 6) # TODO zero function?

@inline damperforce(joint::Joint{T}) where {T} = szeros(T, 6) # TODO zero function?

# ### Forcing (for dynamics)
## Wrappers
@inline function applyFτ!(joint::Joint, body1::Body, body2::Body, Δt::T, clear::Bool) where T
    applyFτ!(joint, body1.state, body2.state, Δt, clear)
    return
end

@inline function applyFτ!(joint::Joint, ::Origin, body2::Body, Δt::T, clear::Bool) where T
    applyFτ!(joint, body2.state, Δt, clear)
    return
end

Joint0 = Joint{T,0} where T
Joint1 = Joint{T,1} where T
Joint2 = Joint{T,2} where T
Joint3 = Joint{T,3} where T

# Base.show(io::IO, joint::Joint) = summary(io, joint)

### Constaint and nullspace matrices
@inline constraintmat(::Joint0{T}) where T = szeros(T,0,3)
@inline nullspacemat(::Joint0{T}) where T = SMatrix{3,3,T,9}(I)
@inline constraintmat(joint::Joint1) = joint.V3
@inline nullspacemat(joint::Joint1) = joint.V12
@inline constraintmat(joint::Joint2) = joint.V12
@inline nullspacemat(joint::Joint2) = joint.V3
@inline constraintmat(::Joint3{T}) where T = SMatrix{3,3,T,9}(I)
@inline nullspacemat(::Joint3{T}) where T = szeros(T,0,3)

### Constraints and derivatives
## Position level constraint wrappers
@inline g(joint::Joint, body1::Body, body2::Body, λ, Δt) = constraintmat(joint) * g(joint, body1.state, body2.state, λ, Δt)
@inline g(joint::Joint, body1::Origin, body2::Body, λ, Δt) = constraintmat(joint) * g(joint, body2.state, λ, Δt)

### Constraints and derivatives
## Discrete-time position wrappers (for dynamics)
g(joint::Joint, statea::State, stateb::State, λ, Δt) = g(joint, posargs3(statea, Δt)..., posargs3(stateb, Δt)..., λ)
g(joint::Joint, stateb::State, λ, Δt) = g(joint, posargs3(stateb, Δt)..., λ)

@inline function ∂g∂ʳself(joint::Joint{T,N}, λ) where {T,N}
    return 1e-10 * sones(T,N)
end

## Discrete-time position derivatives (for dynamics)
# Wrappers 1

@inline ∂g∂posa(joint::Joint, body1::Body, body2::Body, λ, Δt) = ∂g∂posa(joint, posargs3(body1.state, Δt)..., posargs3(body2.state, Δt)..., λ)
@inline ∂g∂posb(joint::Joint, body1::Body, body2::Body, λ, Δt) = ∂g∂posb(joint, posargs3(body1.state, Δt)..., posargs3(body2.state, Δt)..., λ)
@inline ∂g∂posb(joint::Joint, body1::Origin, body2::Body, λ, Δt) = ∂g∂posb(joint, posargs3(body2.state, Δt)..., λ)

# Wrappers 2
∂g∂ʳposa(joint::Joint, statea::State, stateb::State, λ, Δt) = ∂g∂ʳposa(joint, posargs2(statea)..., posargs2(stateb)..., λ)
∂g∂ʳposb(joint::Joint, statea::State, stateb::State, λ, Δt) = ∂g∂ʳposb(joint, posargs2(statea)..., posargs2(stateb)..., λ)
∂g∂ʳposb(joint::Joint, stateb::State, λ, Δt) = ∂g∂ʳposb(joint, posargs2(stateb)..., λ)

# Derivatives accounting for quaternion specialness
@inline function ∂g∂ʳposa(joint::Joint, xa::AbstractVector, qa::UnitQuaternion, xb::AbstractVector, qb::UnitQuaternion, λ)
    X, Q = ∂g∂posa(joint, xa, qa, xb, qb, λ)
    Q = Q * LVᵀmat(qa)

    return [X Q]
end
@inline function ∂g∂ʳposb(joint::Joint, xa::AbstractVector, qa::UnitQuaternion, xb::AbstractVector, qb::UnitQuaternion, λ)
    X, Q = ∂g∂posb(joint, xa, qa, xb, qb, λ)
    Q = Q * LVᵀmat(qb)

    return [X Q]
end
@inline function ∂g∂ʳposb(joint::Joint, xb::AbstractVector, qb::UnitQuaternion, λ)
    X, Q = ∂g∂posb(joint, xb, qb, λ)
    Q = Q * LVᵀmat(qb)

    return [X Q]
end

# Wrappers 2
∂g∂ʳvela(joint::Joint, statea::State, stateb::State, λ, Δt) = ∂g∂ʳvela(joint, posargs3(statea, Δt)..., posargs3(stateb, Δt)..., fullargssol(statea)..., λ, Δt)
∂g∂ʳvelb(joint::Joint, statea::State, stateb::State, λ, Δt) = ∂g∂ʳvelb(joint, posargs3(statea, Δt)..., posargs3(stateb, Δt)..., fullargssol(stateb)..., λ, Δt)
∂g∂ʳvelb(joint::Joint, stateb::State, λ, Δt) = ∂g∂ʳvelb(joint, posargs3(stateb, Δt)..., fullargssol(stateb)..., λ, Δt)
# offdiagonal∂damper∂ʳvel(joint::Joint, statea::State, stateb::State) = offdiagonal∂damper∂ʳvel(joint, posargs2(statea)..., posargs2(stateb)..., λ)
# offdiagonal∂damper∂ʳvel(joint::Joint, stateb::State) = offdiagonal∂damper∂ʳvel(joint, posargs2(stateb)..., λ)

# Derivatives accounting for quaternion specialness
@inline function ∂g∂ʳvela(joint::Joint, x2a::AbstractVector, q2a::UnitQuaternion, x2b::AbstractVector, q2b::UnitQuaternion,
        x1a::AbstractVector, v1a::AbstractVector, q1a::UnitQuaternion, ω1a::AbstractVector, λ, Δt,
    )

    X, Q = ∂g∂posa(joint, x2a, q2a, x2b, q2b, λ)
    V = X * Δt
    Ω = Q * Lmat(q1a) * derivωbar(ω1a, Δt) * Δt / 2

    return [V Ω]
end
@inline function ∂g∂ʳvelb(joint::Joint, x2a::AbstractVector, q2a::UnitQuaternion, x2b::AbstractVector, q2b::UnitQuaternion,
        x1b::AbstractVector, v1b::AbstractVector, q1b::UnitQuaternion, ω1b::AbstractVector, λ, Δt
    )

    X, Q = ∂g∂posb(joint, x2a, q2a, x2b, q2b, λ)
    V = X * Δt
    Ω = Q * Lmat(q1b) * derivωbar(ω1b, Δt) * Δt / 2

    return [V Ω]
end
@inline function ∂g∂ʳvelb(joint::Joint, x2b::AbstractVector, q2b::UnitQuaternion,
        x1b::AbstractVector, v1b::AbstractVector, q1b::UnitQuaternion, ω1b::AbstractVector, λ, Δt
    )

    X, Q = ∂g∂posb(joint, x2b, q2b, λ)
    V = X * Δt
    Ω = Q * Lmat(q1b) * derivωbar(ω1b, Δt) * Δt / 2

    return [V Ω]
end

### Force derivatives (for linearization)
## Forcing
@inline function setForce!(joint::Joint, Fτ::SVector)
    joint.Fτ = zerodimstaticadjoint(nullspacemat(joint)) * Fτ
    return
end
@inline setForce!(joint::Joint) = return


@inline function addForce!(joint::Joint, Fτ::SVector)
    joint.Fτ += zerodimstaticadjoint(nullspacemat(joint)) * Fτ
    return
end
@inline addForce!(joint::Joint) = return

## Derivative wrappers
@inline function ∂Fτ∂ua(joint::Joint, body1::Body, body2::Body, Δt, childid)
    return ∂Fτ∂ua(joint, body1.state, body2.state, Δt) * zerodimstaticadjoint(nullspacemat(joint))
end
@inline function ∂Fτ∂ub(joint::Joint, body1::Body, body2::Body, Δt, childid)
    if body2.id == childid
        return ∂Fτ∂ub(joint, body1.state, body2.state, Δt) * zerodimstaticadjoint(nullspacemat(joint))
    else
        return ∂Fτ∂ub(joint)
    end
end
@inline function ∂Fτ∂ub(joint::Joint, body1::Origin, body2::Body, Δt, childid)
    if body2.id == childid
        return return ∂Fτ∂ub(joint, body2.state, Δt) * zerodimstaticadjoint(nullspacemat(joint))
    else
        return ∂Fτ∂ub(joint)
    end
end

@inline ∂Fτ∂ub(joint::Joint{T,N}) where {T,N} = szeros(T, 6, 3 - N) # TODO zero function?


### Minimal coordinates
@inline minimalCoordinates(joint::Joint{T,N}) where {T,N} = szeros(T, 3 - N)
