using Test
using ForceCubeAccess
using Serialization
using Rasters
using Dates

# const qai = ForceCube("/force/FORCE/C1/L2/ard/"; type="QAI", filename_contains="SEN2")
const boa = deserialize("/home/mfreude/projects/force_cutouts/boa_2023-10-03.jls191")
const qai = deserialize("/home/mfreude/projects/force_cutouts/qai_2023-10-03.jls191")


@testset "getindex" begin
    @testset "integer indexing" begin
        # indexing into the force cube with integer tile indices should yield the underlying raster series
        idx = findfirst(!isempty, parent(boa))
        selection = boa[Tuple(idx)...]
        @test selection isa RasterSeries
        @test length(selection) > 0
    end

    @testset "temporal indexing" begin
        # indexing with a time range should yield a ForceCube
        selection = boa[Ti(Date("2021-01-01")..Date("2023-01-01"))]
        @test selection isa ForceCube
        @test sum(length.(parent(selection))) > 0
    end

    @testset "spatial-spectral indexing" begin
        selection = boa[X(4315813..4317186), Y(3157554..3158709), Band(1:3)]
        @test selection isa ForceCube
        @test sum(length.(parent(selection))) > 0
        @test size(selection) == (1,2)
        @test length(dims(selection, X)) == 136
        @test length(dims(selection, Y)) == 114
        @test length(dims(selection, Band)) == 3
    end

    @testset "At and Near" begin
        selection = boa[X(At(4.3158163630416505e6)), Y(At(3.1586896079648044e6))]
        @test selection isa RasterSeries
        @test length(selection) > 0

        selection = boa[X(Near(4.3158163630416505e6)), Y(Near(3.1586896079648044e6))]
        @test selection isa RasterSeries
        @test length(selection) > 0
    end

    @testset "Subsetting other ForceCube" begin
        selection = qai[X(4315813..4317186), Y(3132554..3135809)]
        selection = selection[Ti(Date(2021)..Date(2022))]
        timing = @elapsed res = boa[selection]
        timing = @elapsed res = boa[selection]
        @test res isa RasterSeries
        @test res[1] isa TimeSlice
        @test timing < 1.
    end
end

@testset "methods" begin
    selection = boa[X(4315813..4317186), Y(3132554..3135809), Band(1:3)]
    selection = selection[Ti(Date(2021)..Date(2022))]
    rep = seriesrepresentation(selection)
    @test rep isa RasterSeries
    @test length(rep) == 43
    
    ts = rep[1]
    @test ts isa ForceCubeAccess.TimeSlice
    solid = solidify(ts)
    @test solid isa Raster
    @test size(solid) == length.(dims(selection, (X,Y,Band)))
    

    selection = qai[X(4315813..4317186), Y(3132554..3135809)]
    selection = selection[Ti(Date(2021)..Date(2022))]

    cloudy = CLOUD_BUFFER | CLOUD_CIRRUS | CLOUD_OPAQUE | CLOUD_SHADOW
    selection = read(selection)
    @test selection isa ForceCube
    @test all(Rasters.isdisk.(selection[1]) .== false)
    qai_masked = apply_bitmask(selection, cloudy)  # garbage is 1, usable data is 0, missingval should be 1
    @test length(qai_masked[1]) == 39

    
    qai_masked = extract_nonmissing(qai_masked)
    @test length(qai_masked[1]) == 35

end