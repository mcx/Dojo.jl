"""
    Atlas <: Environment

    humanoid robot designed by Boston Dynamics (v5)
"""
struct Atlas end

function atlas(; 
    representation=:minimal, 
    timestep=0.01, 
    gravity=-9.81, 
    friction_coefficient=0.8,
    dampers=0, 
    springs=0, 
    parse_dampers=true, 
    info=nothing, 
    model_type=:simple,
    seed=1, 
    contact_feet=true, 
    contact_body=false,
    vis=Visualizer(), 
    name=:robot,
    infeasible_control=false,
    opts_step=SolverOptions(rtol=3.0e-4, btol=3.0e-4, undercut=1.5),
    opts_grad=SolverOptions(rtol=3.0e-4, btol=3.0e-4, undercut=1.5),
    T=Float64)

    mechanism = get_mechanism(:atlas;
        timestep, 
        gravity, 
        friction_coefficient,
        damper,  
        spring, 
        parse_damper,
        contact_feet,
        contact_body,
        model_type)

    initialize!(mechanism, :atlas)

    if representation == :minimal
        nx = minimal_dimension(mechanism)
    elseif representation == :maximal
        nx = maximal_dimension(mechanism)
    end
    nu_inf = input_dimension(mechanism)
    nu = infeasible_control ? nu_inf : nu_inf - 6 # remove first 6 controls
    no = nx

    aspace = BoxSpace(nu, 
        low=(-1.0e8 * ones(nu)), 
        high=(1.0e8 * ones(nu)))
    ospace = BoxSpace(no, 
        low=(-Inf * ones(no)), 
        high=(Inf * ones(no)))

    rng = MersenneTwister(seed)
    z = get_maximal_state(mechanism)
    x = representation == :minimal ? maximal_to_minimal(mechanism, z) : z
    fx = zeros(nx, nx)
    fu = zeros(nx, nu)

    u_prev = zeros(nu)
    control_mask = infeasible_control ? I(nu) : [zeros(nu, 6) I(nu)]
    control_scaling = Diagonal(ones(nu))

    build_robot(mechanism, vis=vis, name=name)

    TYPES = [Atlas, T, typeof(mechanism), typeof(aspace), typeof(ospace), typeof(info)]
    Environment{TYPES...}(mechanism, representation, aspace, ospace,
        x, fx, fu,
        u_prev, control_mask' * control_scaling,
        nx, nu, no,
        info,
        [rng], vis,
        opts_step, opts_grad)
end






################################################################################
# Quadruped Trajectory Generator
################################################################################

# Trajectory template
function low_foot_trajectory(r::T, N::Int) where T
	# r = radius of the foot traj
	# low foot trajectory decomposed into N steps (N+1 waypoints)
	X = Vector(range(-r, r, length = N+1))
	low_traj = [[x, 0, 0] for x in X]
	return low_traj
end

function high_foot_trajectory(r::T, β::T, N::Int) where T
	# high foot trajectory decomposed into N steps (N+1 waypoints)
	α = range(0, π, length = N+1)
	θ = π * (1 .- cos.(α)) / 2
	X = [r*cos(θi) for θi in θ]
	Z = [β*r*sin(θi) for θi in θ] # the facto 2 flatten the foo trajectory
	high_traj = [[X[i], 0, Z[i]] for i = 1:N+1]
	return high_traj
end

function foot_trajectory(r::T, β::T, N::Int) where T
	low_traj = low_foot_trajectory(r, N)
	high_traj = high_foot_trajectory(r, β, N)
	traj = [low_traj[1:end-1]; high_traj[1:end-1]]
	return traj
end

# Inverse kinematics: given the position of the first link, finds the knee and hip angles that will put the foot
# at the p_foot location
function IKatlas(mechanism::Mechanism, p_base, p_foot; leg::Symbol = :r)
	# starting point of the local search
	θ = [0.5, 1] # θhip, θknee
	for k = 1:10
		err = AtlasIKerror(mechanism, p_base, p_foot, θ; leg = leg)
		norm(err, Inf) < 1e-10 && continue
		∇ = FiniteDiff.finite_difference_jacobian(θ -> AtlasIKerror(mechanism, p_base, p_foot, θ; leg = leg), θ)
		θ -= ∇ \ err
	end
	return θ
end

