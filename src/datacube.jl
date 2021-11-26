abstract type DataCube end

struct ForceCube{D,F,Mi} <: DataCube
    filetree::F
    dims::D
    missingval::Mi
end

function ForceCube(rootfolder::String; type::String="BOA")
    ftree = FileTree(rootfolder);
    ftree_filtered = ftree[glob"*X*/*$(type)*.tif"];

    rasters = FileTrees.load(ftree_filtered; dirs=true, lazy=false) do node
        if node isa File
            fname = FileTrees.name(node)
            return fname_to_datetime(fname)
        elseif node isa FileTree
            if node.name[1] == '/'  # filter out root node
                return NoValue()
            else
                fnames = FileTrees.path.(node.children)
                times = FileTrees.values(exec(node); dirs=false)
                return RasterSeries(fnames, Ti(times); duplicate_first=true)
            end
        end
    end

    dims = nothing
    missingval = get(rasters[1]).missingval

    return ForceCube(rasters, dims, missingval)
end

function Base.getindex(cu::ForceCube, I...)

end