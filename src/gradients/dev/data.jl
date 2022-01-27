################################################################################
# Dimension
################################################################################
# Mechanism
data_dim(mechanism::Mechanism; attjac::Bool=true) =
	sum(Vector{Int64}(data_dim.(mechanism.joints))) +
    sum(Vector{Int64}(data_dim.(mechanism.bodies, attjac=attjac))) +
	sum(Vector{Int64}(data_dim.(mechanism.contacts)))
# Joints
data_dim(joint::JointConstraint) = 2 + sum(data_dim.(joint.constraints)) # [utra, urot, spring, damper]
data_dim(joint::Rotational{T,Nλ,Nb,N,Nb½,N̄λ}) where {T,Nλ,Nb,N,Nb½,N̄λ} = N̄λ # [u, spring, damper]
data_dim(joint::Translational{T,Nλ,Nb,N,Nb½,N̄λ}) where {T,Nλ,Nb,N,Nb½,N̄λ} = N̄λ # [u, spring, damper]
# Body
data_dim(body::Body; attjac::Bool=true) = attjac ? 19 : 20 # 1+6+6+6 or 1+6+6+7 [m,flat(J),v15,ϕ15,x2,q2] with attjac
# Contact
data_dim(contact::ContactConstraint) = sum(data_dim.(contact.constraints))
data_dim(bound::NonlinearContact) = 7 # [cf, p, offset]
data_dim(bound::LinearContact) = 7 # [cf, p, offset]
data_dim(bound::ImpactContact) = 6 # [p, offset]


################################################################################
# Attitude Jacobian
################################################################################
# Mechanism
function data_attitude_jacobian(mechanism::Mechanism)
	attjacs = [data_attitude_jacobian.(mechanism.joints);
		data_attitude_jacobian.(mechanism.bodies);
		data_attitude_jacobian.(mechanism.contacts)]
	attjac = cat(attjacs..., dims=(1,2))
	return attjac
end
# Joints
function data_attitude_jacobian(joint::JointConstraint)
	return I(data_dim(joint))
end
# Body
function data_attitude_jacobian(body::Body)
	# [m,flat(J),x1,q1,x2,q2]
	x2, q2 = current_configuration(body.state)
	attjac = cat(I(1+6+6+3), LVᵀmat(q2), dims=(1,2))
	return attjac
end
# Contacts
function data_attitude_jacobian(contact::ContactConstraint)
	return I(data_dim(contact))
end


################################################################################
# Get Data
################################################################################
# Mechanism
get_data(mechanism::Mechanism) = vcat([get_data.(mechanism.joints);
	get_data.(mechanism.bodies); get_data.(mechanism.contacts)]...)
# Joints
function get_data(joint::JointConstraint)
	joints = joint.constraints
	u = vcat(nullspace_mask.(joints) .* getfield.(joints, :Fτ)...)
	spring = joints[1].spring # assumes we have the same spring and dampers for translational and rotational joint.
	damper = joints[1].damper # assumes we have the same spring and dampers for translational and rotational joint.
	return [u; spring; damper]
end
# Body
function get_data(body::Body)
	m = body.m
	j = flatten_inertia(body.J)
	v15 = body.state.v15
	ϕ15 = body.state.ϕ15
	x2, q2 = current_configuration(body.state)
	return [m; j; v15; ϕ15; x2; vector(q2)]
end
# Contacts
get_data(bound::NonlinearContact) = [bound.cf; bound.offset; bound.p]
get_data(bound::LinearContact) = [bound.cf; bound.offset; bound.p]
get_data(bound::ImpactContact) = [bound.offset; bound.p]
get_data(contact::ContactConstraint) = vcat(get_data.(contact.constraints)...)


################################################################################
# Set Data
################################################################################
# Mechanism
function set_data!(mechanism::Mechanism, data::AbstractVector)
	# It's important to treat bodies before eqcs
	# set_data!(body) will erase state.F2[1] and state.τ2[1]
	# set_data!(eqc) using applyFτ!, will write in state.F2[1] and state.τ2[1]
	c = 0
	for joint in mechanism.joints
		Nd = data_dim(joint)
		set_data!(joint, data[c .+ (1:Nd)]); c += Nd
	end
	for body in mechanism.bodies
		Nd = data_dim(body, attjac=false)
		set_data!(body, data[c .+ (1:Nd)], mechanism.timestep); c += Nd
	end
	for contact in mechanism.contacts
		Nd = data_dim(contact)
		set_data!(contact, data[c .+ (1:Nd)]); c += Nd
	end
	for joint in mechanism.joints
		apply_input!(joint, mechanism, false)
	end
	return nothing
end
 # Joints
function set_data!(joint::JointConstraint, data::AbstractVector)
	nu = control_dimension(joint)
	u = data[SUnitRange(1,nu)]
	spring = data[nu+1]
	damper = data[nu+2]

	set_input!(joint, u)
	for joint in joint.constraints
		joint.spring = spring
		joint.damper = damper
	end
	return nothing
end
# Body
function set_data!(body::Body, data::AbstractVector, timestep)
	# [m,flat(J),x2,v15,q2,ϕ15]
	m = data[1]
	J = lift_inertia(data[SUnitRange(2,7)])
	v15 = data[SUnitRange(8,10)]
	ϕ15 = data[SUnitRange(11,13)]
	x2 = data[SUnitRange(14,16)]
	q2 = UnitQuaternion(data[17:20]..., false)
	x1 = next_position(x2, -v15, timestep)
	q1 = next_orientation(q2, -ϕ15, timestep)

	body.m = m
	body.J = J
	body.state.x1 = x1
	body.state.v15 = v15
	body.state.q1 = q1
	body.state.ϕ15 = ϕ15
	body.state.x2[1] = x2
	body.state.q2[1] = q2
	body.state.F2[1] = SVector{3}(0,0,0.)
	body.state.τ2[1] = SVector{3}(0,0,0.)
	return nothing
end
# Contact
function set_data!(bound::NonlinearContact, data::AbstractVector)
	bound.cf = data[1]
    bound.offset = data[SVector{3,Int}(2:4)]
    bound.p = data[SVector{3,Int}(5:7)]
    return nothing
end
function set_data!(bound::LinearContact, data::AbstractVector)
	bound.cf = data[1]
    bound.offset = data[SVector{3,Int}(2:4)]
    bound.p = data[SVector{3,Int}(5:7)]
    return nothing
end
function set_data!(bound::ImpactContact, data::AbstractVector)
    bound.offset = data[SVector{3,Int}(1:3)]
    bound.p = data[SVector{3,Int}(4:6)]
    return nothing
end
function set_data!(contact::ContactConstraint, data::AbstractVector)
    c = 0
	for bound in contact.constraints
		N = data_dim(bound)
        set_data!(bound, data[c .+ (1:N)]); c += N
    end
    return nothing
end
