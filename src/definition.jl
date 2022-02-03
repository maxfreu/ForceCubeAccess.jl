struct ForceCubeDefinition{P}
    projection::P
    origin_lon::Float64
    origin_lat::Float64
    origin_x::Float64
    origin_y::Float64
    tile_size::Int
    block_size::Int
end

function ForceCubeDefinition(fpath::String)
    lines = open(fpath, "r") do io
        readlines(io)
    end
    proj = ArchGDAL.importWKT(lines[1])
    origin = [parse(Float64, l) for l in lines[2:5]]
    sizes = [Int(parse(Float64, l)) for l in lines[6:7]]
    return ForceCubeDefinition(proj, origin..., sizes...)
end