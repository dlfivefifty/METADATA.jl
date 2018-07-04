function invenia_remote()
    remote = ""
    for line in eachline(`git remote -v`)
        if occursin("gitlab.invenia.ca", line)
            remote = line[1:prevind(line, findfirst(isspace, line))]
            break
        end
    end
    remote == "" ? nothing : remote
end

const METADATA_HOME = normpath(@__DIR__, "..")

if get(ENV, "CI", "false") != "true"
    # Make sure we an Invenia-specific remote checked out and up to date
    @info "Updating the Invenia fork of METADATA"
    cd(METADATA_HOME) do
        remote = invenia_remote()
        if remote === nothing
            run(`git remote add invenia https://gitlab.invenia.ca/invenia/METADATA.jl.git`)
            run(`git fetch invenia`)
            run(`git checkout invenia/invenia`)
        else
            run(`git fetch $remote --prune`)
            branch = readchomp(`git rev-parse --abbrev-ref --symbolic-full-name "@{u}"`)
            if startswith(branch, remote * "/") && !endswith(branch, "metadata-v2")
                run(`git reset --hard $remote/invenia`)
            else
                run(`git checkout $remote/invenia`)
            end
        end
    end
end

include("loadmeta.jl")
include("utils.jl")
include("gitmeta.jl")
include("genstdlib.jl")
include("generate.jl")