function AtlasIKerror(mechanism::Mechanism, p_base, p_foot, θ; leg::Symbol = :r)
	set_minimal_coordinates!(mechanism, get_joint(mechanism, :floating_base), [p_base; zeros(3)])
	set_minimal_coordinates!(mechanism, get_joint(mechanism, Symbol(leg, :_leg_hpxyz)), [0, -θ[1], 0])
	set_minimal_coordinates!(mechanism, get_joint(mechanism, Symbol(leg, :_leg_kny)), [θ[2]])
	set_minimal_coordinates!(mechanism, get_joint(mechanism, Symbol(leg, :_leg_akxy)), [θ[1]-θ[2], 0])

	foot = get_body(mechanism, Symbol(leg, :_foot))
	foot_contacts = mechanism.contacts[findall(x -> x.parent_id == foot.id, mechanism.contacts)]
	p = mean([contact_location(contact, foot) for contact in foot_contacts]) # average of all contact locations for one foot
	err = p - p_foot
	return err[[1,3]]
end

function atlas_trajectory(mechanism::Mechanism{T}; timestep=0.05, β=0.5,
		αtorso=0.15, Δx=0, r=0.10, x=0.00, z=0.85, N=12, Ncycles=1) where T
	pL = [Δx, + 0.1145, 0]
	pR = [Δx, - 0.1145, 0]

	t = reverse(foot_trajectory(r, β, N))
	t_dephased = [t[N+1:2N]; t[1:N]]
	# Foot positions
	tL = [pL + ti for ti in t_dephased]
	tR = [pR + ti for ti in t]

	# Leg angles
	p_base = [x,0,z]
	θL = [IKatlas(mechanism, p_base, tL[i], leg = :l) for i = 1:2N]
	θR = [IKatlas(mechanism, p_base, tR[i], leg = :r) for i = 1:2N]

	# adding angular velocities
	ωL = [(θL[i%(2N)+1] - θL[i]) / timestep for i = 1:2N]
	ωR = [(θR[i%(2N)+1] - θR[i]) / timestep for i = 1:2N]

	# Minimal Coordinates
	nx = minimal_dimension(mechanism)
	X = [zeros(nx) for i = 1:2N]
	for i = 1:2N

		set_minimal_coordinates!(mechanism, get_joint(mechanism, :floating_base), [p_base; 0; αtorso; 0])
		set_minimal_coordinates!(mechanism, get_joint(mechanism, :back_bkxyz), [0, -αtorso, 0])
		set_minimal_coordinates!(mechanism, get_joint(mechanism, :l_leg_hpxyz), [0, -θL[i][1], 0])
		set_minimal_coordinates!(mechanism, get_joint(mechanism, :l_leg_kny), [θL[i][2]])
		set_minimal_coordinates!(mechanism, get_joint(mechanism, :l_leg_akxy), [θL[i][1]-θL[i][2], 0])

		set_minimal_coordinates!(mechanism, get_joint(mechanism, :r_leg_hpxyz), [0, -θR[i][1], 0])
		set_minimal_coordinates!(mechanism, get_joint(mechanism, :r_leg_kny), [θR[i][2]])
		set_minimal_coordinates!(mechanism, get_joint(mechanism, :r_leg_akxy), [θR[i][1]-θR[i][2], 0])

		set_minimal_velocities!(mechanism, get_joint(mechanism, :floating_base), [zeros(3); zeros(3)])
		set_minimal_velocities!(mechanism, get_joint(mechanism, :l_leg_hpxyz), [0, -ωL[i][1], 0])
		set_minimal_velocities!(mechanism, get_joint(mechanism, :l_leg_kny), [ωL[i][2]])
		set_minimal_velocities!(mechanism, get_joint(mechanism, :l_leg_akxy), [ωL[i][1]-ωL[i][2], 0])

		set_minimal_velocities!(mechanism, get_joint(mechanism, :r_leg_hpxyz), [0, -ωR[i][1], 0])
		set_minimal_velocities!(mechanism, get_joint(mechanism, :r_leg_kny), [ωR[i][2]])
		set_minimal_velocities!(mechanism, get_joint(mechanism, :r_leg_akxy), [ωR[i][1]-ωR[i][2], 0])
		X[i] .= get_minimal_state(mechanism)
	end

	X = vcat([deepcopy(X) for i = 1:Ncycles]...)
	# adding forward displacement and velocity
	for i = 1:2N*Ncycles
		X[i][1] += (i-1) * 2r / N
		X[i][7] += 2r / N / timestep
	end
	
	return X
end

function interpolate(parent_vertex, p2, N::Int)
	return [parent_vertex .+ α*(p2 - parent_vertex) for α in range(0, stop=1, length=N)]
end

