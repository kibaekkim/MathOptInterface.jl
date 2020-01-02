using Test

using MathOptInterface
const MOI = MathOptInterface
const MOIT = MathOptInterface.Test
const MOIU = MathOptInterface.Utilities
const MOIB = MathOptInterface.Bridges

include("../utilities.jl")

mock = MOIU.MockOptimizer(MOIU.UniversalFallback(MOIU.Model{Float64}()))
config = MOIT.TestConfig()

@testset "NormSpectral" begin
    bridged_mock = MOIB.Constraint.NormSpectral{Float64}(mock)

    MOIT.basic_constraint_tests(bridged_mock, config,
        include = [(F, MOI.NormSpectralCone) for F in [
            MOI.VectorOfVariables, MOI.VectorAffineFunction{Float64}, MOI.VectorQuadraticFunction{Float64}
        ]])

    d1 = 1 / 6
    d2 = 0.25
    x = -inv(2 * sqrt(6))
    psd_dual = [d1, 0, d1, 0, 0, d1, x, x, x, d2, x, x, x, 0, d2]
    mock.optimize! = (mock::MOIU.MockOptimizer) -> MOIU.mock_optimize!(mock, [sqrt(6)],
        (MOI.VectorAffineFunction{Float64}, MOI.PositiveSemidefiniteConeTriangle) => [psd_dual])

    MOIT.normspec1test(bridged_mock, config)

    @testset "Test mock model" begin
        var_names = ["t"]
        MOI.set(mock, MOI.VariableName(), MOI.get(mock, MOI.ListOfVariableIndices()), var_names)
        psd = MOI.get(mock, MOI.ListOfConstraintIndices{MOI.VectorAffineFunction{Float64}, MOI.PositiveSemidefiniteConeTriangle}())
        @test length(psd) == 1
        MOI.set(mock, MOI.ConstraintName(), psd[1], "psd")

        s = """
        variables: t
        psd: [t, 0.0, t, 0.0, 0.0, t, 1.0, 1.0, 1.0, t, 1.0, 1.0, 1.0, 0.0, t] in MathOptInterface.PositiveSemidefiniteConeTriangle(5)
        minobjective: t
        """
        model = MOIU.Model{Float64}()
        MOIU.loadfromstring!(model, s)
        MOIU.test_models_equal(mock, model, var_names, ["psd"])
    end

    @testset "Test bridged model" begin
        var_names = ["t"]
        MOI.set(bridged_mock, MOI.VariableName(), MOI.get(bridged_mock, MOI.ListOfVariableIndices()), var_names)
        spec = MOI.get(bridged_mock, MOI.ListOfConstraintIndices{MOI.VectorAffineFunction{Float64}, MOI.NormSpectralCone}())
        @test length(spec) == 1
        MOI.set(bridged_mock, MOI.ConstraintName(), spec[1], "spec")

        s = """
        variables: t
        spec: [t, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0] in MathOptInterface.NormSpectralCone(2, 3)
        minobjective: t
        """
        model = MOIU.Model{Float64}()
        MOIU.loadfromstring!(model, s)
        MOIU.test_models_equal(bridged_mock, model, var_names, ["spec"])
    end

    ci = first(MOI.get(bridged_mock, MOI.ListOfConstraintIndices{MOI.VectorAffineFunction{Float64}, MOI.NormSpectralCone}()))
    test_delete_bridge(bridged_mock, ci, 1, ((MOI.VectorAffineFunction{Float64}, MOI.PositiveSemidefiniteConeTriangle, 0),))
end

@testset "NormNuclear" begin
    bridged_mock = MOIB.Constraint.NormNuclear{Float64}(mock)

    MOIT.basic_constraint_tests(bridged_mock, config,
        include = [(F, MOI.NormNuclearCone) for F in [
            MOI.VectorOfVariables, MOI.VectorAffineFunction{Float64}, MOI.VectorQuadraticFunction{Float64}
        ]])

    x = -inv(2 * sqrt(6))
    psd_dual = [0.5, 0, 0.5, 0, 0, 0.5, x, x, x, 0.5, x, x, x, 0, 0.5]
    mock.optimize! = (mock::MOIU.MockOptimizer) -> MOIU.mock_optimize!(mock, vcat(sqrt(6), ones(6), ones(3)),
        (MOI.ScalarAffineFunction{Float64}, MOI.GreaterThan{Float64}) => [[1.0]],
        (MOI.VectorAffineFunction{Float64}, MOI.PositiveSemidefiniteConeTriangle) => [psd_dual])

    MOIT.normnuc1test(bridged_mock, config)

    @testset "Test mock model" begin
        var_names = ["t", "U11", "U12", "U22", "U31", "U32", "U33", "V11", "V12", "V22"]
        MOI.set(mock, MOI.VariableName(), MOI.get(mock, MOI.ListOfVariableIndices()), var_names)
        greater = MOI.get(mock, MOI.ListOfConstraintIndices{MOI.ScalarAffineFunction{Float64}, MOI.GreaterThan{Float64}}())
        @test length(greater) == 1
        MOI.set(mock, MOI.ConstraintName(), greater[1], "greater")
        psd = MOI.get(mock, MOI.ListOfConstraintIndices{MOI.VectorAffineFunction{Float64}, MOI.PositiveSemidefiniteConeTriangle}())
        @test length(psd) == 1
        MOI.set(mock, MOI.ConstraintName(), psd[1], "psd")

        s = """
        variables: t, U11, U12, U22, U31, U32, U33, V11, V12, V22
        greater: t + -0.5U11 + -0.5U22 + -0.5U33 + -0.5V11 + -0.5V22 >= 0.0
        psd: [U11, U12, U22, U31, U32, U33, 1.0, 1.0, 1.0, V11, 1.0, 1.0, 1.0, V12, V22] in MathOptInterface.PositiveSemidefiniteConeTriangle(5)
        minobjective: t
        """
        model = MOIU.Model{Float64}()
        MOIU.loadfromstring!(model, s)
        MOIU.test_models_equal(mock, model, var_names, ["greater", "psd"])
    end

    @testset "Test bridged model" begin
        var_names = ["t"]
        MOI.set(bridged_mock, MOI.VariableName(), MOI.get(bridged_mock, MOI.ListOfVariableIndices()), var_names)
        nuc = MOI.get(bridged_mock, MOI.ListOfConstraintIndices{MOI.VectorAffineFunction{Float64}, MOI.NormNuclearCone}())
        @test length(nuc) == 1
        MOI.set(bridged_mock, MOI.ConstraintName(), nuc[1], "nuc")

        s = """
        variables: t
        nuc: [t, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0] in MathOptInterface.NormNuclearCone(2, 3)
        minobjective: t
        """
        model = MOIU.Model{Float64}()
        MOIU.loadfromstring!(model, s)
        MOIU.test_models_equal(bridged_mock, model, var_names, ["nuc"])
    end

    ci = first(MOI.get(bridged_mock, MOI.ListOfConstraintIndices{MOI.VectorAffineFunction{Float64}, MOI.NormNuclearCone}()))
    test_delete_bridge(bridged_mock, ci, 1, (
        (MOI.ScalarAffineFunction{Float64}, MOI.GreaterThan{Float64}, 0),
        (MOI.VectorAffineFunction{Float64}, MOI.PositiveSemidefiniteConeTriangle, 0)))
end
