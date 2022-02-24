# temporal queries
function Base.getindex(fc::ForceCube, I::DD.Selector)
    map(fc) do series
        return series[I]
    end
end

# spatial queries
function Base.getindex(fc::ForceCube, I::Vararg{DD.Dimension})
    map(fc) do series
        @views rasters = [r[I...] for r in series]
        rebuild(series, rasters)
    end
end

# using At() or Near() to get a single time series
function Base.getindex(fc::ForceCube, I::Vararg{Union{DD.Dimension{<:At}, DD.Dimension{<:Near}}})
    x, y = DD.val.(DD.val.(DD.Dimensions.sortdims(I, (X,Y))))
    # if !isnothing(mappedcrs(fc))
    #     x, y = ArchGDAL.reproject((x,y), mappedcrs(fc), crs(fc); order=:trad)
    # end
    tile_x, tile_y = tile_index(fc, x, y)
    series = parent(fc)[tile_y, tile_x]
    if series isa NoData
        return EMPTY_SERIES
    else
        map(series) do raster
            @view raster[I...]
        end
    end
end

# using one cube for indexing into another
function Base.getindex(fc::ForceCube, I::ForceCube)
    # 1. temporal query
    if fc.xy != I.xy
        throw(ArgumentError("Data cubes must cover the same set of tiles"))
    end
    
    tiles = Matrix{eltype(fc)}(undef, size(fc)...)
    fill!(tiles, NoData())

    for xy in eachindex(parent(fc))
        roi_series = parent(I)[xy]
        src_series = parent(fc)[xy]
        if isa(roi_series, NoData) || isa(src_series, NoData)
            tiles[xy] = NoData()
            continue
        end
        roi_times = dims(roi_series, Ti).val
        src_times = dims(src_series, Ti).val
        times = intersect(roi_times, src_times)
        series = src_series[At(times)]
        tiles[xy] = series
    end
    xdims, ydims = extract_dims(tiles)
    sample_raster = first(filter(!isempty, tiles))
    if ndims(sample_raster) == 3
        dims_ = (xdims, ydims, Rasters.dims(sample_raster, Band))
    else
        dims_ = (xdims, ydims)
    end
    fc = ForceCube(tiles, dims_, sample_raster.refdims, fc.missingval, fc.mappedcrs, fc.xy, def(fc))

    # 2. spatial query
    xd = dims(I, X)
    yd = dims(I, Y)
    xmin, xmax = first(xd), last(xd) + step(xd)  # adjust for forward and reverse order...
    ymin, ymax = first(yd) - step(yd), last(yd)
    cutout = fc[X(Between(xmin, xmax)), Y(Between(ymin, ymax))]
    return cutout
end