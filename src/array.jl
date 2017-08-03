using CUDAdrv: OwnedPtr
using CUDAnative: DevicePtr

mutable struct CuArray{T,N} <: DenseArray{T,N}
  ptr::OwnedPtr{T}
  dims::NTuple{N,Int}
end

function CuArray{T,N}(dims::NTuple{N,Integer}) where {T,N}
  xs = CuArray{T,N}(Mem.alloc(T, prod(dims)), dims)
  finalizer(xs, unsafe_free!)
  return xs
end

CuArray{T}(dims::NTuple{N,Integer}) where {T,N} =
  CuArray{T,N}(dims)

CuArray(dims::NTuple{N,Integer}) where N = CuArray{Float64,N}(dims)

Base.similar(a::CuArray, ::Type{T}, dims::Base.Dims{N}) where {T,N} =
  CuArray{T,N}(dims)

function unsafe_free!(xs::CuArray)
  CUDAdrv.isvalid(xs.ptr.ctx) && Mem.free(xs.ptr)
  return
end

Base.size(x::CuArray) = x.dims
Base.sizeof(x::CuArray) = Base.elsize(x) * length(x)

function Base.copy!{T}(dst::CuArray{T}, src::DenseArray{T})
    @assert length(dst) == length(src)
    Mem.upload(dst.ptr, pointer(src), length(src) * sizeof(T))
    return dst
end

function Base.copy!{T}(dst::DenseArray{T}, src::CuArray{T})
    @assert length(dst) == length(src)
    Mem.download(pointer(dst), src.ptr, length(src) * sizeof(T))
    return dst
end

function Base.copy!{T}(dst::CuArray{T}, src::CuArray{T})
    @assert length(dst) == length(src)
    Mem.transfer(dst.ptr, src.ptr, length(src) * sizeof(T))
    return dst
end

Base.convert(::Type{CuArray{T,N}}, xs::DenseArray{T,N}) where {T,N} =
  copy!(CuArray{T,N}(size(xs)), xs)

Base.convert(::Type{CuArray}, xs::DenseArray{T,N}) where {T,N} =
  convert(CuArray{T,N}, xs)

function Base.convert(::Type{CuDeviceArray{T,N,AS.Global}}, a::CuArray{T,N}) where {T,N}
    ptr = Base.unsafe_convert(Ptr{T}, a.ptr)
    CuDeviceArray{T,N,AS.Global}(a.dims, DevicePtr{T,AS.Global}(ptr))
end

CUDAnative.cudaconvert(a::CuArray{T,N}) where {T,N} = convert(CuDeviceArray{T,N,AS.Global}, a)
CUDAnative.cudaconvert(a::Tuple) = CUDAnative.cudaconvert.(a)

cu(x) = x
cu(x::CuArray) = x

cu(xs::AbstractArray) = isbits(xs) ? xs : CuArray(xs)

Base.getindex(::typeof(cu), xs...) = CuArray([xs...])