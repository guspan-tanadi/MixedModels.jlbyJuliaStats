"""
like `copy!` but allowing for heterogeneous matrix types
"""
inject!(d,s) = copy!(d,s)               # fallback method

function inject!(d::UpperTriangular,s::UpperTriangular)
    if (n = size(s,2)) ≠ size(d,2)
        throw(DimensionMismatch("size(s,2) ≠ size(d,2)"))
    end
    for j in 1:n
        inject!(sub(d,1:j,j),sub(s,1:j,j))
    end
    d
end

function inject!{T<:Real}(d::StridedMatrix{T}, s::Diagonal{T})
    sd = s.diag
    if length(sd) ≠ Compat.LinAlg.checksquare(d)  # why does d have to be square?
        throw(DimensionMismatch("size(d,2) ≠ size(s,2)"))
    end
    fill!(d, zero(T))
    @inbounds for i in eachindex(sd)
        d[i,i] = sd[i]
    end
    d
end

inject!(d::Diagonal{Float64},s::Diagonal{Float64}) = (copy!(d.diag,s.diag);d)

function inject!(d::SparseMatrixCSC{Float64},s::SparseMatrixCSC{Float64})
    m,n = size(d)
    if size(d) ≠ size(s)
        throw(DimensionMismatch("size(d) ≠ size(s)"))
    end
    if nnz(d) == nnz(s)  # should also check that colptr
        copy!(nonzeros(d),nonzeros(s))
        return d
    end
    drv = rowvals(d); srv = rowvals(s); dnz = nonzeros(d); snz = nonzeros(s)
    fill!(dnz,0.)
    for j in 1:n
        dnzr = nzrange(d, j)
        dnzrv = sub(drv, dnzr)
        snzr = nzrange(s, j)
        if length(snzr) == length(dnzr) && all(dnzrv .== sub(srv, snzr))
            copy!(sub(dnz, dnzr),sub(snz, snzr))
        else
            for k in snzr
                ssr = srv[k]
                kk = searchsortedfirst(dnzrv, ssr)
#                @show k, ssr, dnzrv, kk, length(dnzrv), kk > length(dnzrv)
                if kk > length(dnzrv) || dnzrv[kk] != ssr
                    throw(ArgumentError("cannot inject sparse s into sparse d"))
                end
                dnz[dnzr[kk]] = snz[k]
            end
        end
    end
    d
end
