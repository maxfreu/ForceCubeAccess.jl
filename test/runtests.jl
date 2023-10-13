using Test
using ForceCubeAccess
using ForceCubeAccess: joindims_bridge_gap, sizes
using Serialization
using Rasters
using Dates
using OffsetArrays

const boa = deserialize("/home/mfreude/projects/force_cutouts/boa_2023-10-03.jls191")
const qai = deserialize("/home/mfreude/projects/force_cutouts/qai_2023-10-03.jls191")

function checkdims(tile1, tile2, dim)
    dim1 = dims(tile1, dim)
    dim2 = dims(tile2, dim)
    return isapprox(last(dim1) + step(dim1), first(dim2); atol=1e-9)
end

@testset "all" begin

@testset "contract" begin
    @test parent(boa) isa OffsetArray
    @test eltype(parent(boa)) <: RasterSeries
end

@testset "dims" begin
    tilesx = first.(boa[34,58:62]);
    tilesy = first.(boa[34:36,58]);

    # check that the tiles in the cube are aligned to +-1nm
    @test checkdims(tilesx[1:2]..., X)
    @test checkdims(tilesx[2:3]..., X)
    @test checkdims(tilesy[1:2]..., Y)
    @test checkdims(tilesy[2:3]..., Y)

    xdims = dims.(tilesx, X)
    ydims = dims.(tilesy, Y)

    # check that the dimensions are correctly joined, even when there are gaps
    xdim = joindims_bridge_gap(xdims[1], xdims[end])
    xsize = sum(size.(tilesx, X))
    @test length(xdim) == xsize

    xdim = joindims_bridge_gap(xdims[1], xdims[1])
    xsize = size(tilesx[1], X)
    @test length(xdim) == xsize

    ydim = joindims_bridge_gap(ydims[1], ydims[end])
    ysize = sum(size.(tilesy, Y))
    @test length(ydim) == ysize

    ydim = joindims_bridge_gap(ydims[1], ydims[1])
    ysize = size(tilesy[1], Y)
    @test length(ydim) == ysize

    # check that the dims and size of a subset match
    selection = boa[X(4315813..4317186), Y(3132554..3135809)]
    tiles = first.(selection.tiles);
    sz = sum.(sizes(tiles))
    @test sz == length.(dims(selection, (X,Y)))


end

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
        @test selection isa RasterSeries
        @test first(selection) isa TimeSlice
        # @test sum(length.(parent(selection))) > 0
        # @test size(selection) == (1,2)
        # @test length(dims(selection, X)) == 136
        # @test length(dims(selection, Y)) == 114
        # @test length(dims(selection, Band)) == 3
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
end