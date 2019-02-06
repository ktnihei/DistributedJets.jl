using Revise

using Distributed

addprocs(2)

@everywhere using Revise

@everywhere using DistributedArrays, DistributedJets, Jets, Test

@everywhere JopFoo_df!(d,m;diagonal,kwargs...) = d .= diagonal .* m
@everywhere function JopFoo(diag)
    spc = JetSpace(Float64, length(diag))
    JopLn(;df! = JopFoo_df!, df′! = JopFoo_df!, dom = spc, rng = spc, s = (diagonal=diag,))
end

@everywhere JopBar_f!(d,m) = d .= m.^2
@everywhere JopBar_df!(δd,δm;mₒ,kwargs...) = δd .= 2 .* mₒ .* δm
@everywhere function JopBar(n)
    spc = JetSpace(Float64, n)
    JopNl(f! = JopBar_f!, df! = JopBar_df!, df′! = JopBar_df!, dom = spc, rng = spc)
end

@everywhere JopBaz_df!(d,m;A,kwargs...) = d .= A*m
@everywhere JopBaz_df′!(m,d;A,kwargs...) = m .= A'*d
@everywhere function JopBaz(A)
    dom = JetSpace(eltype(A), size(A,2))
    rng = JetSpace(eltype(A), size(A,1))
    JopLn(;df! = JopBaz_df!, df′! = JopBaz_df′!, dom = dom, rng = rng, s = (A=A,))
end

@testset "DArray irregular construction" for T in (Float32,Float64,Complex{Float32},Complex{Float64})
    A = DArray(I->myid()*ones(T,length(I[1]),length(I[2])), workers(), [1:2,3:10], [1:2])
    @test size(A) == (10,2)
    @test A.indices[1] == (1:2, 1:2)
    @test A.indices[2] == (3:10, 1:2)
    @test indices(A,1) == [1:2,3:10]
    @test indices(A,2) == [1:2]
    @test fetch(@spawnat procs(A)[1] all(a->a≈T(myid()), localpart(A)))
    @test fetch(@spawnat procs(A)[2] all(a->a≈T(myid()), localpart(A)))
    A = DArray(I->myid()*ones(length(I[1])), workers(), [1:2,3:10])
    @test size(A) == (10,)
    @test A.indices[1] == (1:2,)
    @test A.indices[2] == (3:10,)
    @test indices(A,1) == [1:2,3:10]
end

@testset "JetDSpace construction" begin
    A = @blockop DArray(I->[JopFoo(rand(2)) for i in I[1], j in I[2]], (2,1))
    R = range(A)
    @test size(R) == (4,)
    @test length(R) == 4
    @test eltype(R) == Float64
    @test eltype(typeof(R)) == Float64
    @test ndims(R) == 1
    @test indices(R) == [1:2,3:4]
    @test procs(R) == workers()
end

#@testset "JedDSpace operations" begin
A = @blockop DArray(I->[JopFoo(rand(2)) for i in I[1], j in I[2]], (2,1))
R = range(A)
@test dzeros(4) ≈ zeros(R)
@test dones(4) ≈ ones(R)
d = rand(R)
_d = drand(4)
@test size(d) == size(_d)
@test d.cuts == _d.cuts
@test d.indices == _d.indices
d = Array(R)
@test size(d) == size(_d)
@test d.cuts == _d.cuts
@test d.indices == _d.indices

x = block(d,R,1)
x .= π
block!(d,R,1,x)
@test d[1:2] ≈ [π,π]

#end

@everywhere function myblocks(i,j)

end

@testset "JopDBlock" begin
    function
end

#
#
#
using Distributed
addprocs(2)
@everywhere using DistributedJets, Jets

ops = DArray(I->[JopFoo(10) for i in I[1], j in I[2]], (3,4), workers(), [2,1])

A = @blockop ops

domain(A)
range(A)

indices(ops,1)
indices(ops,2)

n1,n2 = length(indices(ops, 1)),length(indices(ops, 2))
@everywhere function build(I, ops)
    irng = DistributedJets.indices(ops,1)[I[1][1]]
    jrng = DistributedJets.indices(ops,2)[I[2][1]]
    A = [ops[i,j] for i in irng, j in jrng]
    [Jets.JopBlock(A) for k=1:1, j=1:1]
end

_ops = DArray(I->build(I,ops), (n1,n2), workers(), [n1,n2])

_ops[1,1]
_ops[2,1]
