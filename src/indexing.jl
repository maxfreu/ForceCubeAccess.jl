const SpatialSpectralDim = Union{DD.Dimensions.X, DD.Dimensions.Y, Rasters.Band}

# indexing into the offset array with tile indices
function Base.getindex(fc::ForceCube, I::Vararg{Int})
    return parent(fc)[I...]
end


# temporal queries
function Base.getindex(fc::ForceCube, I::DD.Dimensions.TimeDim)
    map(fc) do series
        return series[I]
    end
end


# spatial and spectral queries
function Base.getindex(fc::ForceCube, I::Vararg{<:SpatialSpectralDim})
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
        return NoData()
    else
        map(series) do raster
            @view raster[I...]
        end
    end
end


# indexing into the cube at or near a certain time
# function Base.getindex(fc::ForceCube, I::Union{DD.Ti{<:At}, DD.Ti{<:Near}, DD.Ti{<:ClosedInterval}})
#     series = seriesrepresentation(fc)
#     return series[I]
# end


function Base.getindex(ts::TimeSlice, I::Vararg{<:SpatialSpectralDim})
    map(ts) do raster
        @views raster[I...] 
    end
end