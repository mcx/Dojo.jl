function getcartpole(; timestep::T=0.1, g::T=-9.81, spring=0.0, damper=0.0) where T
    #TODO: make customizable
    # Parameters
    slider_axis = [0.0; 1.0; 0.0]
    pendulum_axis = [1.0; 0.0; 0.0]
    slider_length = 1.0
    pendulum_length = 1.0
    radius = 0.075
    slider_mass = 1.0
    pendulum_mass = 0.432

    # Links
    origin = Origin{Float64}()
    slider = Capsule(1.5 * radius, slider_length, slider_mass, qoffset=UnitQuaternion(RotX(0.5 * π)), color=cyan)
    pendulum = Capsule(radius, pendulum_length, pendulum_mass, color=cyan)
    links = [slider, pendulum]

    # Joint Constraints
    joint_origin_slider = JointConstraint(Prismatic(origin, slider, slider_axis; p1=szeros(Float64, 3), p2=szeros(Float64, 3)))
    joint_slider_pendulum = JointConstraint(Revolute(slider, pendulum, pendulum_axis; p1=szeros(Float64, 3), p2=[0.0; 0.0; 0.5 * pendulum_length]))
    joints = [joint_origin_slider, joint_slider_pendulum]

    # Mechanism
    mech = Mechanism(origin, links, joints, g=g, timestep=timestep, spring=spring, damper=damper)

    return mech
end

function initializecartpole!(mech::Mechanism{T,Nn,Ne,Nb}; mode=:down, pendulum_length=1.0) where {T,Nn,Ne,Nb}
    # origin to slider
    set_position(mech.origin, mech.bodies[1])
    set_velocity!(mech.bodies[1], v=[0.0; 0.0; 0.0],ω=zeros(3))

    # slider to pendulum
    if mode == :down
        set_position(mech.bodies[1], mech.bodies[2], Δx=[0.0; 0.0; -0.5 * pendulum_length], Δq=UnitQuaternion(RotX(π)))
        set_velocity!(mech.bodies[2], v=zeros(3), ω=zeros(3))
    elseif mode == :up
        set_position(mech.bodies[1], mech.bodies[2], Δx=[0.0; 0.0; 0.5 * pendulum_length], Δq=UnitQuaternion(RotX(π)))
        set_velocity!(mech.bodies[2], v=zeros(3), ω=zeros(3))
    end
end

function mujoco_inertia!(mech)
    mech.bodies[1].m = 1.0063
    mech.bodies[1].J = Diagonal([0.106974, 0.106974, 0.00636812])

    mech.bodies[2].m = 0.4321
    mech.bodies[2].J = Diagonal([0.0422274, 0.0422274, 0.0012155])
end
