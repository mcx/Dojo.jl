function gettwister(; Δt::T=0.01, g::T=-9.81, cf::T=0.8, contact::Bool=true,
    contact_type=:contact, spring=0.0, damper=0.0, Nb::Int=5,
    jointtype::Symbol=:Prismatic, h::T=1.0, r::T=0.05) where {T}
    # Parameters
    ex = [1.;0.;0.]
    ey = [0.;1.;0.]
    ez = [0.;0.;1.]
    axes = [ex, ey, ez]

    vert11 = [0.;0.;h / 2]
    vert12 = -vert11
    vert = h/2

    # Links
    origin = Origin{T}()
    bodies = [Box(3r, 2r, h, h, color = RGBA(1., 0., 0.)) for i = 1:Nb]

    # Constraints
    jointb1 = JointConstraint(Floating(origin, bodies[1], spring = 0.0, damper = 0.0)) # TODO remove the spring and damper from floating base
    if Nb > 1
        eqcs = [JointConstraint(Prototype(jointtype, bodies[i - 1], bodies[i], axes[i%3+1]; p1 = vert12, p2 = vert11, spring = spring, damper = damper)) for i = 2:Nb]
        # eqcs = [JointConstraint(Prototype(jointtype, bodies[i - 1], bodies[i], axes[1]; p1 = vert12, p2 = vert11, spring = spring, damper = damper)) for i = 2:Nb]
        # eqcs = [JointConstraint(Prototype(jointtype, bodies[i - 1], bodies[i], axes[3]; p1 = vert12, p2 = vert11, spring = spring, damper = damper)) for i = 2:Nb]
        eqcs = [jointb1; eqcs]
    else
        eqcs = [jointb1]
    end

    if contact
        n = Nb
        normal = [[0;0;1.0] for i = 1:n]
        cf = cf * ones(n)
        ineqcs1 = contact_constraint(bodies[1], normal[1], cf=cf[1], p=vert11, contact_type=contact_type) # to avoid duplicating the contact points
        ineqcs2 = contact_constraint(bodies, normal, cf=cf, p=fill(vert12, n), contact_type=contact_type)
        mech = Mechanism(origin, bodies, eqcs, [ineqcs1; ineqcs2], g = g, Δt = Δt)
    else
        mech = Mechanism(origin, bodies, eqcs, g = g, Δt = Δt, spring=spring, damper=damper)
    end
    return mech
end

function initializetwister!(mechanism::Mechanism{T,Nn,Ne,Nb}; x::AbstractVector{T}=[0,-1.,0],
    v::AbstractVector{T}=zeros(3), ω::AbstractVector{T}=zeros(3),
    Δω::AbstractVector{T}=zeros(3), Δv::AbstractVector{T}=zeros(3),
    q1::UnitQuaternion{T}=UnitQuaternion(RotX(0.6 * π))) where {T,Nn,Ne,Nb}

    bodies = collect(mechanism.bodies)
    body1 = bodies[1]
    h = 1.0
    vert11 = [0.;0.; h/2]
    vert12 = -vert11
    # set position and velocities
    set_position(mechanism.origin, body1, p2 = x, Δq = q1)
    set_velocity!(body1, v = v, ω = ω)

    previd = body1.id
    for (i,body) in enumerate(Iterators.drop(mechanism.bodies, 1))
        set_position(get_body(mechanism, previd), body, p1 = vert12, p2 = vert11)
        set_velocity!(get_body(mechanism, previd), body, p1 = vert12, p2 = vert11,
                Δv = Δv, Δω = Δω)
        previd = body.id
    end
end
