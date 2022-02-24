@testset "Modified Rodrigues Parameters" begin
    q = rand(UnitQuaternion)
    @test norm(Dojo.∂mrp∂q(Dojo.vector(q)) -
        FiniteDiff.finite_difference_jacobian(Dojo.mrp, Dojo.vector(q)), Inf) < 1.0e-5
    @test norm(Dojo.∂axis∂q(Dojo.vector(q)) -
        FiniteDiff.finite_difference_jacobian(Dojo.axis, Dojo.vector(q))) < 1.0e-5
    @test norm(Dojo.∂rotation_vector∂q(Dojo.vector(q)) -
        FiniteDiff.finite_difference_jacobian(Dojo.rotation_vector, Dojo.vector(q))) < 1.0e-5

    q = one(UnitQuaternion)
    @test norm(Dojo.∂mrp∂q(Dojo.vector(q)) -
        FiniteDiff.finite_difference_jacobian(Dojo.mrp, Dojo.vector(q)), Inf) < 1.0e-5
    @test norm(Dojo.∂rotation_vector∂q(Dojo.vector(q)) -
        FiniteDiff.finite_difference_jacobian(Dojo.rotation_vector, Dojo.vector(q))) < 1.0e-5
end
