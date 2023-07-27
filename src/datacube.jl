struct ForceCube{T,D,R,M,C,Def}
    tiles::T
    dims::D
    refdims::R
    missingval::M
    mappedcrs::C
    def::Def
end


"""
    ForceCube(rootfolder; type="BOA", filename_contains="", duplicate_first=true)

Creates a virtual representation of the FORCE Cube stored in the root folder,
without reading any raster data from disk. The cube is represented as a matrix of 
`RasterSeries` objects from the `Rasters` package.

Combining several sensors is not supported.

Args:
  - rootfolder: The folder containing the X_Y tiles
  - type: Which data to load, for example BOA or QAI
  - filename_contains: With this you can select the sensor, e.g. SEN2.
  - duplicate_first: Whether to duplicate the metadata of the first matching file in each folder. 
                     Makes sense when only data of a specific sensor is loaded.

Example:
```
# parse all SEN2 QAI images:
fc = ForceCube("/FORCE/C1/L2/ard"; type="QAI", filename_contains="SEN2")
```
"""
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
    
    tiles = fill(String[], length(ys), length(xs))
    tiles_offset = OffsetArray(tiles, minimum(ys):maximum(ys), minimum(xs):maximum(xs))

    println("Listing files...")
    for folder in ProgressBar(tile_folders)
        x,y = folder_to_index(folder)
        files = readdir(GlobMatch("*$(type).tif"), joinpath(rootfolder, folder))
        if filename_contains != ""
            files = [f for f in files if contains(f, filename_contains)]
        end
        tiles_offset[y,x] = files
    end

    tiles_offset = croptocontent(tiles_offset)

    # read a single sample raster
    r = Raster(tiles_offset[findfirst(!isempty, tiles_offset)][1]; lazy=true)

    println("Reading metadata...")
    tiles_offset = read_files_into_series.(tiles_offset, typeof(r))
    
    idx = findfirst(!isempty, tiles_offset)
    series = tiles_offset[idx]

    xdims, ydims = extract_dims(tiles_offset)
    banddim = Rasters.dims(series[1], Band)
    
    # qai files have no band dimension
    if isnothing(banddim)
        dims = (xdims, ydims)
    else
        dims = (xdims, ydims, banddim)
    end

    missingval = series[1].missingval
    mappedcrs_ = mappedcrs(series[1])

    def = ForceCubeDefinition(joinpath(rootfolder, "datacube-definition.prj"))

    return ForceCube(tiles_offset, dims, (), missingval, mappedcrs_, def)
end


function Base.show(io::IO, mime::MIME"text/plain", fc::ForceCube)
    tiles = parent(fc)
    counts = length.(tiles)
    total_count = sum(counts)
    # scratch = Matrix{Any}(undef, size(counts).+(1,1))
    scratch = fill(0, size(counts).+(1,1))
    scratch[2:end, 1] = axes(tiles, 1)
    scratch[1, 2:end] = axes(tiles, 2)
    scratch[2:end, 2:end] = counts
    times = alltimes(fc)
    println(io)
    show(io, mime, fc.dims)
    println(io)
    println(io, "Dates ranging from $(Date(first(times))) to $(Date(last(times)))")
    println(io)
    println(io, "Image counts per tile (top and left display tile index):\n")
    Base.print_matrix(io, scratch)
    println(io)
    println(io)
    print(io, "$(total_count) images in total.")
end


Base.parent(fc::ForceCube) = fc.tiles
Base.size(fc::ForceCube) = size(parent(fc))
Base.ndims(fc::ForceCube) = length(dims(fc))
Base.iterate(fc::ForceCube, state...) = iterate(filter(!isempty, parent(fc)), state...)
Base.eltype(fc::ForceCube) = eltype(parent(fc))


"""
    map(f, fc::ForceCube)

Map function f over the each tile in the FORCE cube. Each tile is a `RasterSeries` from \
the Rasters package, so the function to be mapped should take a RasterSeries as argument.
"""
function Base.map(f, fc::ForceCube)
    tiles_offset = map(parent(fc)) do x
        res = f(x)
        if isempty(res) || (0 in size(first(res)))
            return NoData()
        else 
            return res
        end 
    end
    tiles_offset = croptocontent(tiles_offset)

    if all(isempty.(tiles_offset))
        return ForceCube(tiles_offset, (), (), fc.missingval, nothing, def(fc))
    else
        xdims, ydims = extract_dims(tiles_offset)
        sample_raster = first(filter(!isempty, tiles_offset))[1]
        if ndims(sample_raster) == 3
            dims_ = (xdims, ydims, dims(sample_raster, Band))
        else
            dims_ = (xdims, ydims)
        end
        return ForceCube(tiles_offset, dims_, sample_raster.refdims, fc.missingval, mappedcrs(sample_raster), def(fc))
    end
end


Rasters.dims(fc::ForceCube) = fc.dims
Rasters.crs(fc::ForceCube) = crs(filter(!isempty, parent(fc))[1][1])
Rasters.mappedcrs(fc::ForceCube) = fc.mappedcrs


"""
    read(fc::ForceCube)

Reads all data from disk into memory. Ideally you should select a subset
of the force cube before applying this.
"""
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
    return RasterSeries(rasters, Ti(times); lazy=true)
end


function Rasters.setmappedcrs(fc::ForceCube, crs)
    map(fc) do series
        return setmappedcrs.(series, Fill(crs, length(series)))
    end
end


"""
    extract_nonmissing(fc::ForceCube)

Extract all rasters that contain data that is unequal to their missing value.
"""
extract_nonmissing(fc::ForceCube) = map(extract_nonmissing_rasters, fc)


"""
    get_data(fc::ForceCube)

Returns a matrix of the non-empty tiles within the cube.
"""
function get_data(fc::ForceCube)
    tiles = parent(fc)
    mask = .!isempty.(tiles)
    return tiles[mask]
end


def(fc::ForceCube) = fc.def


"""
    apply_bitmask(fc::ForceCube, bitmask)

Applies a bitmask to the cube by applying "bitwise and" to each value and then
taking values greater zero, which results in a boolean array with ones where 
the bitmask was matched. This can be used for quality filtering using the QAI 
data.

Example:
```
# turn clouds and snow into ones and the rest into zero
apply_bitmask(fc, CLOUD_OPAQUE | SNOW)
````
"""
function apply_bitmask(fc::ForceCube, bitmask)
    map(fc) do series
        apply_bitmask(series, bitmask)
    end
end


"""
    origin(fc::ForceCube, proj::Symbol=:projected)

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


function alltimes(fc::ForceCube)
    data = get_data(fc)
    timedims = dims.(data, Ti)
    times = union(Rasters.val.(timedims)...)
    sort!(times)
    timedim = Ti(DD.rebuild(first(timedims).val, data=times))
    return timedim
end


function extract_timeslice(fc::ForceCube, time::Dates.AbstractTime)
    # first, filter out all series that have time in them
    # to avoid later indexing errors
    containstime = map(fc) do series
        if time in dims(series, Ti)
            return series
        else
            return NoData()
        end
    end

    matrixofrasters = map(parent(containstime)) do series
        return series[At(time)]
    end
    # content = matrixofrasters
    content = croptocontent(matrixofrasters)
    return content
end