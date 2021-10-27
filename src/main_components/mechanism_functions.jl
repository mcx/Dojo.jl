"""
    getbody!(mechanism, id)

Gets the body with ID `id` from `mechanism` if it exists. If `id = nothing`, the origin will be returned.
"""
@inline getbody(mechanism::Mechanism, id::Integer) = mechanism.bodies[id]
@inline getbody(mechanism::Mechanism, id::Nothing) = mechanism.origin

"""
    getbody!(mechanism, name)

Gets the body with name `name` from `mechanism` if it exists.
"""
function getbody(mechanism::Mechanism, name::String)
    if mechanism.origin.name == name
        return mechanism.origin
    else
        for body in mechanism.bodies
            if body.name == name
                return body
            end
        end
    end
    return
end

"""
    geteqconstraint!(mechanism, id)

Gets the equality constraint with ID `id` from `mechanism` if it exists.
"""
@inline geteqconstraint(mechanism::Mechanism, id::Integer) = mechanism.eqconstraints[id]

"""
    geteqconstraint!(mechanism, name)

Gets the equality constraint with name `name` from `mechanism` if it exists.
"""
function geteqconstraint(mechanism::Mechanism, name::String)
    for eqc in mechanism.eqconstraints
        if eqc.name == name
            return eqc
        end
    end
    return
end

@inline getineqconstraint(mechanism::Mechanism, id::Integer) = mechanism.ineqconstraints[id]
function getineqconstraint(mechanism::Mechanism, name::String)
    for ineqc in mechanism.ineqconstraints
        if ineqc.name == name
            return ineqc
        end
    end
    return
end

@inline getfriction(mechanism::Mechanism, id::Integer) = mechanism.frictions[id]
function getfriction(mechanism::Mechanism, name::String)
    for friction in mechanism.frictions
        if friction.name == name
            return friction
        end
    end
    return
end

"""
    getcomponent(mechanism, id)

Gets the component (body or equality constraint) with ID `id` from `mechanism` if it exists.
"""
function getcomponent(mechanism::Mechanism{T,Nn,Ne,Nb,Nf}, id::Integer) where {T,Nn,Ne,Nb,Nf}
    if id <= Ne
        return geteqconstraint(mechanism, id)
    elseif id <= Ne+Nb
        return getbody(mechanism, id)
    elseif id <= Ne+Nb+Nf
        return getfriction(mechanism, id)
    else
        return getineqconstraint(mechanism, id)
    end
end
getcomponent(mechanism::Mechanism, id::Nothing) = mechanism.origin

"""
    getcomponent!(mechanism, name)

Gets the component (body or equality constraint) with name `name` from `mechanism` if it exists.
"""
function getcomponent(mechanism::Mechanism, name::String)
    component = getbody(mechanism,name)
    if component === nothing
        component = geteqconstraint(mechanism,name)
    end
    if component === nothing
        component = getineqconstraint(mechanism,name)
    end
    if component === nothing
        component = getfriction(mechanism,name)
    end
    return component
end

@inline function normf(mechanism::Mechanism, component::Component)
    f = g(mechanism, component)
    return dot(f, f)
end

@inline function normf(mechanism::Mechanism, ineqc::InequalityConstraint)
    f1 = complementarity(mechanism, ineqc)
    f2 = gs(mechanism, ineqc)
    # @show ineqc.ssol[2]
    # @show ineqc.γsol[2]
    # @show norm(f1, Inf)
    # @show norm(f2, Inf)
    return dot(f1, f1) + dot(f2, f2)
end

@inline function normfμ(mechanism::Mechanism, ineqc::InequalityConstraint)
    f1 = complementarityμ(mechanism, ineqc)
    f2 = gs(mechanism, ineqc)
    # @show ineqc.ssol[2]
    # @show ineqc.γsol[2]
    # @show mechanism.μ
    # @show norm(f1, Inf)
    # @show norm(f2, Inf)
    return dot(f1, f1) + dot(f2, f2)
end

@inline function normf(mechanism::Mechanism)
    mechanism.normf = 0

    foreach(addNormf!, mechanism.eqconstraints, mechanism)
    foreach(addNormf!, mechanism.bodies, mechanism)
    foreach(addNormf!, mechanism.frictions, mechanism)
    foreach(addNormf!, mechanism.ineqconstraints, mechanism)

    return sqrt(mechanism.normf)
end

@inline function meritf(mechanism::Mechanism)
    mechanism.normf = 0

    foreach(addNormf!, mechanism.eqconstraints, mechanism)
    foreach(addNormf!, mechanism.bodies, mechanism)
    foreach(addNormf!, mechanism.frictions, mechanism)
    foreach(addNormfμ!, mechanism.ineqconstraints, mechanism)

    return sqrt(mechanism.normf)
end

@inline function normΔs(mechanism::Mechanism)
    mechanism.normΔs = 0

    foreach(addNormΔs!, mechanism.eqconstraints, mechanism)
    foreach(addNormΔs!, mechanism.bodies, mechanism)
    foreach(addNormΔs!, mechanism.frictions, mechanism)
    foreach(addNormΔs!, mechanism.ineqconstraints, mechanism)

    return sqrt(mechanism.normΔs)
