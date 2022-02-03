struct ForceCube{T,D,R,Mi,C,X,Def}
    tiles::T
    dims::D
    refdims::R
    missingval::Mi
    mappedcrs::C
    xy::X
    def::Def
end

function ForceCube(rootfolder::String; type::String="BOA", filename_contains="", duplicate_first=true)
    println("Indexing data. This may take a while.")
   
    folder_contents = readdir(rootfolder)
    tile_folders = filter(s -> startswith(s, 'X'), folder_contents)
    
    # get all the x and y tile indices
    tile_indices = folder_to_index.(tile_folders)
    xs = [xy[1] for xy in tile_indices]
    ys = [xy[2] for xy in tile_indices]
    xs, ys = unique.((xs, ys))
    sort!.((xs, ys))
    
    tiles = Matrix{Union{NoData, RasterSeries}}(undef, length(ys), length(xs))
    fill!(tiles, NoData())
    tiles_offset = OffsetArray(tiles, minimum(ys):maximum(ys), minimum(xs):maximum(xs))

    for folder in tile_folders
        files = readdir(GlobMatch("*$(type).tif"), joinpath(rootfolder, folder));
        if filename_contains != ""
            files = [f for f in files if contains(f, filename_contains)]
        end
        if length(files) == 0
            continue
        end
        times = fname_to_datetime.(basename.(files));
        x,y = folder_to_index(folder)
        series = RasterSeries(files, Ti(times); duplicate_first=duplicate_first, name=Symbol(folder))
        tiles_offset[y,x] = series
        # push!(tiles, series)
    end
    
    idx = findfirst(!isempty, tiles_offset)
    series = tiles_offset[idx]

    xdims, ydims = extract_dims(tiles_offset)

    dims = (xdims, ydims, Rasters.dims(series[1], Band))
    missingval = series[1].missingval
    mappedcrs_ = mappedcrs(series[1])

    def = ForceCubeDefinition(joinpath(rootfolder, "datacube-definition.prj"))

    return ForceCube(tiles_offset, dims, (), missingval, mappedcrs_, (xs, ys), def)
end

function Base.show(io::IO, mime::MIME"text/plain", fc::ForceCube)
    tiles = parent(fc)
    counts = length.(tiles)
    total_count = sum(counts)
    println(io)
    show(io, mime, fc.dims)
    println(io)
    println(io)
    println(io, "Image counts per tile:\n")
    Base.print_matrix(io, counts)
    println(io)
    println(io)
    print(io, "$(total_count) images in total.")
end

Base.parent(fc::ForceCube) = fc.tiles
Base.size(fc::ForceCube) = size(parent(fc))
Base.ndims(fc::ForceCube) = length(dims(fc))
Base.iterate(fc::ForceCube, state...) = iterate(filter(!isempty, parent(fc)), state...)
Base.eltype(fc::ForceCube) = eltype(parent(fc))

function Base.map(f, fc::ForceCube)
    tiles = Matrix{eltype(fc)}(undef, size(fc)...)
    fill!(tiles, NoData())
    tiles_offset = OffsetArray(tiles, minimum(fc.xy[2]):maximum(fc.xy[2]), minimum(fc.xy[1]):maximum(fc.xy[1]))

    for xy in eachindex(parent(fc))
        series = parent(fc)[xy]
        if series isa NoData
            tiles_offset[xy] = NoData()
            continue
        end
        res = f(series)
        if isempty(res) || (0 in size(first(res)))  # mind the comparison order
            tiles_offset[xy] = NoData()
        else
            tiles_offset[xy] = res
        end
    end
    if all(isa.(tiles, NoData))
        return ForceCube(tiles_offset, (), (), fc.missingval, nothing, fc.xy, def(fc))
    else
        xdims, ydims = extract_dims(tiles)
        sample_raster = first(filter(!isempty, tiles))[1]
        if ndims(sample_raster) == 3
            dims_ = (xdims, ydims, dims(sample_raster, Band))
        else
            dims_ = (xdims, ydims)
        end
        return ForceCube(tiles_offset, dims_, sample_raster.refdims, fc.missingval, mappedcrs(sample_raster), fc.xy, def(fc))
    end
end

Rasters.dims(fc::ForceCube) = fc.dims
Rasters.crs(fc::ForceCube) = crs(filter(!isempty, parent(fc))[1][1])
Rasters.mappedcrs(fc::ForceCube) = fc.mappedcrs

Rasters.read(fc::ForceCube) = map(fc) do series
    rasters = Raster[]
    times = DateTime[]
    for (i,r) in enumerate(series)
        try
            raster = read(r)
            push!(rasters, raster)
            push!(times, dims(series, Ti)[i])
        catch err
            if err isa GDAL.GDALError
                println("[WARNING] Error loading $(Rasters.filename(r)), skipping.")
                println(err)
            else
                rethrow(err)
            end
        end
    end
    return RasterSeries(rasters, Ti(times))
end

function Rasters.setmappedcrs(fc::ForceCube, crs)
    map(fc) do series
        return setmappedcrs.(series, fill(crs, length(series)))
    end
end

extract_nonmissing(fc::ForceCube) = map(extract_nonmissing_rasters, fc)

function get_data(fc::ForceCube)
    tiles = parent(fc)
    mask = .!isempty.(tiles)
    return tiles[mask]
end

def(fc::ForceCube) = fc.def

"""
Returns the origin of the force cube either in Lon/Lat or projected coords. The proj arg can either be :projected or :WGS
"""
function origin(fc::ForceCube, proj::Symbol=:projected)
    if proj == :projected
        x = def(fc).origin_x
        y = def(fc).origin_y
    elseif proj == :WGS
        x = def(fc).origin_lon
        y = def(fc).origin_lat
    else
        throw(ArgumentError("The proj argument can either be :projected or :WGS."))
    end
    return (x,y)
end