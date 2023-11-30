# ForceCubeAccess.jl

Methods for (lazily) accessing data stored in a force data cube

## Installation
Install julia, create a folder for your project, start julia, hit "]" to open package management and activate your project environment via `activate /path/to/project`. Then add this package via `add https://github.com/maxfreu/ForceCubeAccess.jl.git`

## Usage
You can create a new ForceCube for example like this (this can take hours!):

```julia
using ForceCubeAccess
using Serialization
using Dates

path = "/codede/community/FORCE/C1/L2/ard/"
boa = ForceCube(path; type="BOA", filename_contains="SEN2")
qai = ForceCube(path; type="QAI", filename_contains="SEN2")

serialize("boa_s3_$(today()).jls", boa)
serialize("qai_s3_$(today()).jls", qai)
```
The type defines which type of data we want to load; here BOA stands for bottom of atmosphere reflectance and qai is quality assurance information. With `filename_contains` you can select the satellite. Currently only Sentinel-2 data has been tested. Creating the `ForceCube` can take several hours, depending on the underlying filesystem, as the program now indexes several thousand files and extracts their metadata for later use. Above example proceeds to save the ForceCube using `serialize`, so that you can quickly load it via `deserialize`. Note that serialization formats might be incompatible between julia versions or even different package versions. To be safe, you can backup the Manifest.toml file of a working state, which is located in your project folder, before updating (which happens automatically when adding new packages, if not specified otherwise!).

Once the cube is loaded, it should display the dimensions, as well as the image counts per tile. Below example shows data for Germany, along with the x and y tile index in the first row and column:

```julia
julia> qai

X Projected{Float64} LinRange{Float64}(4.01603e6, 4.70602e6, 69000) ForwardOrdered Regular Intervals crs: WellKnownText,
Y Projected{Float64} LinRange{Float64}(3.58491e6, 2.65492e6, 93000) ReverseOrdered Regular Intervals crs: WellKnownText
Dates ranging from 2015-07-04 to 2023-09-29

Image counts per tile (top and left display tile index):

  0   52   53   54   55   56   57   58   59   60   61   62   63   64   65   66   67   68   69   70   71   72   73   74
 33    0    0    0    0    0    0  393  509    0    0    0    0    0    0    0    0    0    0    0    0    0    0    0
 34    0    0    0    0    0    0  538  390  411  436  450    0    0    0    0    0    0    0    0    0    0    0    0
 35    0    0    0    0    0    0  377  369  365  361  418    0  385  370    0  422  385  582  342    0    0    0    0
 36    0    0    0    0    0  198  370  413  371  340  389  598  379  386  417  425  384  387  395  350    0    0    0
 37    0    0    0    0    0  406  435  450  404  342  365  543  414  424  431  371  409  411  453  435    0    0    0
 38    0    0  406  402  423  580  381  403  378  322  313  333  339  330  358  310  486  371  389  402    0    0    0
 39    0    0  411  410  403  376  379  391  373  332  343  351  321  332  359  335  415  378  371  341  363    0    0
 40    0    0    0  412  415  373  380  400  401  365  503  399  371  360  389  363  391  425  421  366  366    0    0
 41    0    0    0  399  533  364  381  407  408  365  348  397  372  367  398  352  392  418  428  333  336    0    0
 42    0    0  339  343  326  307  310  349  354  328  308  360  326  325  367  471  351  342  386  365  351    0    0
 43    0    0  349  332  336  306  315  355  360  416  301  351  331  323  360  340  342  340  422  392  375  405    0
 44    0    0  385  489  388  347  355  382  384  313  334  388  371  370  392  385  392  388  435  390  371  412    0
 45  368  380  337  314  364  316  312  341  342  278  275  345  340  331  363  345  359  356  401  353  328  378    0
 46  355  379  331  316  369  312  310  329  327  278  277  310  308  332  327  354  349  351  390  354  344  384    0
 47  405  385  210  364  385  347  333  345  302  322  321  372  359  350  396  388  398  396  434  373  380  413  425
 48  374  349  322  350  355  282  275  309  296  298  292  343  321  317  350  355  345  350  395  307  341  390  400
 49  381  337  330  340  352  286  291  304  311  303  300  346  324  233  359  351  342  328  378  168  332  386    0
 50  393  187  369  381  399  342  352  186  341  322  325  356  338  163  385  381  374  366  396  344    0    0    0
 51  379  327  373  387  400  357  359  329  358  337  334  352  333  309  366  372  371  394  386    0    0    0    0
 52  290  333  334  357  373  343  323  345  344  317  311  325  289  287  343  319  306    0    0    0    0    0    0
 53  181  340  348  341  372  353  181  360  358  329  314  335  144  297  342  320  311    0    0    0    0    0    0
 54    0  387  375  383  414  369  197  392  384  352  354  363  168  345  380  376  379  353    0    0    0    0    0
 55    0  365  360  377  377  315  333  368  369  332  310  330  311  329  356  354  356  355  336    0    0    0    0
 56    0  376  364  380  386  188  351  370  384  330  332  182  330  330  363  366  357  183  384  373    0    0    0
 57    0    0    0    0  408  206  389  409  430  392  375  192  379  374  406  383  387  206  393  416    0    0    0
 58    0    0    0    0  372  335  361  413  424  352  337  190  353  345  375  356  351  175  375  393    0    0    0
 59    0    0    0  399  226  357  365  394  420  355  186  359  370  385  411  380  364  187  382    0    0    0    0
 60    0    0    0  459  243  400  416  465  458  415  211  424  421  439  460  441  221  391  433    0    0    0    0
 61    0    0    0  344  244  433  440  472  446  433  226  435  441  438  467  432  207  426  428    0    0    0    0
 62    0    0    0  212  406  405  409    0  423  371  208  410  414  406  446  414  202  396  374    0    0    0    0
 63    0    0    0    0    0    0    0    0    0    0  301  426    0    0    0    0    0    0    0    0    0    0    0

185494 images in total.
```

