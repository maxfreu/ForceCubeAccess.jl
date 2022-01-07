module ForceCubeAccess

using Rasters
using DimensionalData
using Glob: GlobMatch
using Dates
using OffsetArrays

export ForceCube, mapseries

const EMPTY_SERIES = RasterSeries(Raster[],Ti(DateTime[]))

include("utils.jl")
include("datacube.jl")
include("indexing.jl")

end
