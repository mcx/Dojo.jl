function get_twister(; 
    timestep=0.01, 
    input_scaling=timestep, 
    gravity=-9.81, 
    num_bodies=5,
    height=1, 
    radius=0.05,
    color=RGBA(1, 0, 0),
    springs=0, 
    dampers=0, 
    limits=false,
    joint_limits=Dict(),
    joint_type=:Prismatic, 
    keep_fixed_joints=false, 
    friction_coefficient=0.8,
    contact=true,
    contact_type=:nonlinear,  
    T=Float64)

    # mechanism
    origin = Origin{T}()

    bodies = [Box(height, 3 * radius, 2 * radius, height; color) for i = 1:num_bodies]

    jointb1 = JointConstraint(Floating(origin, bodies[1]))

    axes = [X_AXIS, Y_AXIS, Z_AXIS]
    joints = [
        jointb1;
        [
            JointConstraint(Prototype(joint_type, bodies[i - 1], bodies[i], axes[i%3+1]; 
            parent_vertex=-X_AXIS*height/2, child_vertex=X_AXIS*height/2)) for i = 2:num_bodies
        ]
    ]

    mechanism = Mechanism(origin, bodies, joints;
        gravity, timestep, input_scaling)

    # springs and dampers
    set_springs!(mechanism.joints, springs)
    set_dampers!(mechanism.joints, dampers)

    # joint limits    
    if limits
        joints = set_limits(mechanism, joint_limits)

        mechanism = Mechanism(mechanism.origin, mechanism.bodies, joints;
            gravity, timestep, input_scaling)
    end

    # contacts
    origin = mechanism.origin
    bodies = mechanism.bodies
    joints = mechanism.joints
    contacts = ContactConstraint{T}[]

    if contact
        n = num_bodies
        normal = [Z_AXIS for i = 1:n]
        friction_coefficient = friction_coefficient * ones(n)
        contacts1 = contact_constraint(bodies[1], normal[1]; 
        friction_coefficient=friction_coefficient[1], 
            contact_origin=X_AXIS*height/2, 
            contact_type) # to avoid duplicating the contact points
        contacts2 = contact_constraint(bodies, normal;
            friction_coefficient, 
            contact_origins=fill(X_AXIS*height/2, n), 
            contact_type)
        contacts = [contacts1; contacts2]
    end

    mechanism = Mechanism(origin, bodies, joints, contacts; 
        gravity, timestep, input_scaling)

    # zero configuration
    initialize_twister!(mechanism)

    # construction finished
    return mechanism
end

function initialize_twister!(mechanism::Mechanism)

    zero_velocity!(mechanism)
    zero_coordinates!(mechanism)

    return
end