You can now select subsets of the data in space and time:

```julia
# a..b means from a (inclusive) to b (exclusive) or [a,b) in mathematical notation
timeselection = qai[Ti(Date(2018,06)..Date(2018,07))]
cutout = timeselection[X(4.6e6..4.65e6), Y(3e6..3.1e6)]

X Projected{Float64} LinRange{Float64}(4.60001e6, 4.64999e6, 4999) ForwardOrdered Regular Intervals crs: WellKnownText,
Y Projected{Float64} LinRange{Float64}(3.09999e6, 3.04492e6, 5508) ReverseOrdered Regular Intervals crs: WellKnownText
Dates ranging from 2018-06-05 to 2018-06-30

Image counts per tile (top and left display tile index):

  0  71  72  73
 49   1   4   6
 50   5   0   0

16 images in total.
```
To get best performance, you should always index time first and then the spatial dimensions, as the former is faster and the latter scales with the number of images in the selection.

So in the above, we have boiled our datacube down from 185494 images to 16. We can now read the data into memory using `read`:

```julia
data_in_memory = read(cutout)
```

Individual tiles can be accessed via getindex by tile index:
```julia
x = 73
y = 49
data_in_memory[y,x]  # rows first, like in matrix notation

6-element RasterSeries{Raster,1} with dimensions: 
  Ti Sampled{DateTime} DateTime[2018-06-08T00:00:00, …, 2018-06-30T00:00:00] ForwardOrdered Irregular Points
```

Above `cutout` has different data in different tiles at possibly different time steps. You can construct a `RasterSeries` that contains data for all the time steps present in the selection using the functin `seriesrepresentation`:
```julia
srep = seriesrepresentation(cutout)

7-element RasterSeries{TimeSlice,1} with dimensions: 
  Ti Sampled{DateTime} DateTime[2018-06-05T00:00:00, …, 2018-06-30T00:00:00] ForwardOrdered Irregular Points

srep[1]

X Projected{Float64} LinRange{Float64}(4.60001e6, 4.64999e6, 4999) ForwardOrdered Regular Intervals crs: WellKnownText,
Y Projected{Float64} LinRange{Float64}(3.09999e6, 3.04492e6, 5508) ReverseOrdered Regular Intervals crs: WellKnownText
Date: 2018-06-05
Size in tiles (rows, cols): (2, 3)
Size in pixels (x,y): (4999, 5508)
Tilerange y: (49, 50)
Tilerange x: (71, 73)
```
When applied to data that has not yet been read into memory, the resulting `RasterSeries` contains `TimeSlice` objects, that efficiently represent missing data. Above `srep[1]` retrieves the first `TimeSlice`. All timeslices in the series cover the same spatial extent. The seriesrepresentation can be read to create a `RasterSeries` of `Raster`s by broadcasting the read function over its elements:

```julia
srep_in_mem = read.(srep)

srep_in_mem[2]
4999×5508 Raster{Int16,2} with dimensions: 
  X Projected{Float64} LinRange{Float64}(4.60001e6, 4.64999e6, 4999) ForwardOrdered Regular Intervals crs: WellKnownText,
  Y Projected{Float64} LinRange{Float64}(3.09999e6, 3.04492e6, 5508) ReverseOrdered Regular Intervals crs: WellKnownText
and reference dimensions: 
  Band Categorical{String} String["Quality assurance information"] Unordered
extent: Extent(X = (4.60000636304165e6, 4.64999636304165e6), Y = (3.0449196079648044e6, 3.0999996079648044e6))
missingval: 1
crs: PROJCS["ETRS89-extended / LAEA Europe",GEOGCS["ETRS89",DATUM["European_Terrestrial_Reference_System_1989",SPHEROID["GRS 1980",6378137,298.257222101,AUTHORITY["EPSG","7019"]],AUTHORITY["EPSG","6258"]],PRIMEM["Greenwich",0,AUTHORITY["EPSG","8901"]],UNIT["degree",0.0174532925199433,AUTHORITY["EPSG","9122"]],AUTHORITY["EPSG","4258"]],PROJECTION["Lambert_Azimuthal_Equal_Area"],PARAMETER["latitude_of_center",52],PARAMETER["longitude_of_center",10],PARAMETER["false_easting",4321000],PARAMETER["false_northing",3210000],UNIT["metre",1,AUTHORITY["EPSG","9001"]],AXIS["Northing",NORTH],AXIS["Easting",EAST],AUTHORITY["EPSG","3035"]]
parent:
                3.09999e6      3.09998e6      3.09997e6  …  3.04497e6  3.04496e6  3.04495e6  3.04494e6  3.04493e6  3.04492e6
 4.60001e6  16972          16972          16972             1          1          1          1          1          1
 4.60002e6  16972          25164          25164             1          1          1          1          1          1
 4.60003e6  25164          25164          25164             1          1          1          1          1          1
 ⋮                                                       ⋱                                              ⋮          
 4.64997e6  24650          24650          24650             1          1          1          1          1          1
 4.64998e6  24650          24650          24650             1          1          1          1          1          1
 4.64999e6  24650          24650          24650             1          1          1          1          1          1
```

As soon as the data is in memory, it can be used in any way you want, e.g. putting it on the GPU for processing.

There's more functionality available, like indexing one force cube with another, which allows pre-selecting areas of interest using QAI filtering and then applying the selection to the BOA reflectance. But that's still lacking documentation. However, you can read the tests for further usage examples.
