abstract type DataCube end

struct ForceCube{T,D,Mi,X} <: DataCube
    tiles::T
    dims::D
    missingval::Mi
    xy::X
end

struct ForceCubeBroadcastStyle <: Base.Broadcast.BroadcastStyle end

function ForceCube(rootfolder::String; type::String="BOA")
    println("Indexing data. This may take a while.")
   
    folder_contents = readdir(rootfolder)
    tile_folders = filter(s -> startswith(s, 'X'), folder_contents)
    
    # get all the x and y tile indices
    tile_indices = folder_to_index.(tile_folders)
    xs = [xy[1] for xy in tile_indices]
    ys = [xy[2] for xy in tile_indices]
    xs, ys = unique.((xs, ys))
    sort!.((xs, ys))
    
    tiles = RasterSeries[]
    
    for folder in tile_folders
        files = readdir(GlobMatch("*$(type).tif"), joinpath(rootfolder, folder));
        times = fname_to_datetime.(basename.(files));
        # x,y = folder_to_index(folder)
        series = RasterSeries(files, Ti(times); duplicate_first=true, name=Symbol(folder))
        # tiles_offset[x,y] = series
        push!(tiles, series)
    end
    
    series = first(tiles)

    xdims, ydims = extract_dims(tiles)

    dims = (xdims, ydims, Rasters.dims(series[1], Band))
    missingval = series[1].missingval

    return ForceCube(tiles, dims, missingval, (xs, ys))
end

function Base.show(io::IO, mime::MIME"text/plain", fc::ForceCube)
    counts = collect(length_skipmissing.(fc.tiles)')
    show(io, mime, fc.dims)
    println(io)
    println(io)
    println(io, "Image counts per tile:\n")
    Base.print_matrix(io, counts)
    println(io)
    println(io)
    print(io, "$(sum(counts)) images in total.")
end

Base.parent(fc::ForceCube) = fc.tiles
Base.size(fc::ForceCube) = size(parent(fc))
Base.ndims(fc::ForceCube) = length(dims(fc))
Base.iterate(fc::ForceCube) = iterate(parent(fc))

# not type stable
function mapseries(f, fc::ForceCube)
    tiles = similar(parent(fc))
    for xy in eachindex(parent(fc))
        series = parent(fc)[xy]
        tiles[xy] = f(series)
    end
    xdims, ydims = extract_dims(tiles)
    firstseries = findfirst(!isempty, tiles)
    if isnothing(firstseries)  # all series are empty
        dims = (xdims, ydims, Band(Int[]))
    else
        sample_raster = tiles[firstseries][1] # first raster in first non-empty series
        if ndims(sample_raster) == 3
            dims = (xdims, ydims, Rasters.dims(sample_raster, Band))
        else
            dims = (xdims, ydims)
        end
    end
    return ForceCube(tiles, dims, fc.missingval, fc.xy)
end

Rasters.dims(dc::DataCube) = dc.dims
Rasters.crs(fc::ForceCube) = crs(first(first(parent(fc))))
Rasters.mappedcrs(fc::ForceCube) = mappedcrs(first(first(parent(fc))))

Rasters.read(fc::ForceCube) = mapseries(read, fc)

function Rasters.setmappedcrs(fc::ForceCube, crs)
    mapseries(fc) do series
        return setmappedcrs.(series, fill(crs, length(series)))
    end
end

extract_nonmissing(fc::ForceCube) = mapseries(extract_nonmissing_rasters, fc)