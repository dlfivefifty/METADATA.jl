# This file is adapted from code that is a part of Julia, see https://julialang.org/license

import Pkg: TOML

# TODO: use Sys.STDLIBDIR instead once implemented
let vers = "v$(VERSION.major).$(VERSION.minor)"
    global stdlibdir = realpath(abspath(Sys.BINDIR, "..", "share", "julia", "stdlib", vers))
    isdir(stdlibdir) || error("stdlib directory does not exist: $stdlibdir")
end

# NOTE: The Git incantation down below assumes access to a Git clone of the Julia source,
# so we clone it during the GitLab CI setup.
juliadir = joinpath(get(ENV, "CI_TMP_DIR", @__DIR__), "julia_source")
@assert isdir(juliadir)

stdlib_uuids = Dict{String,String}()
stdlib_trees = Dict{String,String}()
stdlib_deps = Dict{String,Vector{String}}()

for pkg in readdir(stdlibdir)
    project_file = joinpath(stdlibdir, pkg, "Project.toml")
    isfile(project_file) || continue
    project = TOML.parsefile(project_file)
    stdlib_uuids[pkg] = project["uuid"]
    stdlib_trees[pkg] = split(readchomp(`git -C $juliadir ls-tree HEAD -- stdlib/$pkg`))[3]
    stdlib_deps[pkg] = String[]
    haskey(project, "deps") || continue
    append!(stdlib_deps[pkg], sort!(collect(keys(project["deps"]))))
end
