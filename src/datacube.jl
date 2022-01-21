struct ForceCube{T,D,R,Mi,X}
    tiles::T
    dims::D
    refdims::R
    missingval::Mi
    xy::X
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

    return ForceCube(tiles_offset, dims, (), missingval, (xs, ys))
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
Base.iterate(fc::ForceCube, state...) = iterate(parent(fc), state...)
Base.eltype(fc::ForceCube) = eltype(parent(fc))

function mapseries(f, fc::ForceCube)
    tiles = Matrix{eltype(fc)}(undef, size(fc)...)
    fill!(tiles, NoData())
    for xy in eachindex(parent(fc))
        series = parent(fc)[xy]
        if isa(series, NoData)
            tiles[xy] = NoData()
            continue
        end
        res = f(series)
        if isempty(res) || (0 in size(first(res)))  # mind the comparison order
            tiles[xy] = NoData()
        else
            tiles[xy] = res
        end
    end
    if all(isa.(tiles, NoData))
        return ForceCube(tiles, (), (), fc.missingval, fc.xy)
    else
        xdims, ydims = extract_dims(tiles)
        sample_raster = first(filter(!isempty, tiles))[1]
        if ndims(sample_raster) == 3
            dims_ = (xdims, ydims, dims(sample_raster, Band))
        else
            dims_ = (xdims, ydims)
        end
        return ForceCube(tiles_offset, dims_, sample_raster.refdims, fc.missingval, fc.xy)
    end
end

Rasters.dims(fc::ForceCube) = fc.dims
Rasters.crs(fc::ForceCube) = crs(first(first(parent(fc))))
Rasters.mappedcrs(fc::ForceCube) = mappedcrs(first(first(parent(fc))))

Rasters.read(fc::ForceCube) = mapseries(read, fc)

function Rasters.setmappedcrs(fc::ForceCube, crs)
    mapseries(fc) do series
        return setmappedcrs.(series, fill(crs, length(series)))
    end
end

extract_nonmissing(fc::ForceCube) = mapseries(extract_nonmissing_rasters, fc)

function get_data(fc::ForceCube)
    tiles = parent(fc)
    mask = .!isempty.(tiles)
    return tiles[mask]
end