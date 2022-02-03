struct NoData end

Base.length(::NoData) = 0
Base.getindex(::NoData, I...) = NoData()
Base.iterate(::NoData, state...) = nothing
Base.ismissing(::NoData) = true
Base.isempty(::NoData) = true
DD.rebuild(::NoData, ::Vararg) = NoData()
Rasters.read(::NoData) = NoData()

"""
    fname_to_datetime(fname)

Converts a string starting with 'yymmdd' into a DateTime object. 
"""
fname_to_datetime(fname) = DateTime(fname[1:8], "yyyymmdd")

"""
    folder_to_index(foldername)

Convert a folder name of the form 'X<number>_Y<number>' into a tuple containing the two numbers.
"""
function folder_to_index(foldername)::Tuple{Int, Int}
    startswith(foldername, 'X') || error("Folder name must be of the form 'X<number>_Y<number>', but is $foldername.")
    xy = split(foldername, '_')
    xy = ntuple(i -> parse(Int, xy[i][2:end]), 2)
    return xy
end


"""
    joindims(lower, upper)

Collates two dimensions. The dimensions must have the same resolution and must align perfectly.
"""
function joindims(lower::T, upper::T)::T where T
    if length(lower) == 0
        return upper
    elseif length(upper) == 0
        return lower
    end
    lproj = lower.val
    uproj = upper.val
    lres = lproj.span.step
    ures = uproj.span.step
    lres == ures || error("Dimensions must have the same resolution, but they have $lres and $ures.")
    lrange = lproj.data
    urange = uproj.data
    # enforce that both dims align
    lrange.stop + lres == urange.start || error("Dimensions are overlapping.")
    newrange = LinRange(lrange.start, urange.stop, lrange.len + urange.len)
    newproj = rebuild(lproj; data=newrange)
    return rebuild(lower; val=newproj)
end

"""
    joindims_bridge_gap(lower, upper)

Collates two dimensions. The dimensions must have the same resolution, but they can be disjunct.
"""
function joindims_bridge_gap(lower::T, upper::T)::T where T
    if length(lower) == 0
        return upper
    elseif length(upper) == 0
        return lower
    end
    lproj = lower.val
    uproj = upper.val
    lres = step(lproj)
    ures = step(uproj)
    lres == ures || error("Dimensions must have the same resolution, but they have $lres and $ures.")
    lrange = lproj.data
    urange = uproj.data
    newrange = LinRange(lrange.start, urange.stop, floor(Int, (urange.stop - lrange.start) / lres) + 1)
    newproj = rebuild(lproj; data=newrange)
    return rebuild(lower; val=newproj)
end


"""
    uniquedims(dims::Vector{T}) where T

`unique` is broken for vectors of `DimensionalData` dimensions; this is a replacement.
"""
function uniquedims(dims::Vector{T}) where T
    seen = T[]
    for d in dims
        if !in(d, seen)
            push!(seen, d)
        end
    end
    return seen
end

length_skipmissing(v::Any) = length(v)
length_skipmissing(v::Missing) = 0

"""
    extract_dims(tiles)
    
Extracts the dimensions from an AbstractArray of RasterSeries.
"""
function extract_dims(tiles)
    # extract dimensions
    xdims = uniquedims([dims(r[1], X) for r in tiles if !isempty(r)])
    ydims = uniquedims([dims(r[1], Y) for r in tiles if !isempty(r)])
    # sort them by their starting point
    xperm = sortperm([d.val.data.start for d in xdims])
    yperm = sortperm([d.val.data.start for d in ydims])
    xdims = xdims[xperm]
    ydims = reverse(ydims[yperm])  # adjust for reversed y indices, this is brittle
    xdims = joindims_bridge_gap(first(xdims), last(xdims))
    ydims = joindims_bridge_gap(first(ydims), last(ydims))
    return xdims, ydims
end

"""
    contains_data(r::Raster)

Checks whether `r` contains any data which is different from its `missingval`.
"""
contains_data(r::Raster) = any(r .!= missingval(r))

"""
    extract_nonmissing_rasters(s::RasterSeries)

Extracts all `Rasters` from a series that contain any data uneual 
to their missing value and returns them as a new `RasterSeries`.
"""
extract_nonmissing_rasters(s::RasterSeries) = s[contains_data.(s)]

"""
    get_sensor(series, sensor="SEN2")

This function takes a RasterSeries and returns a new RasterSeries comprising only Rasters with 'sensor' in their name.

This function can be mapped over the force cube to extract data from a specific sensor, based on the file names.
It checks whether or not the file name contains the string "sensor" and if yes, the file is included.
"""
function get_sensor(series, sensor="SEN2")
    fnames = Rasters.filename.(series)
    sensor_imgs = (n -> contains(n, sensor)).(fnames)
    return series[sensor_imgs]
end

"""
    tile_index(fc, x, y)

Calculates the tile index, given the x and y coordinates in the projected coordinate reference system.
Returns tile_x, tile_y
"""
function tile_index(fc, x, y)
    o = origin(fc, :projected)
    tile_size = def(fc).tile_size
    tile_x = floor(Int, (x - o[1])/tile_size)
    tile_y = floor(Int, (o[2] - y)/tile_size)
    return tile_x, tile_y
end

"""
    apply_bitmask(raster::Raster, bitmask)
    apply_bitmask(series::RasterSeries, bitmask)
    apply_bitmask(fc::ForceCube, bitmask)

Applies a bitmask (e.g. CLOUD_OPAQUE) to a `Raster`, `RasterSeries` or `ForceCube`.
"""
function apply_bitmask(raster::Raster, bitmask)
    (x -> (x .& bitmask) .> 0).(raster)
end

function apply_bitmask(series::RasterSeries, bitmask)
    map(series) do raster
        apply_bitmask(raster, bitmask)
    end
end