function get_raiberthopper(; 
    timestep=0.05, 
    input_scaling=timestep, 
    gravity=-9.81, 
    body_mass=4.18,
    foot_mass=0.52,
    body_radius=0.1,
    foot_radius=0.05,
    color=RGBA(0.9, 0.9, 0.9),
    springs=[0;0], 
    dampers=[0;0.1],
    limits=false,
    joint_limits=Dict(), 
    keep_fixed_joints=false, 
    contact_foot=true, 
    contact_body=true,
    T=Float64)

    # mechanism
    origin = Origin{Float64}()

    body = Sphere(body_radius, body_mass; color)
    foot = Sphere(foot_radius, foot_mass; color)
    bodies = [body, foot]

    joint_origin_body = JointConstraint(Floating(origin, body))
    joint_body_foot = JointConstraint(Prismatic(body, foot, Z_AXIS;
        parent_vertex=szeros(Float64, 3), child_vertex=szeros(Float64, 3)))
    joints = [joint_origin_body, joint_body_foot]

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

    if contact_foot
         # Contact
        contact_normal = Z_AXIS
        friction_coefficient = 0.5

        # foot
        foot_contacts = contact_constraint(foot, contact_normal; 
            friction_coefficient,
            contact_origin=[0; 0; 0], 
            contact_radius=foot_radius)

        contacts = [foot_contacts]

        # body
        if contact_body
            body_contacts = contact_constraint(body, contact_normal; 
                friction_coefficient,
                contact_origin=[0; 0; 0], 
                contact_radius=body_radius)
            push!(contacts, body_contacts)
        end
    end

    mechanism = Mechanism(origin, bodies, joints, contacts; 
        gravity, timestep, input_scaling)

    # zero configuration
    initialize_raiberthopper!(mechanism)
    
    # construction finished
    return mechanism
end

function initialize_raiberthopper!(mechanism::Mechanism; 
    body_position=zeros(3), leg_length=0.5)

    zero_velocity!(mechanism)
    zero_coordinates!(mechanism)

    body_position += [0;0;leg_length+mechanism.bodies[2].shape.r]
    set_minimal_coordinates!(mechanism, mechanism.joints[1], [body_position; 0; 0; 0])
    set_minimal_coordinates!(mechanism, mechanism.joints[2], [-leg_length])

    return
end