function atlas_jump(mechanism::Mechanism{T}; timestep=0.05, αtorso=0, z=0.95, Δx=0, x = 0,
		Ns=[5,5,5,5,5], foot_high=0.20, base_high=0.20, base_low=-0.20) where T
	N = sum(Ns)
	# Foot position
	fL = [Δx, + 0.1145, 0]
	fH = [Δx, + 0.1145, foot_high]
	# Base position
	bL = [x, 0, z+base_low]
	bM = [x, 0, z]
	bH = [x, 0, z+base_high]

	pfoot = [
		interpolate(fL, fL, Ns[1]);
		interpolate(fL, fL, Ns[2]);
		interpolate(fL, fH, Ns[3]);
		interpolate(fH, fL, Ns[4]);
		interpolate(fL, fL, Ns[5]);
		]
	pbase = [
		interpolate(bM, bL, Ns[1]);
		interpolate(bL, bM, Ns[2]);
		interpolate(bM, bH, Ns[3]);
		interpolate(bH, bL, Ns[4]);
		interpolate(bL, bM, Ns[5]);
		]

	# Leg angles
	θL = [IKatlas(mechanism, pbase[i], pfoot[i], leg=:l) for i=1:N]
	θR = [IKatlas(mechanism, pbase[i], pfoot[i], leg=:r) for i=1:N]

	# adding angular velocities
	ωL = [(θL[i%N+1] - θL[i]) / timestep for i = 1:N]
	ωR = [(θR[i%N+1] - θR[i]) / timestep for i = 1:N]

	# Minimal Coordinates
	nx = minimal_dimension(mechanism)
	X = [zeros(nx) for i = 1:N]
	for i = 1:N
		set_minimal_coordinates!(mechanism, get_joint(mechanism, :floating_base), [pbase[i]; 0; αtorso; 0])
		set_minimal_coordinates!(mechanism, get_joint(mechanism, :back_bkxyz), [0, -αtorso, 0])
		set_minimal_coordinates!(mechanism, get_joint(mechanism, :l_leg_hpxyz), [0, -θL[i][1], 0])
		set_minimal_coordinates!(mechanism, get_joint(mechanism, :l_leg_kny), [θL[i][2]])
		set_minimal_coordinates!(mechanism, get_joint(mechanism, :l_leg_akxy), [θL[i][1]-θL[i][2], 0])

		set_minimal_coordinates!(mechanism, get_joint(mechanism, :r_leg_hpxyz), [0, -θR[i][1], 0])
		set_minimal_coordinates!(mechanism, get_joint(mechanism, :r_leg_kny), [θR[i][2]])
		set_minimal_coordinates!(mechanism, get_joint(mechanism, :r_leg_akxy), [θR[i][1]-θR[i][2], 0])

		# set_minimal_velocities!(mechanism, get_joint(mechanism, :floating_base), [zeros(3); zeros(3)])
		# set_minimal_velocities!(mechanism, get_joint(mechanism, :l_leg_hpxyz), [0, -ωL[i][1], 0])
		# set_minimal_velocities!(mechanism, get_joint(mechanism, :l_leg_kny), [ωL[i][2]])
		# set_minimal_velocities!(mechanism, get_joint(mechanism, :l_leg_akxy), [ωL[i][1]-ωL[i][2], 0])
		#
		# set_minimal_velocities!(mechanism, get_joint(mechanism, :r_leg_hpxyz), [0, -ωR[i][1], 0])
		# set_minimal_velocities!(mechanism, get_joint(mechanism, :r_leg_kny), [ωR[i][2]])
		# set_minimal_velocities!(mechanism, get_joint(mechanism, :r_leg_akxy), [ωR[i][1]-ωR[i][2], 0])
		X[i] .= get_minimal_state(mechanism)
	end

	# X = vcat([deepcopy(X) for i = 1:Ncycles]...)
	# # adding forward displacement and velocity
	# for i = 1:2N*Ncycles
	# 	X[i][1] += (i-1) * 2r / N
	# 	X[i][7] += 2r / N / timestep
	# end
	return X
end


################################################################################
# Compute trajectory
################################################################################
# vis= Visualizer()
# open(vis)

# mechanism = get_mechanism(:atlas, timestep=0.05, model_type=:armless, damper=1000)
# initialize!(mechanism, :atlas, tran=[1,0,0], rot=[0,0,0.], αhip=0.5, αknee=1)
#
# @elapsed storage = simulate!(mechanism, 0.05, record=true, verbose=true)
# visualize(mechanism, storage, vis=vis)
#
# X = atlas_jump(mech; Ns=[7,4,4,8,8], timestep=0.025, Δx=0, x=0, z=1.10, foot_high=0.20, base_high=+0.20, base_low=-0.20)
# zref = [minimal_to_maximal(mechanism, x) for x in X]
# storage = generate_storage(mechanism, zref)
# visualize(mechanism, storage, vis=vis)

