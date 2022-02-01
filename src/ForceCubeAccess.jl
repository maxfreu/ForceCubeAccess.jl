module ForceCubeAccess

using Rasters
using Glob: GlobMatch
using Dates
using OffsetArrays
using GDAL
using DimensionalData
const DD = DimensionalData

export ForceCube, mapseries, extract_nonmissing, get_data
export VALID,
       NODATA,
       CLOUD_BUFFER,
       CLOUD_OPAQUE,
       CLOUD_CIRRUS,
       CLOUD_SHADOW,
       SNOW,
       WATER,
       AOD_INT,
       AOD_HIGH,
       AOD_FILL,
       SUBZERO,
       SATURATION,
       SUN_LOW,
       ILLUMIN_LOW,
       ILLUMIN_POOR,
       ILLUMIN_NONE,
       SLOPED,
       WVP_NONE

const EMPTY_SERIES = RasterSeries(Raster[],Ti(DateTime[]))

include("quality_bits.jl")
include("utils.jl")
include("datacube.jl")
include("indexing.jl")

end
