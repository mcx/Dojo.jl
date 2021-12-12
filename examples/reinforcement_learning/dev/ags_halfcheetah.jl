# Utils
function module_dir()
    return joinpath(@__DIR__, "..", "..", "..")
end

# Activate package
using Pkg
Pkg.activate(module_dir())

# Load packages
using MeshCat

# Open visualizer
vis = Visualizer()
open(vis)

# Include new files
include(joinpath(module_dir(), "examples", "loader.jl"))


include("../ars.jl")
include("../ags.jl")


opts_grad = InteriorPointOptions(rtol = 1e-4, btol = 1e-2, undercut = 2.0)
env = make("halfcheetah", vis = vis, dt = 0.05, opts_grad = opts_grad)
obs = reset(env)
render(env)
input_size = length(obs)
output_size = length(env.u_prev)
hp = HyperParameters(main_loop_size = 30, horizon = 80, n_directions = 6, b = 6, step_size = 0.01)
policy = Policy(input_size, output_size, hp)
normalizer = Normalizer(input_size)


hp = HyperParameters(main_loop_size = 30, horizon = 80, n_directions = 6, b = 6, step_size = 0.01)
train(env, policy, normalizer, hp)
traj = display_policy(env, policy, normalizer, hp)
visualize(env, traj)
