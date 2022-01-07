function Base.getindex(fc::ForceCube, I::DimensionalData.Selector)
    mapseries(fc) do series
        return series[I]
    end
end

function Base.getindex(fc::ForceCube, I::Vararg{DimensionalData.Dimension})
    mapseries(fc) do series
        @views rasters = [r[I...] for r in series]
        rebuild(series, rasters)
    end
end
