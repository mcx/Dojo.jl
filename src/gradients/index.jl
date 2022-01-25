
################################################################################
# Index and Dimensions
################################################################################

function Fz_indices(Nb::Int)
    return vcat([13*(i-1) .+ [4:6; 11:13] for i = 1:Nb]...)
end

function data_dimension(mechanism::Mechanism{T,Nn,Ne,Nb,Ni}; attjac::Bool = true) where {T,Nn,Ne,Nb,Ni}
    d = 0
    d += 12Nb
    !attjac && (d += Nb)
    d += control_dimension(mechanism)
    return d
end

function solution_dimension(mechanism::Mechanism{T,Nn,Ne,Nb,Ni}) where {T,Nn,Ne,Nb,Ni}
    d = 0
    d += 6Nb
    d += joint_dimension(mechanism)
    d += contact_dimension(mechanism)
    return d
end

function control_dimension(eqc::JointConstraint{T,N,Nc,Cs}; ignore_floating_base::Bool = false) where {T,N,Nc,Cs}
    ignore_floating_base && (N == 0) && return 0

    N̄ = 0
    for (i, joint) in enumerate(eqc.constraints)
        N̄ += control_dimension(joint)
    end

    return N̄
end

function control_dimension(joint::Joint{T,N}) where {T,N}
    return 3 - N
end

function control_dimension(mechanism::Mechanism{T,Nn,Ne,Nb,Ni}; ignore_floating_base::Bool = false) where {T,Nn,Ne,Nb,Ni}
    nu = 0
    for eqc in mechanism.eqconstraints
        nu += control_dimension(eqc, ignore_floating_base = ignore_floating_base)
    end
    return nu
end

function minimal_dimension(mechanism::Mechanism{T,Nn,Ne,Nb,Ni}) where {T,Nn,Ne,Nb,Ni}
    nx = 0
    free_rot_base = false # we are going to check if the link attached to the base has free orientation
    nx = 2 * control_dimension(mechanism, ignore_floating_base = false)
    free_rot_base && (nx += 1)
    return nx
end

function contact_dimension(mechanism::Mechanism{T,Nn,Ne,Nb,Ni}) where {T,Nn,Ne,Nb,Ni}
    nineqcs = 0
    for ineqc in mechanism.ineqconstraints
        nineqcs += length(ineqc)
    end
    return nineqcs
end

function joint_dimension(mechanism::Mechanism{T,Nn,Ne,Nb,Ni}) where {T,Nn,Ne,Nb,Ni}
    neqcs = 0
    for eqc in mechanism.eqconstraints
        neqcs += length(eqc)
    end
    return neqcs
end
