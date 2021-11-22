"""
$(TYPEDEF)

A `Body` is a component of a [`Mechanism`](@ref).
# Important attributes
* `id`:    The unique ID of a body. Assigned when added to a `Mechanism`.
* `name`:  The name of a body. The name is taken from a URDF or can be assigned by the user.
* `m`:     The mass of a body.
* `J`:     The inertia of a body.
* `state`: The state of a body. Contains all position and velocity information (see [`State`](@ref)).
* `shape`: The visualization shape of a body (see [`Shape`](@ref)).

# Constructors
    Body(m, J; name, shape)
    Mesh(path, m, J; scale, kwargs...)
    Box(x, y, z, m; kwargs...)
    Cylinder(r, h, m; kwargs...)
    Sphere(r, m; kwargs...)
    Pyramid(w, h, m; kwargs...)
"""
mutable struct Body{T} <: AbstractBody{T}
    id::Int64
    name::String

    m::T
    J::SMatrix{3,3,T,9}

    state::State{T}

    shape::Shape{T}

    parentid::Int64
    childid::Int64


    function Body(m::Real, J::AbstractArray; name::String="", shape::Shape=EmptyShape())
        T = promote_type(eltype.((m, J))...)
        new{T}(getGlobalID(), name, m, J, State{T}(), shape, 0, 0)
    end

    function Body{T}(contents...) where T
        new{T}(getGlobalID(), contents...)
    end
end

"""
$(TYPEDEF)

The `Origin` is the root of a [`Mechanism`](@ref).
# Important attributes
* `id`:    The unique ID of the origin. Assigned when added to a `Mechanism`.
* `name`:  The name of the origin. The name is taken from a URDF or can be assigned by the user.
* `shape`: The visualization shape of the origin (see [`Shape`](@ref)).

# Constructors
    Origin(; name, shape)
    Origin{Type}(; name, shape)
    Origin(body)
"""
mutable struct Origin{T} <: AbstractBody{T}
    id::Int64
    name::String

    shape::Shape{T}


    function Origin{T}(; name::String="", shape::Shape=EmptyShape()) where T
        new{T}(getGlobalID(), name, shape)
    end

    function Origin(; name::String="", shape::Shape=EmptyShape())
        Origin{Float64}(; name = name, shape = shape)
    end

    function Origin(body::Body{T}) where T
        new{T}(body.id, body.name, body.shape)
    end
end

function Base.show(io::IO, mime::MIME{Symbol("text/plain")}, body::Body{T}) where {T}
    summary(io, body)
    println(io,"")
    println(io, " id:     "*string(body.id))
    println(io, " name:   "*string(body.name))
    println(io, " m:      "*string(body.m))
    println(io, " J:      "*string(body.J))
end

function Base.show(io::IO, mime::MIME{Symbol("text/plain")}, origin::Origin{T}) where {T}
    summary(io, origin)
    println(io,"")
    println(io, " id:   "*string(origin.id))
    println(io, " name: "*string(origin.name))
end

function Base.deepcopy(b::Body{T}) where T
    contents = []
    for i = 2:getfieldnumber(b)
        push!(contents, deepcopy(getfield(b, i)))
    end

    return Body{T}(contents...)
end

Base.length(::Body) = 6
Base.zero(::Body{T}) where T = szeros(T,6,6)

@inline getM(body::Body{T}) where T = [[I*body.m;szeros(T,3,3)] [szeros(T,3,3);body.J]]



# Derivatives for linearizations
function ∂F∂z(body::Body{T}, Δt::T; attjac::Bool = true) where T
    state = body.state
    Z3 = szeros(T,3,3)
    Z34 = szeros(T,3,4)
    ZT = attjac ? szeros(T,6,6) : szeros(T,6,7)
    ZR = szeros(T,7,6)

    AposT = [-I Z3]
    AvelT = [Z3 -I*body.m] # solving for impulses

    AposR = attjac ?
        [-Rmat(ωbar(state.ϕ15, Δt)*Δt/2)*LVᵀmat(state.q1) -Lmat(state.q1)*derivωbar(state.ϕ15, Δt)*Δt/2] :
        [-Rmat(ωbar(state.ϕ15, Δt)*Δt/2)                  -Lmat(state.q1)*derivωbar(state.ϕ15, Δt)*Δt/2]

    J = body.J
    ω1 = state.ϕ15
    sq1 = sqrt(4 / Δt^2 - ω1' * ω1)
    ω1func = -skewplusdiag(-ω1, sq1) * J + J * ω1 * (ω1' / sq1) - skew(J * ω1)
    AvelR = attjac ? [Z3 ω1func*Δt] : [Z34 ω1func*Δt] # solving for impulses

    return [[AposT;AvelT] ZT;
             ZR [AposR;AvelR]]
end

function ∂F∂u(body::Body{T}, Δt) where T
    Z3 = szeros(T,3,3)
    Z43 = szeros(T,4,3)


    BposT = [Z3 Z3] # TODO is there a UniformScaling way for this instead of E3?

    BvelT = [-I Z3]

    BposR = [Z43 Z43]

    BvelR = [Z3 -2.0*I]


    return [BposT;BvelT;BposR;BvelR]
end

mech = getmechanism(:hopper)
Δt = mech.Δt
body1 = collect(mech.bodies)[1]
∂F∂z(body1, Δt)
∂F∂z(body1, Δt, attjac = true)
∂F∂z(body1, Δt, attjac = false)


A = ones(3,7)
B = zeros(4,7)
[A; B]
a = 10
a = 10
a = 10
a = 10
a = 10
a = 10

function ∂F∂fz(body::Body{T}, Δt) where T
    state = body.state
    Z3 = szeros(T,3,3)
    Z34 = szeros(T,3,4)
    Z43 = szeros(T,4,3)
    Z67 = szeros(T,6,7)
    Z76 = szeros(T,7,6)


    AposT = [I Z3]

    AvelT = [Z3 I*body.m/Δt]

    AposR = [I Z43]

    J = body.J
    ω2 = state.ϕsol[2]
    sq2 = sqrt(4 / Δt^2 - ω2' * ω2)
    ω2func = skewplusdiag(ω2, sq2) * J - J * ω2 * (ω2' / sq2) - skew(J * ω2)
    AvelR = [Z34 ω2func]


    return [[AposT;AvelT] Z67;Z76 [AposR;AvelR]], [I Z3 Z34 Z3;Z3 I Z34 Z3;Z3 Z3 VLᵀmat(state.qsol[2]) Z3;Z3 Z3 Z34 I]
end
