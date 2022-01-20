module ForceCubeAccess

using Rasters
using DimensionalData
using Glob: GlobMatch
using Dates
using OffsetArrays

export ForceCube, mapseries, extract_nonmissing, get_data

const EMPTY_SERIES = RasterSeries(Raster[],Ti(DateTime[]))

include("quality_bits.jl")
include("utils.jl")
include("datacube.jl")
include("indexing.jl")

end
