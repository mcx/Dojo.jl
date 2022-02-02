function transform(x, q, shape)
    scale_transform = MeshCat.LinearMap(diagm(shape.scale))
    x_transform = MeshCat.Translation(x + vrotate(shape.xoffset, q))
    q_transform = MeshCat.LinearMap(q * shape.qoffset)
    return MeshCat.compose(x_transform, q_transform, scale_transform)
end

MeshCat.js_scaling(s::AbstractVector) = s
MeshCat.js_position(p::AbstractVector) = p

function prepare_vis!(storage::Storage{T,N}, id, shape, animation, shapevisualizer, framevisualizer, showshape, showframes) where {T,N}
    if showshape
        for i=1:N
            x = storage.x[id][i]
            q = storage.q[id][i]
            # TODO currently setting props directly because MeshCat/Rotations doesn't convert scaled rotation properly.
            # If this changes, do similarily to origin
            atframe(animation, i) do
                setprop!(shapevisualizer, "scale", MeshCat.js_scaling(shape.scale))
                setprop!(shapevisualizer, "position", MeshCat.js_position(x + vrotate(shape.xoffset, q)))
                setprop!(shapevisualizer, "quaternion", MeshCat.js_quaternion(q * shape.qoffset))
            end
        end
    end

    if showframes
        for i=1:N
            x = storage.x[id][i]
            q = storage.q[id][i]
            atframe(animation, i) do
                setprop!(framevisualizer, "scale", MeshCat.js_scaling(SA{T}[1;1;1]))
                setprop!(framevisualizer, "position", MeshCat.js_position(x))
                setprop!(framevisualizer, "quaternion", MeshCat.js_quaternion(q))
            end
        end
    end

    return
end

function MeshCat.setobject!(subvisshape, visshape, shapes::Shapes; transparent=false)
    for (i, s) in enumerate(shapes.shape)
        v = subvisshape["node_$i"]
        setobject!(v, visshape[i], s, transparent=transparent)
        scale_transform = MeshCat.LinearMap(diagm(s.scale))
        x_transform = MeshCat.Translation(s.xoffset)
        q_transform = MeshCat.LinearMap(s.qoffset)
        t = MeshCat.compose(x_transform, q_transform, scale_transform)
        settransform!(v, t)
    end
end

function MeshCat.setobject!(subvisshape, visshape, shape::Shape; transparent=false)
    setobject!(subvisshape, visshape, MeshPhongMaterial(color=(transparent ? RGBA(0.75, 0.75, 0.75, 0.5) : shape.color)))
end

function MeshCat.setobject!(subvisshape, visshape::Vector, shape::Capsule; transparent=false)
    setobject!(subvisshape["cylinder"], visshape[1], MeshPhongMaterial(color=(transparent ? RGBA(0.75, 0.75, 0.75, 0.5) : shape.color)))
    setobject!(subvisshape["cap1"], visshape[2], MeshPhongMaterial(color=(transparent ? RGBA(0.75, 0.75, 0.75, 0.5) : shape.color)))
    setobject!(subvisshape["cap2"], visshape[3], MeshPhongMaterial(color=(transparent ? RGBA(0.75, 0.75, 0.75, 0.5) : shape.color)))
end

function MeshCat.setobject!(subvisshape, visshape, shape::Mesh; transparent=false)
    if visshape.mtl_library == ""
        visshape = MeshFileGeometry(visshape.contents, visshape.format)
        setobject!(subvisshape, visshape, MeshPhongMaterial(color=shape.color))
    else
        setobject!(subvisshape, visshape)
    end
end