#
# bodies = mechanism.bodies
# joints = mechanism.joints
# contacts = collect(mechanism.contacts)
# getfield.(contacts, :parent_id)
# get_body(mechanism, 15)
# nx = minimal_dimension(mechanism)
#
#
# p_base = [0, 0, 0.9385]
# p_base = [0, 0, 0.88]
# p_foot = [0, 0, 0.00]
# θ = [0.4, 0.8]
# IKerror(mechanism, p_base, p_foot, θ; leg=:r)
# IKatlas(mechanism, p_base, p_foot; leg=:r)






# function initialize_atlas!(mechanism::Mechanism;
#     model_type=:simple,
#     body_position=[0, 0, 0.2],
#     body_orientation=[0, 0, 0],
#     link_linear_velocity=[zeros(3)  for i=1:length(mechanism.bodies)],
#     link_angular_velocity=[zeros(3) for i=1:length(mechanism.bodies)],
#     hip_orientation=0, 
#     knee_orientation=0)

#     body_position += (model_type == :armless) ? [0, 0, 0.9385 + 0.14853] : [0, 0, 0.9385]

#     # positions
#     try
#         set_minimal_coordinates!(mechanism,
#                 get_joint(mechanism, :floating_base),
#                 [body_position; body_orientation])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :back_bkxyz), [0, 0, 0])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :l_leg_hpxyz), [0, -hip_orientation, 0])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :r_leg_hpxyz), [0, -hip_orientation, 0])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :l_leg_kny), [knee_orienation])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :r_leg_kny), [knee_orienation])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :l_leg_akxy), [hip_orientation-knee_orienation, 0])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :r_leg_akxy), [hip_orientation-knee_orienation, 0])
#     catch
#         nothing
#     end

#     zero_velocity!(mechanism)

#     return nothing
# end

# function initialize_atlas_stance!(mech::Mechanism;
#     body_position=[0, 0, 0.2],
#     body_orientation=[0, 0, 0],
#     link_linear_velocity=[zeros(3)  for i=1:length(mechanism.bodies)],
#     link_angular_velocity=[zeros(3) for i=1:length(mechanism.bodies)],
#     hip_orientation=0, 
#     knee_orienation=0)
    
#     body_position += [0, 0, 0.9385]

#     # positions
#     try
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :floating_base), [body_position; body_orientation])

#         # set_minimal_coordinates!(mechanism, get_joint(mechanism, :l_leg_hpxyz), [0, -hip_orientation, 0])
#         # set_minimal_coordinates!(mechanism, get_joint(mechanism, :r_leg_hpxyz), [0, -hip_orientation, 0])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :l_leg_kny), [knee_orienation])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :r_leg_kny), [knee_orienation])
#         # set_minimal_coordinates!(mechanism, get_joint(mechanism, :l_leg_akxy), [hip_orientation - knee_orienation, 0])
#         # set_minimal_coordinates!(mechanism, get_joint(mechanism, :r_leg_akxy), [hip_orientation - knee_orienation, 0])

#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :back_bkx), [0.0  * π])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :back_bky), [0.04 * π])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :back_bkz), [0 * π])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :l_arm_elx), [0.25 * π])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :l_arm_ely), [0.5 * π])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :l_arm_shx), [-0.5 * π])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :l_arm_shz), [0 * π])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :l_arm_mwx), [0 * π])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :l_arm_uwy), [0 * π])
#         # set_minimal_coordinates!(mechanism, get_joint(mechanism, :l_arm_lwy), [0])
#         # set_minimal_coordinates!(mechanism, get_joint(mechanism, :l_leg_akx), [0])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :l_leg_aky), [-0.1 * π])
#         # set_minimal_coordinates!(mechanism, get_joint(mechanism, :l_leg_hpx), [0])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :l_leg_hpy), [-0.1 * π])
#         # set_minimal_coordinates!(mechanism, get_joint(mechanism, :l_leg_hpz), [0])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :l_leg_kny), [0.2 * π])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :neck_ay), [0])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :r_arm_elx), [-0.25 * π])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :r_arm_ely), [0.5 * π])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :r_arm_shx), [0.5 * π])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :r_arm_shz), [0 * π])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :r_arm_mwx), [0 * π])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :r_arm_uwy), [0 * π])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :r_arm_lwy), [0 * π])
#         # set_minimal_coordinates!(mechanism, get_joint(mechanism, :r_leg_akx), [0])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :r_leg_aky), [-0.1 * π])
#         # set_minimal_coordinates!(mechanism, get_joint(mechanism, :r_leg_hpx), [0])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :r_leg_hpy), [-0.1 * π])
#         # set_minimal_coordinates!(mechanism, get_joint(mechanism, :r_leg_hpz), [0 * π])
#         set_minimal_coordinates!(mechanism, get_joint(mechanism, :r_leg_kny), [0.2 * π])
#     catch
#         nothing
#     end

#     zero_velocity!(mechanism)

#     return nothing
# end