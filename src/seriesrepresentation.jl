function extract_timeslice(tiles, time::Dates.AbstractTime)
    map(tiles) do series
        if time in dims(series, Ti)
            return series[At(time)]
        else
            return NoData()
        end
    end
end


function seriesrepresentation(fc::ForceCube; times=alltimes(fc))
    # the series representation has to be coherent in time and space
    # so first we have to find all tiles that contain data
    # there can possibly be holes
    # then we have to get the dimensions of the tiles
    # with the dims the time slices can be constructed

    fc_tiles = parent(fc)
    indices = findall(!isempty, fc_tiles)
    if isempty(indices)
        error("Can't compute series representation for empty Force cube.")
    end
    lower, upper = extrema(indices)
    tiles = OffsetArray(fc_tiles[lower:upper], lower:upper)

    # construct array containing the first raster if there is a series
    rasters = map(tiles) do series
        length(series) > 0 ? first(series) : NoData()
    end

    # ok now we have the x and y dimensions for all columns and rows
    # and they will be the same for every TimeSlice
    xydims = get_blocked_dims(rasters, def(fc))
    
    slices = [TimeSlice(extract_timeslice(tiles, t), xydims, t, fc.def) for t in times]

    return RasterSeries(slices, (Ti(times),), Tuple{}())
end