function visualize(mechanism::Mechanism, storage::Storage{T,N};
        vis::Visualizer = Visualizer(), env::String = "browser",
        showframes::Bool = false, openvis::Bool = false,
        show_contact=false, animation=nothing, name::Symbol=:robot) where {T,N}

    storage = deepcopy(storage)
    bodies = mechanism.bodies
    origin = mechanism.origin
    if showframes
        triads = [Triad(0.33) for i=1:length(bodies)]
    end

    setprop!(vis["/Background"], "top_color", RGBA(1.0, 1.0, 1.0))
    setprop!(vis["/Background"], "bottom_color", RGBA(1.0, 1.0, 1.0))
    # Somehow delete! doesn't work in a function call, so set axes to not visible for now
    setvisible!(vis["/Axes"],false)
    # delete!(vis["/Axes"])

    if openvis
        if env == "browser"
            open(vis)
        elseif env == "editor"
            # Needs to be returned to show. Is there a better way of doing this?
        else
            @error "No valid visualization environment option selected."
        end
    end

    framerate = Int64(round(1/mechanism.timestep))
    (animation == nothing) && (animation = MeshCat.Animation(Dict{MeshCat.SceneTrees.Path,MeshCat.AnimationClip}(), framerate))

    for (id,body) in enumerate(bodies)
        shape = body.shape
        visshape = convert_shape(shape)
        subvisshape = nothing
        subvisframe = nothing
        showshape = false
        if visshape !== nothing
            subvisshape = vis[name]["bodies/body:"*string(id)]
            setobject!(subvisshape,visshape,shape,transparent=show_contact)
            showshape = true
        end

        prepare_vis!(storage, id, shape, animation, subvisshape, subvisframe, showshape, showframes)

        if show_contact
            for (jd, contact) in enumerate(mechanism.contacts)
                if contact.parent_id == body.id
                    contact_shape = Sphere(abs(1.0 * contact.constraints[1].offset[3]),
                        xoffset=(contact.constraints[1].p),
                        qoffset=one(UnitQuaternion), color=RGBA(1.0, 0.0, 0.0, 1.0))
                    visshape = convert_shape(contact_shape)
                    subvisshape = nothing
                    subvisframe = nothing
                    showshape = false
                    if visshape !== nothing
                        # subvisshape = vis["bodies/body:"*string(id)]
                        subvisshape = vis[name]["bodies/contact:"*string(id)*"$jd"]
                        setobject!(subvisshape,visshape,contact_shape,transparent=false)
                        showshape = true
                    end
                    prepare_vis!(storage, id, contact_shape, animation, subvisshape, subvisframe, showshape, showframes)
                end
            end
        end
    end

    id = origin.id
    shape = origin.shape
    visshape = convert_shape(shape)
    if visshape !== nothing
        subvisshape = vis[name]["bodies/origin:"*string(id)]
        setobject!(subvisshape,visshape,shape,transparent=show_contact)
        shapetransform = transform(szeros(T,3), one(UnitQuaternion{T}), shape)
        settransform!(subvisshape, shapetransform)
    end

    setanimation!(vis, animation)
    env == "editor" ? (return render(vis)) : (return vis, animation)
end

function build_robot(vis::Visualizer, mechanism::Mechanism; name::Symbol=:robot, color=nothing) where {T,N}

    bodies = mechanism.bodies
    origin = mechanism.origin

    setprop!(vis["/Background"], "top_color", RGBA(1.0, 1.0, 1.0))
    setprop!(vis["/Background"], "bottom_color", RGBA(1.0, 1.0, 1.0))
    setvisible!(vis["/Axes"],false)

    for (id,body) in enumerate(bodies)
        shape = deepcopy(body.shape)
        if color !== nothing
            if shape isa Shapes
                for i = 1:length(shape.shape)
                    shape.shape[i].color = color
                end
            else
                if shape isa EmptyShape
                    nothing
                else
                    shape.color = color
                end
            end
        end
        visshape = convert_shape(shape)
        subvisshape = nothing
        subvisframe = nothing
        showshape = false
        if visshape !== nothing
            subvisshape = vis[name]["bodies/body:"*string(id)]
            setobject!(subvisshape,visshape,shape)
            showshape = true
        end
    end

    id = origin.id
    shape = origin.shape
    visshape = convert_shape(shape)
    if visshape !== nothing
        subvisshape = vis[name]["bodies/origin:"*string(id)]
        setobject!(subvisshape,visshape,shape)
    end

   return vis
end

function set_robot(vis::Visualizer, mechanism::Mechanism, z::Vector{T}; name::Symbol=:robot) where {T,N}
    bodies = mechanism.bodies
    origin = mechanism.origin

    i = 1
    for (id,body) in enumerate(bodies)
        shape = body.shape
        visshape = convert_shape(shape)
        subvisshape = vis[name]["bodies/body:"*string(id)]

        x = z[(i-1) * 13 .+ (1:3)]
        q = UnitQuaternion(z[(i-1) * 13 + 6 .+ (1:4)]...)

        if visshape !== nothing
            setprop!(subvisshape, "scale", MeshCat.js_scaling(shape.scale))
            setprop!(subvisshape, "position", MeshCat.js_position(x + vrotate(shape.xoffset, q)))
            setprop!(subvisshape, "quaternion", MeshCat.js_quaternion(q * shape.qoffset))
        end
        i += 1
    end

    id = origin.id
    shape = origin.shape
    visshape = convert_shape(shape)
    subvisshape = vis[name]["bodies/origin:"*string(id)]
    if visshape !== nothing
        shapetransform = transform(szeros(T,3), one(UnitQuaternion{T}), shape)
        settransform!(subvisshape, shapetransform)
    end

    return vis
end

function visualize_maximal(mechanism::Mechanism{T,Nn,Ne,Nb,Ni}, z::AbstractVector, vis::Visualizer) where {T,Nn,Ne,Nb,Ni}
	storage = Storage(1,Nb)
	for t = 1:1
		for b = 1:Nb
			x2, v15, q2, ϕ15 = unpack_maximal_state(z, b)
			storage.x[b][t] = x2
			storage.v[b][t] = v15
			storage.q[b][t] = q2
			storage.ω[b][t] = ϕ15
		end
	end
	visualize(mechanism, storage, vis = vis)
end