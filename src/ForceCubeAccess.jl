module ForceCubeAccess

using Rasters
using Glob: GlobMatch
using Dates
using OffsetArrays
using ArchGDAL
using GDAL
using DimensionalData
const DD = DimensionalData

export ForceCube,
       extract_nonmissing,
       get_data,  # this is shit
       apply_bitmask

export VALID,
       NODATA,  # really export?
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
include("definition.jl")
include("datacube.jl")
include("indexing.jl")

end
