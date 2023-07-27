struct TimeSlice{T<:AbstractMatrix, D, M, Dt<:Dates.AbstractTime, Def}
    tiles::T
    dims::D
    missingval::M
    date::Dt
    def::Def
end


const EMPTY_TIMESLICE = TimeSlice(zeros(0,0), (), (), Date(0), ())


function TimeSlice(tiles, date, def)
    # crop matrix of Rasters and NoData to its content
    tiles = croptocontent(tiles)
    # extract xdim, ydim for the entire cropped matrix
    dims_ = extract_dims(tiles)
    # get missingval from the first usable Raster
    missingval_ = missingval(tiles[findfirst(!isempty, tiles)])
    # retrieve the heights of each row of the tiles
    xdims, ydims = get_blocked_dims(tiles, def)
    out = similar(tiles)
    sampleraster = tiles[findfirst(!isempty, tiles)]
    banddim = dims(sampleraster, Band)
    for (i,x) in enumerate(axes(tiles, 2))
        for (j,y) in enumerate(axes(tiles, 1))
            xdim = xdims[i]
            ydim = ydims[j]
            if tiles[y,x] isa NoData
                if !isnothing(banddim)
                    sz = length.((xdim, ydim, banddim))
                    val = Raster(Fill(missingval(sampleraster), sz...), dims=(xdim, ydim, banddim))
                else
                    sz = length.((xdim, ydim))
                    val = Raster(Fill(missingval(sampleraster), sz...), dims=(xdim, ydim))
                end
            else
                val = tiles[y,x]
            end
            out[y,x] = val
        end
    end
    dims_ = isnothing(banddim) ? dims_ : (dims_..., banddim)
    return TimeSlice(out, dims_, missingval_, date, def)
end


Base.parent(ts::TimeSlice) = ts.tiles
Base.size(ts::TimeSlice) = length.(ts.dims)
Rasters.dims(ts::TimeSlice) = ts.dims


function Base.show(io::IO, mime::MIME"text/plain", ts::TimeSlice)
    tiles = parent(ts)
    if tiles == zeros(0,0)
        tilerange = ((0,0),(0,0))
    else
        tilerange = extrema.(axes(parent(ts)))
    end
    println(io)
    show(io, mime, ts.dims)
    println(io)
    println(io, "Date: $(Date(ts.date))")
    println(io, "Size in tiles (rows, cols): $(size(parent(ts)))")
    println(io, "Size in pixels (x,y): $(size(ts))")
    println(io, "Tilerange y: $(tilerange[1])")
    println(io, "Tilerange x: $(tilerange[2])")
end


function Base.map(f, ts::TimeSlice)
    res = map(f, parent(ts))
    if all(isempty.(res))
        return EMPTY_TIMESLICE
    end
    return TimeSlice(res, ts.date, ts.def)
end


function solidify(ts::TimeSlice)
    data = read.(parent(ts))
    out = Raster(zeros(eltype(data[1]), size(ts)...);
                       dims=dims(ts),
                       refdims=refdims(data[1]),
                       missingval=missingval(data[1]))
    xs, ys = sizes(parent(ts))
    xoffset = cumsum([0, xs...])
    yoffset = cumsum([0, ys...])
    for col in 1:size(data,2)
        for row in 1:size(data,1)
            r = no_offset_view(data)[row,col]
            width = size(r, X)
            height = size(r, Y)
            xo = xoffset[col]
            yo = yoffset[row]
            if ndims(r) == 2
                out[xo+1:xo+width, yo+1:yo+height] = r
            else
                out[xo+1:xo+width, yo+1:yo+height, :] = r
            end
        end
    end
    return out
end

Rasters.read(ts::TimeSlice) = solidify(ts)


function ismaybeempty(ts::TimeSlice)
    for raster in parent(ts)
        # check if raster contains any data
        # if yes, we can return false
        if !(0 in size(raster))
            return false
        end
        if !Rasters.isdisk(raster)
            if contains_data(raster)
                return false
            end
        end
    end
    return true
end