end

@inline function addNormf!(component::Component, mechanism::Mechanism)
    mechanism.normf += normf(mechanism, component)
    return
end

@inline function addNormfμ!(ineqc::InequalityConstraint, mechanism::Mechanism)
    mechanism.normf += normfμ(mechanism, ineqc)
    return
end

@inline function addNormΔs!(component::Component, mechanism::Mechanism)
    mechanism.normΔs += normΔs(component)
    return
end

@inline function discretizestate!(mechanism::Mechanism)
    foreach(discretizestate!, mechanism.bodies, mechanism.Δt)
    return
end

@inline function residual_violation(mechanism::Mechanism)
    mechanism.rvio = 0

    foreach(residual_violation!, mechanism.eqconstraints, mechanism)
    foreach(residual_violation!, mechanism.bodies, mechanism)
    foreach(residual_violation!, mechanism.ineqconstraints, mechanism)

    return mechanism.rvio
end

@inline function residual_violation!(component::Component, mechanism::Mechanism)
    res = g(mechanism, component)
    # if norm(res, Inf) > 7e-1
        # println("res:", scn.(abs.(res), digits = 6), typeof(component).name)
    # end
    mechanism.rvio = max(mechanism.rvio, norm(res, Inf))
    return nothing
end

@inline function residual_violation!(ineqc::InequalityConstraint, mechanism::Mechanism)
    res = gs(mechanism, ineqc)
    # if norm(res, Inf) > 7e-1
        # println("res:", scn.(abs.(res), digits = 6), typeof(ineqc.constraints[1]).name)
    # end
    mechanism.rvio = max(mechanism.rvio, norm(res, Inf))
    return nothing
end


@inline function bilinear_violation(mechanism::Mechanism)
    mechanism.bvio = 0

    foreach(bilinear_violation!, mechanism.ineqconstraints, mechanism)

    return mechanism.bvio
end

function bilinear_violation!(ineqc::InequalityConstraint, mechanism::Mechanism)
    comp = complementarity(mechanism, ineqc)
    mechanism.bvio = max(mechanism.bvio, norm(comp, Inf))
    return nothing
end


@inline function ∂gab∂ʳba(mechanism::Mechanism{T,Nn,Ne,Nb,Nf,Ni}, body1::Body, body2::Body) where {T,Nn,Ne,Nb,Nf,Ni}
    Δt = mechanism.Δt
    _, _, q1, ω1 = fullargssol(body1.state)
    _, _, q2, ω2 = fullargssol(body2.state)
    M1 = ∂integration(q1, ω1, Δt)
    M2 = ∂integration(q2, ω2, Δt)


    x1, q1 = posargsnext(body1.state, Δt)
    x2, q2 = posargsnext(body2.state, Δt)

    dGab = zeros(6,6)
    dGba = zeros(6,6)

    for connectionid in connections(mechanism.system, body1.id)
        !(connectionid <= Ne) && continue # body
        eqc = getcomponent(mechanism, connectionid)
        Nc = length(eqc.childids)
        off = 0
        if body1.id == eqc.parentid
            for i in 1:Nc
                joint = eqc.constraints[i]
                Nj = length(joint)
                if body2.id == eqc.childids[i]
                    Aᵀ = zerodimstaticadjoint(constraintmat(joint))
                    dGab -= _dGab(joint, x1, q1, x2, q2, Aᵀ * eqc.λsol[2][off .+ (1:Nj)]) * M2
                    dGba -= _dGba(joint, x1, q1, x2, q2, Aᵀ * eqc.λsol[2][off .+ (1:Nj)]) * M1
                    # eqc.isspring && (dGab -= ∂springforcea∂velb(joint, body1, body2, Δt))
                    eqc.isdamper && (dGab -= ∂damperforcea∂velb(joint, body1, body2, Δt))
                    # eqc.isspring && (dGba -= ∂springforceb∂vela(joint, body1, body2, Δt))
                    eqc.isdamper && (dGba -= ∂damperforceb∂vela(joint, body1, body2, Δt))
                end
                off += Nj
            end
        elseif body2.id == eqc.parentid
            for i = 1:Nc
                joint = eqc.constraints[i]
                Nj = length(joint)
                if body1.id == eqc.childids[i]
                    Aᵀ = zerodimstaticadjoint(constraintmat(joint))
                    dGab -= _dGab(joint, x2, q2, x1, q1, Aᵀ * eqc.λsol[2][off .+ (1:Nj)]) * M1
                    dGba -= _dGba(joint, x2, q2, x1, q1, Aᵀ * eqc.λsol[2][off .+ (1:Nj)]) * M2
                    # eqc.isspring && (dGab -= ∂springforcea∂velb(joint, body2, body1, Δt))
                    eqc.isdamper && (dGab -= ∂damperforcea∂velb(joint, body2, body1, Δt))
                    # eqc.isspring && (dGba -= ∂springforceb∂vela(joint, body2, body1, Δt))
                    eqc.isdamper && (dGba -= ∂damperforceb∂vela(joint, body2, body1, Δt))
                end
                off += Nj
            end
        end
    end
    return dGab, dGba
end
