# This file is adapted from code that is a part of Julia, see https://julialang.org/license

# NOTE: DEPOT_PATH can be controlled by the environment variable JULIA_DEPOT_PATH, which
# on CI is set by the julia-ci script to a single directory. When run locally, the first
# entry in DEPOT_PATH is ~/.julia, which should also work fine. In either case, selecting
# the first item only from the array is what we want.
prefix = joinpath(first(DEPOT_PATH), "registries", "Invenia")

@info "Writing Invenia registry file"
write_toml(prefix, "Registry") do io
    repo = "https://gitlab.invenia.ca/invenia/PackageRegistry.git"
    uuid = string(uuid5(uuid_registry, repo))
    println(io, "name = ", repr("Invenia"))
    println(io, "uuid = ", repr(uuid))
    println(io, "repo = ", repr(repo))
    println(io, "\ndescription = ",
            repr("Private Julia package registry for Invenia internal packages."))
    println(io, "\n[packages]")
    for (pkg, p) in sort!(collect(invenia_pkgs), by=(p->p.uuid.value)∘last)
        bucket = string(uppercase(first(pkg)))
        path = joinpath(bucket, pkg)
        println(io, p.uuid, " = { name = ", repr(pkg), ", path = ", repr(path), " }")
    end
end

buckets = Dict()
for (pkg, p) in invenia_pkgs
    bucket = string(uppercase(first(pkg)))
    push!(get!(buckets, bucket, []), (pkg, p))
end

const trees, stdlibs = gitmeta(pkgs)

for pkg in STDLIBS
    tree = stdlib_trees[pkg]
    deps = Dict(dep => Require(VersionInterval()) for dep in stdlib_deps[pkg])
    pkgs[pkg] = Package(
        UUID(stdlib_uuids[pkg]),
        "https://github.com/JuliaLang/julia.git",
        Dict(VersionNumber(0,7,0,("DEV",),("r"*tree[1:8],)) => Version(tree, deps)),
    )
end

for (pkg, p) in invenia_pkgs
    uuid = string(p.uuid)
    haskey(stdlibs, uuid) || continue
    for (ver, v) in p.versions
        n = get(stdlibs[uuid], v.sha1, 0)
        n == 0 && continue
        for lib in STDLIBS
            if n & 1 != 0
                v.requires[lib] = Require(VersionInterval())
            end
            n >>>= 1
        end
    end
end

for (bucket, b_pkgs) in buckets, (pkg, p) in b_pkgs
    haskey(stdlibs, pkg) && continue
    url = p.url
    uuid = string(p.uuid)
    if startswith(url, "git://github.com") || startswith(url, "git://gitlab.invenia.ca")
        url = "https" * url[4:end]
    end

    @info "Writing package files for $pkg"

    # Package.toml
    printstyled("  Package.toml\n"; color=Base.info_color())
    write_toml(prefix, bucket, pkg, "Package") do io
        println(io, "name = ", repr(pkg))
        println(io, "uuid = ", repr(uuid))
        println(io, "repo = ", repr(url))
    end

    # Versions.toml
    printstyled("  Versions.toml\n"; color=Base.info_color())
    write_toml(prefix, bucket, pkg, "Versions") do io
        for (i, (ver, v)) in enumerate(sort!(collect(p.versions), by=first))
            i > 1 && println(io)
            if !(haskey(trees, uuid) && haskey(trees[uuid], v.sha1))
                # FIXME: We keep getting this for DataFeatures
                @warn """
                    Unable to write version $ver to Versions.toml for $pkg:
                    The tree SHA $(v.sha1) could not be found.
                    """
                continue
            end
            println(io, "[", toml_key(string(ver)), "]")
            println(io, "git-tree-sha1 = ", repr(trees[uuid][v.sha1]))
        end
    end
    versions = sort!(collect(keys(p.versions)))

    function write_versions_data(f::Function, name::String; lt::Function=isless)
        data = Dict{VersionNumber,Dict{String,String}}()
        for (ver, v) in p.versions, (dep, d) in v.requires
            val = f(dep, d)
            val == nothing && continue
            haskey(data, ver) || (data[ver] = Dict{String,String}())
            # BinDeps injects a dependency on Libdl
            if name == "Deps" && dep == "BinDeps"
                data[ver]["Libdl"] = "\"8f399da3-3557-5675-b5ff-fb832c97cbdb\""
            end
            data[ver][dep] = val
        end
        compressed = compress_versions_data(data, versions)
        !isempty(compressed) && write_toml(prefix, bucket, pkg, name) do io
            vers = unique(getindex.(compressed, 1))
            keys = sort!(unique(getindex.(compressed, 2)), lt=lt)
            what = (vers, keys)
            ord = (1, 2)
            for (i, x) in enumerate(what[ord[1]])
                i > 1 && println(io)
                println(io, "[", toml_key(x), "]")
                for y in what[ord[2]]
                    for t in compressed
                        t[ord[1]] == x && t[ord[2]] == y || continue
                        println(io, toml_key(y), " = ", t[3])
                    end
                end
            end
        end
    end

    # Deps.toml
    printstyled("  Deps.toml\n"; color=Base.info_color())
    write_versions_data("Deps") do dep, d
        dep == "julia" ? nothing : repr(string(pkgs[dep].uuid))
    end

    # Compat.toml
    printstyled("  Compat.toml\n"; color=Base.info_color())
    write_versions_data("Compat", lt=packagelt) do dep, d
        dep in STDLIBS ? nothing : versions_repr(compress_versions(
            d.versions, collect(keys(pkgs[dep].versions))
        ))
    end

    printstyled("  Done\n"; color=Base.info_color())
end
