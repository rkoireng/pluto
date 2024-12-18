### A Pluto.jl notebook ###
# v0.19.36

using Markdown
using InteractiveUtils

# ╔═╡ d73472ff-9e09-45b0-8811-b7dd8d820358
using Flux, MLUtils, Statistics, PlutoUI

# ╔═╡ 97ae4222-5a3e-4cbd-b4d1-aa028d3e4ca8
TableOfContents()

# ╔═╡ 26fb86d5-c844-469a-aef5-ed3c2a9ba949
xpu = gpu

# ╔═╡ d38ed782-19f0-403e-83d2-2b9069b43949
activation = x->leakyrelu(x, 0.1)

# ╔═╡ 29d41554-3a0a-4972-a9e5-54c998429acd
md"## Data Generator"

# ╔═╡ 87c020ab-3730-430c-8340-104a10c83006
"""
Returns BatchView for each state, after shuffling the instances and picking `ntau` at a time.
"""
function get_batchviews(dvec, ntau)
	X = map(dvec) do d
	d = dropdims(d ,dims=2) 
	BatchView(shuffleobs(ObsView(d)), batchsize=ntau, partial=false)
end
	return X
end

# ╔═╡ 2b4bedc7-7d63-4a36-b203-c1b127c46abd
"""
X is generates using get_batchviews, use this method to sample a datapoint of a given batchsize from X.
"""
function sample(dvec; batchsize , ntau=20)
	X = get_batchviews(dvec, ntau)
stack(map(1:batchsize) do i
	randobs(randobs(X))
end
	, dims=3)
end

# ╔═╡ 6597a8f3-2396-4892-a28f-17f709df237a
#sample(dvec, 2, ntau=3)

# ╔═╡ ae96f920-5828-4c5f-b69f-48d8c4fee378
md"## Dense Networks"

# ╔═╡ 96aebf7d-2112-4a4d-9993-6f53f40ffca5

function generate_dense_chain(nt, p, num_layers, output_activation,  flat_flag=false, )
	if(flat_flag)
		lp = fill(max(nt, p), num_layers+1)
	else
		lp = floor.(Int, LinRange(nt, p, num_layers+1))
	end
    layers = []

    # Add input layer
    push!(layers, Dense(nt, lp[2], activation))

    # Add hidden layers
    for il in 2:num_layers-1
        push!(layers, Dense(lp[il], lp[il+1], activation))
	end

    # Add output layer
    push!(layers, Dense(lp[num_layers], p, output_activation))

    return layers
end

# ╔═╡ 4cc4fea4-2a3b-11ee-1341-d7fa7529b14a
## get networks
function get_dense_networks(nt, p, q, nt0_enc=div(nt, 2), nt0_dec=nt0_enc, flat_flag=false, )

	num_layers = 5
	@assert nt0_enc <= nt
	@assert nt0_dec <= nt

	if(nt0_enc == nt)
		downsample = identity
	else
		downsample = Chain(generate_dense_chain(nt, nt0_enc, 2, activation)...)
	end
	if(nt0_dec == nt)
		upsample = identity
	else
		upsample = Chain(generate_dense_chain(nt0_dec, nt, 2, identity)...)
	end

	
    senc = Chain(downsample, generate_dense_chain(nt0_enc, p, num_layers, activation, flat_flag)...) |> xpu

	# instance means
	senc_μ = Chain(Dense(p, p)) |> xpu

	# inverse variances
    senc_loginvvar = Chain(Dense(p, p)) |> xpu

    nenc = Chain(downsample, generate_dense_chain(nt0_enc, q, num_layers, activation,  flat_flag)...) |> xpu
	
    # produce logσ for the nuisance encoder
    nenc_μ = Chain(Dense(q, q)) |> xpu
    nenc_logσ = Chain(Dense(q, q)) |> xpu

    dec = Chain(generate_dense_chain(p + q, nt0_dec, num_layers, identity, flat_flag)..., upsample) |> xpu

	dec_logvar = xpu(cat(1f0, dims=3))
	
    return (; senc, senc_μ, senc_loginvvar, nenc, nenc_μ, nenc_logσ, dec, dec_logvar)
end

# ╔═╡ 747680b0-3469-426c-8b9e-4ab8ca04a6de
md"## Convolutional Networks"

# ╔═╡ 61297fb8-3da8-4b5c-9fe5-fe9adc382e8d
# begin
# nf=50
#     len=20
# 	# senc = Chain(generate_dense_chain(nt, p, 5, activation)...) |> xpu
#     senc =
#         Chain(
#         Conv((len,2), 1 => nf, activation, ; pad=SamePad()), # nt = 700
# 		#Conv((len,), nf => nf, activation, ; pad=SamePad()),
# 		MeanPool((5,1)), #
# 		Conv((len,2), nf => nf, activation, ; pad=SamePad()), # nt = 125
# 		Conv((len,2), nf => nf, activation, ; pad=SamePad()), # nt = 125
# 		MeanPool((2,1)),
# 		Conv((len,2), nf => 16, activation, ; pad=SamePad()), # nt = 125
# 		# BatchNorm(nf),
#         #MeanPool((2,)),
# 		# Conv((len,2), nf => 2, activation, ; pad=SamePad()),
# 		 x -> Flux.flatten(x),
# 		#generate_dense_chain(8*div(nt, 5*2), p, 1, activation)...
# 		Dense(16*2*div(nt,5*2),p,activation)
#         )
# end

# ╔═╡ f15ca5b5-42aa-4094-b0f3-81dd79206086
# ╠═╡ disabled = true
#=╠═╡
d1=Chain(Dense(1000,10,activation),)
  ╠═╡ =#

# ╔═╡ b8ee77f8-f21e-488e-bdd6-7850511fc916


# ╔═╡ 5f2d0b04-2996-450b-958f-912da3030d9e
begin
vrt=rand(Float32,100)
vrt=reshape(vrt,:,1,1)
end

# ╔═╡ a6eed27f-dfa7-45db-ab50-9a21b7f691bf
700/5

# ╔═╡ 5c35b60b-d163-4af4-a862-76377e76ffc1
1400/4

# ╔═╡ dc984d76-54e3-49df-82ec-c3cfd6c7c1f8
md"""
## 2D Conv
"""

# ╔═╡ 3cd03057-1294-44c3-b541-57c8db847617
## get networks
function get_2Dconv_networks(nt, p, q)
   activation = elu
	nf=[5,10,50,40]
    len=[50,20,5,5]
	# senc = Chain(generate_dense_chain(nt, p, 5, activation)...) |> xpu
    senc =
        Chain(
        Conv((len[1],3), 1 => nf[1], activation, ; pad=SamePad()), # nt = 700
		#Conv((len,3), nf => nf, activation, ; pad=SamePad()),
		MeanPool((5,1)), #
		Conv((len[2],3), nf[1] => nf[2], activation, ; pad=SamePad()), # nt = 125
		Conv((len[3],3), nf[2] => nf[3], activation, ; pad=SamePad()), # nt = 125
		#MeanPool((2,1)),
		#Conv((len,3), nf => 16, activation, ; pad=SamePad()), # nt = 125
		# BatchNorm(nf),
        MeanPool((2,1)),
		 Conv((len[end],3), nf[3] => nf[end] , activation, ; pad=SamePad()),
		x -> Flux.flatten(x),
		generate_dense_chain(nf[4]*3*div(nt, 5*2), q, 3, activation)...,
        ) |> xpu

     #s1= Chain(generate_dense_chain(nf[4]*1*div(nt,5*2*2),p,3,activation)...,) |> xpu


	# instance means
	senc_μ = Chain(Dense(p, p)) |> xpu

	# inverse variances
    senc_loginvvar = Chain(Dense(p, p)) |> xpu

	
    # nenc = Chain(generate_dense_chain(nt, q, 5, activation)...) |> xpu
	nenc = 
		# input size: nt, 2, 1, nb
        Chain(
        Conv((len[1],3), 1 => nf[1], activation, ; pad=SamePad()), # nt = 700
		MeanPool((5,1)),
		Conv((len[2],3), nf[1] => nf[2], activation, ; pad=SamePad()),
		Conv((len[2],3), nf[2] => nf[3], activation, ; pad=SamePad()),
		 MeanPool((2,1)),
		#Conv((len,), nf => 20, activation, ; pad=SamePad()), # nt = 125
		Conv((len[end],3), nf[3] => nf[end], activation, ; pad=SamePad()), # nt = 125
		 x -> Flux.flatten(x),
		generate_dense_chain(nf[end]*3*div(nt, 5*2), q, 3, activation)...,
		
		) |> xpu

    # produce logσ for the nuisance encoder
    nenc_μ = Chain(Dense(q, q)) |> xpu
    nenc_logσ = Chain(Dense(q, q)) |> xpu
	
    dnf=[40,10,5,5]
	dlen=[50,20,5,5]
    dec =
        Chain(
		generate_dense_chain(p+q,3*nt, 3, activation)...,
	    #Dense(p+q,3*nt,activation),
        x -> reshape(x, nt, 3, 1,size(x,2)),
        Conv((dlen[1],3), 1 => dnf[1], activation, ; pad=SamePad()),
	    Conv((dlen[2],3), dnf[1] => dnf[2], activation, ; pad=SamePad()),
		Conv((dlen[3],3), dnf[2] => dnf[3], activation, ; pad=SamePad()),
		 #Upsample((2,)),
		#Conv((len,), nf => 30, activation, ; pad=SamePad()),
		#Conv((len,), nf => nf, activation, ; pad=SamePad()),
		# BatchNorm(nf),	
        Conv((dlen[end],3), dnf[3] => dnf[end]; pad=SamePad()),
		Conv((dlen[end],3), dnf[end] => 1; pad=SamePad()),
		#x -> dropdims(x, dims=2),
        ) |> xpu

	#dec = Chain(generate_dense_chain(p+q, nt, 5, identity)...) |> xpu
	dec_logvar = xpu(cat(1f0, dims=2))
	
    return (; senc, senc_μ, senc_loginvvar, nenc, nenc_μ, nenc_logσ, dec, dec_logvar)
end

# ╔═╡ 54c7cd96-9faa-40ef-8ae4-b6a57749286b
md"""
## 1D Conv
"""

# ╔═╡ 7cfad366-59d8-4b74-a8ec-a283150d5ddf
## get networks
function get_conv_networks(nt, p, q)
	activation = elu
	nf=[5,10,50,40]
    len=[50,20,5,5]
	# senc = Chain(generate_dense_chain(nt, p, 5, activation)...) |> xpu
    senc=
        Chain(
        Conv((len[1],), 1 => nf[1], activation, ; pad=SamePad()), # nt = 700
		#Conv((len,), nf => nf, activation, ; pad=SamePad()),
		MeanPool((5,)), #
		Conv((len[2],), nf[1] => nf[2], activation, ; pad=SamePad()), # nt = 125
		#Conv((len,), nf => nf, activation, ; pad=SamePad()), # nt = 125
		Conv((len[3],), nf[2] => nf[3], activation, ; pad=SamePad()), # nt = 125
		MeanPool((2,)),
		Conv((len[4],), nf[3] => nf[end], activation, ; pad=SamePad()), # nt = 125
			
        x -> Flux.flatten(x),
        generate_dense_chain(nf[end]*1*div(nt, 5*2), p, 4, activation)...,
		) |> xpu
	
    #s1= Chain(generate_dense_chain(5*1*div(nt,5*2),p,5,activation)...,) |> xpu
	

	# instance means
	senc_μ = Chain(Dense(p, p)) |> xpu

	# inverse variances
    senc_loginvvar = Chain(Dense(p, p)) |> xpu

	
    # nenc = Chain(generate_dense_chain(nt, q, 5, activation)...) |> xpu
	nenc = 
		# input size: nt, 2, 1, nb
        Chain(
         Conv((len[1],), 1 => nf[1], activation, ; pad=SamePad()), # nt = 700
		#Conv((len,), nf => nf, activation, ; pad=SamePad()),
		MeanPool((5,)), #
		Conv((len[2],), nf[1] => nf[2], activation, ; pad=SamePad()), # nt = 125
		#Conv((len,), nf => nf, activation, ; pad=SamePad()), # nt = 125
		Conv((len[3],), nf[2] => nf[3], activation, ; pad=SamePad()), # nt = 125
		MeanPool((2,)),
		Conv((len[4],), nf[3] => nf[end], activation, ; pad=SamePad()), # nt = 125
			
        x -> Flux.flatten(x),
        generate_dense_chain(nf[end]*1*div(nt, 5*2), q, 4, activation)...,
		) |> xpu
		
	#n1=Chain(generate_dense_chain(5*1*div(nt,5*2),q,5,activation)...,
	#	) |> xpu

    # produce logσ for the nuisance encoder
    nenc_μ = Chain(Dense(q, q)) |> xpu
    nenc_logσ = Chain(Dense(q, q)) |> xpu

  #   d1 =
  #       Chain(
		# generate_dense_chain(p+q, 1*nt, 5, activation)...,
		# ) |> xpu
	   # Dense(p+q,3*nt,activation),) |> xpu
	dnf=[40,10,5,5]
	dlen=[50,20,5,5]
	dec = Chain(
		generate_dense_chain(p+q, 1*nt, 4, activation)...,
        x -> reshape(x, nt,1, size(x, 2)),
		Conv((dlen[1],), 1 => dnf[1], activation, ; pad=SamePad()),
	    Conv((dlen[2],), dnf[1] => dnf[2], activation, ; pad=SamePad()),
		Conv((dlen[3],), dnf[2] => dnf[3], activation, ; pad=SamePad()),
        Conv((dlen[end],), dnf[3] => dnf[end]; pad=SamePad()),
		Conv((dlen[end],), dnf[end] => 1; pad=SamePad()),
 
        ) |> xpu

	#dec = Chain(generate_dense_chain(p+q, nt, 5, identity)...) |> xpu
	dec_logvar = xpu(cat(1f0, dims=2))
	
    return (; senc, senc_μ, senc_loginvvar, nenc, nenc_μ, nenc_logσ, dec,dec_logvar)
end

# ╔═╡ 66bddc43-ca9f-43cd-85a3-d33b11a6c033
md"## Coherent Encoder"

# ╔═╡ 8684c192-d1b9-4821-a02e-2c7300af9b3c
begin
	struct BroadcastSenc
		chain::Chain
	    μ::Chain
	    loginvvar::Chain
	end

	
	Flux.@functor BroadcastSenc
	function (m::BroadcastSenc)(x)
	    x = cat(x, dims=3)
	    n = size(x)
	    X = reshape(x, n[1],1, n[2] * n[3])
	    X = m.chain(X)
  #       X = Flux.flatten(X)
		# X = m.d(X)

		
		μ = m.μ(X)
	    loginvvar = m.loginvvar(X)


		n1 = size(X)
	    μ = reshape(μ, n1[1:end-1]..., n[end-1], n[end])
		loginvvar = reshape(loginvvar, n1[1:end-1]..., n[end-1], n[end])
		
		invvar = exp.(loginvvar)
		
		invvarG = sum(invvar, dims=ndims(μ) - 1)

		varG = inv.(invvarG)
		
	    μG = sum(μ .* invvar, dims=ndims(μ) - 1)

		cμ = μG .* varG
	
	    X = dropdims(cμ, dims=ndims(μ) - 1)
       # X = reshape(X,:,1,n[3])
	    # X = reduce(hcat,fill(X, n[2]))
		X = Flux.stack(fill(X,n[2]),dims=2)
	    return X, cμ, 0.5f0 .* log.(varG)
	end
end

# ╔═╡ 52dc9696-3e0b-42c7-b6cf-7a07ca3cb4dd
md"## Nuisance Encoder"

# ╔═╡ fa646879-158a-4cbb-be0e-d375cf486ba0
begin
	struct BroadcastNenc
	    chain::Chain
		μ::Chain
		logσ::Chain
	end
	Flux.@functor BroadcastNenc
	function (m::BroadcastNenc)(x)
	    x = cat(x, dims=3)
		n = size(x)
	    X = reshape(x, n[1],1, n[2] * n[3])
	    X = m.chain(X)
		# X = Flux.flatten(X)
		# X = m.n1(X)
		Xμ = m.μ(X)
		Xlogσ = m.logσ(X)
	    Xμ = reshape(Xμ, :, n[end-1], n[end])
		Xlogσ = reshape(Xlogσ, :, n[end-1], n[end])
	    return Xμ, Xlogσ
	end
end

# ╔═╡ eafab001-87a7-423f-917f-1fbd46699186
md"## Decoder"

# ╔═╡ 237ad98e-75db-41fc-b378-b895facdd8d9
begin
	struct BroadcastDec{T}
	    chain::Chain
		logvar::T
	end
	Flux.@functor BroadcastDec
	function (m::BroadcastDec)(x)
	    x = cat(x, dims=3)
	    n1, n2, n3 = size(x)
	    X = reshape(x, :, n2 * n3)
	    #Xμ = m.d1(X)
		#Xμ = reshape(Xμ,:,1,size(Xμ, 2))
		Xμ = m.chain(X)
		Xμ = dropdims(Xμ,dims=2)
	    Xμ = reshape(Xμ, :,n2, n3)
	    return Xμ, m.logvar
	end
end

# ╔═╡ 5ed89ee8-325b-4757-b348-e6c1a3d277ad
md"## Reconstruct"

# ╔═╡ 946dd278-7ec4-4088-b63e-a7b05922f97e
# CUDA.device!(1)

# ╔═╡ 64d8bf8a-5ee2-463d-ba90-81bb188962ef
# begin
# NN = get_conv_networks(350, 300, 30)
# #NN = symae.get_conv_networks(div(data.nt,2), data.p, data.q)

#     sencb = BroadcastSenc(NN.senc, NN.senc_μ, NN.senc_loginvvar)

#     nencb = BroadcastNenc(NN.nenc, NN.nenc_μ, NN.nenc_logσ)

#     decb = BroadcastDec(NN.dec, NN.dec_logvar)

# var=stack(fill(randn(350,2),200),dims=3) |> xpu
# var=reshape(var,350,2,20,10)
# cx, cμ, clogσ = sencb(var)
# nμ, nlogσ =nencb(var)

#  nx = nμ + xpu(randn(Float32, size(nlogσ))) .* exp.(nlogσ)
		
# xhat, xhat_logvar = decb(cat(cx, nx, dims=1))
# end


# ╔═╡ 04f9b328-edc8-4b1e-9a7c-79a215b1cf5f
begin
	struct Reconstruct{T1,T2,T3}
    sencb::T1
    nencb::T2
	decb::T3
	end
	function (m::Reconstruct)(x, noise=true)
	    cx, cμ, clogσ = m.sencb(x)
	
	    nμ, nlogσ = m.nencb(x)

		if(noise)
			nx = nμ + xpu(randn(Float32, size(nlogσ))) .* exp.(nlogσ)
		else
			nx = nμ
		end

	    xhat, xhat_logvar = m.decb(cat(cx, nx, dims=1))

		return cx, nμ, nlogσ, xhat, xhat_logvar, cμ, clogσ
	end
	Flux.@functor Reconstruct
end

# ╔═╡ d74b7838-98c4-4356-8a0d-1a2388369788
begin
	struct Reconstruct_Dropout{T1,T2,T3}
    sencb::T1
    nencb::T2
	decb::T3
	end
	function (m::Reconstruct_Dropout)(x,dp,noise=true)
	    cx, cμ, clogσ = m.sencb(x)
	
	    nμ, nlogσ = m.nencb(x)

		if(noise)
			nx = dropout(nμ, dp) 
		else
			nx = nμ
		end
	
	    xhat, xhat_logvar = m.decb(cat(cx, nx, dims=1))

		return cx, nμ, nlogσ, xhat, xhat_logvar, cμ, clogσ
	end
	Flux.@functor Reconstruct
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
Flux = "587475ba-b771-5e3f-ad9e-33799f191a9c"
MLUtils = "f1d291b0-491e-4a28-83b9-f70985020b54"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[compat]
Flux = "~0.13.17"
MLUtils = "~0.4.3"
PlutoUI = "~0.7.51"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.9.3"
manifest_format = "2.0"
project_hash = "8ff2b0f8ea1a9b16f3b6e4c42861bf8fdea1253e"

[[deps.AbstractFFTs]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "16b6dbc4cf7caee4e1e75c49485ec67b667098a0"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.3.1"
weakdeps = ["ChainRulesCore"]

    [deps.AbstractFFTs.extensions]
    AbstractFFTsChainRulesCoreExt = "ChainRulesCore"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "8eaf9f1b4921132a4cff3f36a1d9ba923b14a481"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.1.4"

[[deps.Adapt]]
deps = ["LinearAlgebra", "Requires"]
git-tree-sha1 = "76289dc51920fdc6e0013c872ba9551d54961c24"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.6.2"
weakdeps = ["StaticArrays"]

    [deps.Adapt.extensions]
    AdaptStaticArraysExt = "StaticArrays"

[[deps.ArgCheck]]
git-tree-sha1 = "a3a402a35a2f7e0b87828ccabbd5ebfbebe356b4"
uuid = "dce04be8-c92d-5529-be00-80e4d2c0e197"
version = "2.3.0"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Atomix]]
deps = ["UnsafeAtomics"]
git-tree-sha1 = "c06a868224ecba914baa6942988e2f2aade419be"
uuid = "a9b6321e-bd34-4604-b9c9-b65b8de01458"
version = "0.1.0"

[[deps.BFloat16s]]
deps = ["LinearAlgebra", "Printf", "Random", "Test"]
git-tree-sha1 = "dbf84058d0a8cbbadee18d25cf606934b22d7c66"
uuid = "ab4f0b2a-ad5b-11e8-123f-65d77653426b"
version = "0.4.2"

[[deps.BangBang]]
deps = ["Compat", "ConstructionBase", "InitialValues", "LinearAlgebra", "Requires", "Setfield", "Tables"]
git-tree-sha1 = "e28912ce94077686443433c2800104b061a827ed"
uuid = "198e06fe-97b7-11e9-32a5-e1d131e6ad66"
version = "0.3.39"

    [deps.BangBang.extensions]
    BangBangChainRulesCoreExt = "ChainRulesCore"
    BangBangDataFramesExt = "DataFrames"
    BangBangStaticArraysExt = "StaticArrays"
    BangBangStructArraysExt = "StructArrays"
    BangBangTypedTablesExt = "TypedTables"

    [deps.BangBang.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
    StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
    TypedTables = "9d95f2ec-7b3d-5a63-8d20-e2491e220bb9"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.Baselet]]
git-tree-sha1 = "aebf55e6d7795e02ca500a689d326ac979aaf89e"
uuid = "9718e550-a3fa-408a-8086-8db961cd8217"
version = "0.1.1"

[[deps.CEnum]]
git-tree-sha1 = "eb4cb44a499229b3b8426dcfb5dd85333951ff90"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.4.2"

[[deps.CUDA]]
deps = ["AbstractFFTs", "Adapt", "BFloat16s", "CEnum", "CUDA_Driver_jll", "CUDA_Runtime_Discovery", "CUDA_Runtime_jll", "CompilerSupportLibraries_jll", "ExprTools", "GPUArrays", "GPUCompiler", "KernelAbstractions", "LLVM", "LazyArtifacts", "Libdl", "LinearAlgebra", "Logging", "Preferences", "Printf", "Random", "Random123", "RandomNumbers", "Reexport", "Requires", "SparseArrays", "SpecialFunctions", "UnsafeAtomicsLLVM"]
git-tree-sha1 = "442d989978ed3ff4e174c928ee879dc09d1ef693"
uuid = "052768ef-5323-5732-b1bb-66c8b64840ba"
version = "4.3.2"

[[deps.CUDA_Driver_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl", "Pkg"]
git-tree-sha1 = "498f45593f6ddc0adff64a9310bb6710e851781b"
uuid = "4ee394cb-3365-5eb0-8335-949819d2adfc"
version = "0.5.0+1"

[[deps.CUDA_Runtime_Discovery]]
deps = ["Libdl"]
git-tree-sha1 = "bcc4a23cbbd99c8535a5318455dcf0f2546ec536"
uuid = "1af6417a-86b4-443c-805f-a4643ffb695f"
version = "0.2.2"

[[deps.CUDA_Runtime_jll]]
deps = ["Artifacts", "CUDA_Driver_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "TOML"]
git-tree-sha1 = "5248d9c45712e51e27ba9b30eebec65658c6ce29"
uuid = "76a88914-d11a-5bdc-97e0-2f5a05c973a2"
version = "0.6.0+0"

[[deps.CUDNN_jll]]
deps = ["Artifacts", "CUDA_Runtime_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "TOML"]
git-tree-sha1 = "2918fbffb50e3b7a0b9127617587afa76d4276e8"
uuid = "62b44479-cb7b-5706-934f-f13b2eb2e645"
version = "8.8.1+0"

[[deps.ChainRules]]
deps = ["Adapt", "ChainRulesCore", "Compat", "Distributed", "GPUArraysCore", "IrrationalConstants", "LinearAlgebra", "Random", "RealDot", "SparseArrays", "Statistics", "StructArrays"]
git-tree-sha1 = "61549d9b52c88df34d21bd306dba1d43bb039c87"
uuid = "082447d4-558c-5d27-93f4-14fc19e9eca2"
version = "1.51.0"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "e30f2f4e20f7f186dc36529910beaedc60cfa644"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.16.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "eb7f0f8307f71fac7c606984ea5fb2817275d6e4"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.4"

[[deps.CommonSubexpressions]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "7b8a93dba8af7e3b42fecabf646260105ac373f7"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.0"

[[deps.Compat]]
deps = ["UUIDs"]
git-tree-sha1 = "7a60c856b9fa189eb34f5f8a6f6b5529b7942957"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.6.1"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.0.5+0"

[[deps.CompositionsBase]]
git-tree-sha1 = "802bb88cd69dfd1509f6670416bd4434015693ad"
uuid = "a33af91c-f02d-484b-be07-31d278c5ca2b"
version = "0.1.2"

    [deps.CompositionsBase.extensions]
    CompositionsBaseInverseFunctionsExt = "InverseFunctions"

    [deps.CompositionsBase.weakdeps]
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.ConstructionBase]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "738fec4d684a9a6ee9598a8bfee305b26831f28c"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.5.2"

    [deps.ConstructionBase.extensions]
    ConstructionBaseIntervalSetsExt = "IntervalSets"
    ConstructionBaseStaticArraysExt = "StaticArrays"

    [deps.ConstructionBase.weakdeps]
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.ContextVariablesX]]
deps = ["Compat", "Logging", "UUIDs"]
git-tree-sha1 = "25cc3803f1030ab855e383129dcd3dc294e322cc"
uuid = "6add18c4-b38d-439d-96f6-d6bc489c04c5"
version = "0.1.3"

[[deps.DataAPI]]
git-tree-sha1 = "8da84edb865b0b5b0100c0666a9bc9a0b71c553c"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.15.0"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "d1fff3a548102f48987a52a2e0d114fa97d730f0"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.13"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DefineSingletons]]
git-tree-sha1 = "0fba8b706d0178b4dc7fd44a96a92382c9065c2c"
uuid = "244e2a9f-e319-4986-a169-4d1fe445cd52"
version = "0.1.2"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
git-tree-sha1 = "9e2f36d3c96a820c678f2f1f1782582fcf685bae"
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"
version = "1.9.1"

[[deps.DiffResults]]
deps = ["StaticArraysCore"]
git-tree-sha1 = "782dd5f4561f5d267313f23853baaaa4c52ea621"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.1.0"

[[deps.DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "23163d55f885173722d1e4cf0f6110cdbaf7e272"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.15.1"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "2fb1e02f2b635d0845df5d7c167fec4dd739b00d"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.3"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.ExprTools]]
git-tree-sha1 = "c1d06d129da9f55715c6c212866f5b1bddc5fa00"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.9"

[[deps.FLoops]]
deps = ["BangBang", "Compat", "FLoopsBase", "InitialValues", "JuliaVariables", "MLStyle", "Serialization", "Setfield", "Transducers"]
git-tree-sha1 = "ffb97765602e3cbe59a0589d237bf07f245a8576"
uuid = "cc61a311-1640-44b5-9fba-1b764f453329"
version = "0.2.1"

[[deps.FLoopsBase]]
deps = ["ContextVariablesX"]
git-tree-sha1 = "656f7a6859be8673bf1f35da5670246b923964f7"
uuid = "b9860ae5-e623-471e-878b-f6a53c775ea6"
version = "0.1.1"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "Statistics"]
git-tree-sha1 = "e17cc4dc2d0b0b568e80d937de8ed8341822de67"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "1.2.0"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.Flux]]
deps = ["Adapt", "CUDA", "ChainRulesCore", "Functors", "LinearAlgebra", "MLUtils", "MacroTools", "NNlib", "NNlibCUDA", "OneHotArrays", "Optimisers", "Preferences", "ProgressLogging", "Random", "Reexport", "SparseArrays", "SpecialFunctions", "Statistics", "Zygote", "cuDNN"]
git-tree-sha1 = "3e2c3704c2173ab4b1935362384ca878b53d4c34"
uuid = "587475ba-b771-5e3f-ad9e-33799f191a9c"
version = "0.13.17"

    [deps.Flux.extensions]
    AMDGPUExt = "AMDGPU"
    FluxMetalExt = "Metal"

    [deps.Flux.weakdeps]
    AMDGPU = "21141c5a-9bdb-4563-92ae-f87d6854732e"
    Metal = "dde4c033-4e86-420c-a63e-0dd931031962"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions"]
git-tree-sha1 = "00e252f4d706b3d55a8863432e742bf5717b498d"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.35"
weakdeps = ["StaticArrays"]

    [deps.ForwardDiff.extensions]
    ForwardDiffStaticArraysExt = "StaticArrays"

[[deps.Functors]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "478f8c3145bb91d82c2cf20433e8c1b30df454cc"
uuid = "d9f16b24-f501-4c13-a1f2-28368ffc5196"
version = "0.4.4"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.GPUArrays]]
deps = ["Adapt", "GPUArraysCore", "LLVM", "LinearAlgebra", "Printf", "Random", "Reexport", "Serialization", "Statistics"]
git-tree-sha1 = "a3351bc577a6b49297248aadc23a4add1097c2ac"
uuid = "0c68f7d7-f131-5f86-a1c3-88cf8149b2d7"
version = "8.7.1"

[[deps.GPUArraysCore]]
deps = ["Adapt"]
git-tree-sha1 = "2d6ca471a6c7b536127afccfa7564b5b39227fe0"
uuid = "46192b85-c4d5-4398-a991-12ede77f4527"
version = "0.1.5"

[[deps.GPUCompiler]]
deps = ["ExprTools", "InteractiveUtils", "LLVM", "Libdl", "Logging", "Scratch", "TimerOutputs", "UUIDs"]
git-tree-sha1 = "cb090aea21c6ca78d59672a7e7d13bd56d09de64"
uuid = "61eb1bfa-7361-4325-ad38-22787b887f55"
version = "0.20.3"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "8d511d5b81240fc8e6802386302675bdf47737b9"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.4"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "c47c5fa4c5308f27ccaac35504858d8914e102f9"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.4"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "d75853a0bdbfb1ac815478bacd89cd27b550ace6"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.3"

[[deps.IRTools]]
deps = ["InteractiveUtils", "MacroTools", "Test"]
git-tree-sha1 = "eac00994ce3229a464c2847e956d77a2c64ad3a5"
uuid = "7869d1d1-7146-5819-86e3-90919afe41df"
version = "0.4.10"

[[deps.InitialValues]]
git-tree-sha1 = "4da0f88e9a39111c2fa3add390ab15f3a44f3ca3"
uuid = "22cec73e-a1b8-11e9-2c92-598750a2cf9c"
version = "0.3.1"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.IrrationalConstants]]
git-tree-sha1 = "630b497eafcc20001bba38a4651b327dcfc491d2"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.2"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "abc9885a7ca2052a736a600f7fa66209f96506e1"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.4.1"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.JuliaVariables]]
deps = ["MLStyle", "NameResolution"]
git-tree-sha1 = "49fb3cb53362ddadb4415e9b73926d6b40709e70"
uuid = "b14d175d-62b4-44ba-8fb7-3064adc8c3ec"
version = "0.2.4"

[[deps.KernelAbstractions]]
deps = ["Adapt", "Atomix", "InteractiveUtils", "LinearAlgebra", "MacroTools", "PrecompileTools", "SparseArrays", "StaticArrays", "UUIDs", "UnsafeAtomics", "UnsafeAtomicsLLVM"]
git-tree-sha1 = "bd2a7271f9884dc0ffc057974c374aaaa531b36a"
uuid = "63c18a36-062a-441e-b654-da1e3ab1ce7c"
version = "0.9.5"

[[deps.LLVM]]
deps = ["CEnum", "LLVMExtra_jll", "Libdl", "Printf", "Unicode"]
git-tree-sha1 = "5007c1421563108110bbd57f63d8ad4565808818"
uuid = "929cbde3-209d-540e-8aea-75f648917ca0"
version = "5.2.0"

[[deps.LLVMExtra_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl", "TOML"]
git-tree-sha1 = "1222116d7313cdefecf3d45a2bc1a89c4e7c9217"
uuid = "dad2f222-ce93-54a1-a47d-0025e8a3acab"
version = "0.0.22+0"

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.3"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "7.84.0+0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.10.2+0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "c3ce8e7420b3a6e071e0fe4745f5d4300e37b13f"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.24"

    [deps.LogExpFunctions.extensions]
    LogExpFunctionsChainRulesCoreExt = "ChainRulesCore"
    LogExpFunctionsChangesOfVariablesExt = "ChangesOfVariables"
    LogExpFunctionsInverseFunctionsExt = "InverseFunctions"

    [deps.LogExpFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ChangesOfVariables = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MIMEs]]
git-tree-sha1 = "65f28ad4b594aebe22157d6fac869786a255b7eb"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "0.1.4"

[[deps.MLStyle]]
git-tree-sha1 = "bc38dff0548128765760c79eb7388a4b37fae2c8"
uuid = "d8e11817-5142-5d16-987a-aa16d5891078"
version = "0.4.17"

[[deps.MLUtils]]
deps = ["ChainRulesCore", "Compat", "DataAPI", "DelimitedFiles", "FLoops", "NNlib", "Random", "ShowCases", "SimpleTraits", "Statistics", "StatsBase", "Tables", "Transducers"]
git-tree-sha1 = "3504cdb8c2bc05bde4d4b09a81b01df88fcbbba0"
uuid = "f1d291b0-491e-4a28-83b9-f70985020b54"
version = "0.4.3"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "42324d08725e200c23d4dfb549e0d5d89dede2d2"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.10"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+0"

[[deps.MicroCollections]]
deps = ["BangBang", "InitialValues", "Setfield"]
git-tree-sha1 = "629afd7d10dbc6935ec59b32daeb33bc4460a42e"
uuid = "128add7d-3638-4c79-886c-908ea0c25c34"
version = "0.1.4"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "f66bdc5de519e8f8ae43bdc598782d35a25b1272"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.1.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.10.11"

[[deps.NNlib]]
deps = ["Adapt", "Atomix", "ChainRulesCore", "GPUArraysCore", "KernelAbstractions", "LinearAlgebra", "Pkg", "Random", "Requires", "Statistics"]
git-tree-sha1 = "72240e3f5ca031937bd536182cb2c031da5f46dd"
uuid = "872c559c-99b0-510c-b3b7-b6c96a88d5cd"
version = "0.8.21"

    [deps.NNlib.extensions]
    NNlibAMDGPUExt = "AMDGPU"

    [deps.NNlib.weakdeps]
    AMDGPU = "21141c5a-9bdb-4563-92ae-f87d6854732e"

[[deps.NNlibCUDA]]
deps = ["Adapt", "CUDA", "LinearAlgebra", "NNlib", "Random", "Statistics", "cuDNN"]
git-tree-sha1 = "f94a9684394ff0d325cc12b06da7032d8be01aaf"
uuid = "a00861dc-f156-4864-bf3c-e6376f28a68d"
version = "0.2.7"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "0877504529a3e5c3343c6f8b4c0381e57e4387e4"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.0.2"

[[deps.NameResolution]]
deps = ["PrettyPrint"]
git-tree-sha1 = "1a0fa0e9613f46c9b8c11eee38ebb4f590013c5e"
uuid = "71a1bf82-56d0-4bbc-8a3c-48b961074391"
version = "0.1.5"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.OneHotArrays]]
deps = ["Adapt", "ChainRulesCore", "Compat", "GPUArraysCore", "LinearAlgebra", "NNlib"]
git-tree-sha1 = "5e4029759e8699ec12ebdf8721e51a659443403c"
uuid = "0b1bfda6-eb8a-41d2-88d8-f5af5cad476f"
version = "0.2.4"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.21+4"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.1+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[deps.Optimisers]]
deps = ["ChainRulesCore", "Functors", "LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "6a01f65dd8583dee82eecc2a19b0ff21521aa749"
uuid = "3bd65402-5787-11e9-1adc-39752487f4e2"
version = "0.2.18"

[[deps.OrderedCollections]]
git-tree-sha1 = "d321bf2de576bf25ec4d3e4360faca399afca282"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.6.0"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "5a6ab2f64388fd1175effdf73fe5933ef1e0bac0"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.7.0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.9.2"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "b478a748be27bd2f2c73a7690da219d0844db305"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.51"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "9673d39decc5feece56ef3940e5dafba15ba0f81"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.1.2"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "7eb1686b4f04b82f96ed7a4ea5890a4f0c7a09f1"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.0"

[[deps.PrettyPrint]]
git-tree-sha1 = "632eb4abab3449ab30c5e1afaa874f0b98b586e4"
uuid = "8162dcfd-2161-5ef2-ae6c-7681170c5f98"
version = "0.2.0"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.ProgressLogging]]
deps = ["Logging", "SHA", "UUIDs"]
git-tree-sha1 = "80d919dee55b9c50e8d9e2da5eeafff3fe58b539"
uuid = "33c8b6b6-d38a-422a-b730-caa89a2f386c"
version = "0.1.4"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Random123]]
deps = ["Random", "RandomNumbers"]
git-tree-sha1 = "552f30e847641591ba3f39fd1bed559b9deb0ef3"
uuid = "74087812-796a-5b5d-8853-05524746bad3"
version = "1.6.1"

[[deps.RandomNumbers]]
deps = ["Random", "Requires"]
git-tree-sha1 = "043da614cc7e95c703498a491e2c21f58a2b8111"
uuid = "e6cf234a-135c-5ec9-84dd-332b85af5143"
version = "1.5.3"

[[deps.RealDot]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "9f0a1b71baaf7650f4fa8a1d168c7fb6ee41f0c9"
uuid = "c1ae055f-0cd5-4b69-90a6-9a35b1a98df9"
version = "0.1.0"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "30449ee12237627992a99d5e30ae63e4d78cd24a"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.2.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "StaticArraysCore"]
git-tree-sha1 = "e2cc6d8c88613c05e1defb55170bf5ff211fbeac"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "1.1.1"

[[deps.ShowCases]]
git-tree-sha1 = "7f534ad62ab2bd48591bdeac81994ea8c445e4a5"
uuid = "605ecd9f-84a6-4c9e-81e2-4798472b76a3"
version = "0.1.0"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "5d7e3f4e11935503d3ecaf7186eac40602e7d231"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.4"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "c60ec5c62180f27efea3ba2908480f8055e17cee"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.1.1"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.SpecialFunctions]]
deps = ["IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "ef28127915f4229c971eb43f3fc075dd3fe91880"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.2.0"
weakdeps = ["ChainRulesCore"]

    [deps.SpecialFunctions.extensions]
    SpecialFunctionsChainRulesCoreExt = "ChainRulesCore"

[[deps.SplittablesBase]]
deps = ["Setfield", "Test"]
git-tree-sha1 = "e08a62abc517eb79667d0a29dc08a3b589516bb5"
uuid = "171d559e-b47b-412a-8079-5efa626c420e"
version = "0.1.15"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "Random", "StaticArraysCore", "Statistics"]
git-tree-sha1 = "832afbae2a45b4ae7e831f86965469a24d1d8a83"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.5.26"

[[deps.StaticArraysCore]]
git-tree-sha1 = "6b7ba252635a5eff6a0b0664a41ee140a1c9e72a"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.0"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.9.0"

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "45a7769a04a3cf80da1c1c7c60caf932e6f4c9f7"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.6.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "75ebe04c5bed70b91614d684259b661c9e6274a4"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.34.0"

[[deps.StructArrays]]
deps = ["Adapt", "DataAPI", "GPUArraysCore", "StaticArraysCore", "Tables"]
git-tree-sha1 = "521a0e828e98bb69042fec1809c1b5a680eb7389"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.15"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "Pkg", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "5.10.1+6"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits", "Test"]
git-tree-sha1 = "1544b926975372da01227b382066ab70e574a3ec"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.10.1"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TimerOutputs]]
deps = ["ExprTools", "Printf"]
git-tree-sha1 = "f548a9e9c490030e545f72074a41edfd0e5bcdd7"
uuid = "a759f4b9-e2f1-59dc-863e-4aeb61b1ea8f"
version = "0.5.23"

[[deps.Transducers]]
deps = ["Adapt", "ArgCheck", "BangBang", "Baselet", "CompositionsBase", "DefineSingletons", "Distributed", "InitialValues", "Logging", "Markdown", "MicroCollections", "Requires", "Setfield", "SplittablesBase", "Tables"]
git-tree-sha1 = "25358a5f2384c490e98abd565ed321ffae2cbb37"
uuid = "28d57a85-8fef-5791-bfe6-a80928e7c999"
version = "0.4.76"

[[deps.Tricks]]
git-tree-sha1 = "aadb748be58b492045b4f56166b5188aa63ce549"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.7"

[[deps.URIs]]
git-tree-sha1 = "074f993b0ca030848b897beff716d93aca60f06a"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.4.2"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.UnsafeAtomics]]
git-tree-sha1 = "6331ac3440856ea1988316b46045303bef658278"
uuid = "013be700-e6cd-48c3-b4a1-df204f14c38f"
version = "0.2.1"

[[deps.UnsafeAtomicsLLVM]]
deps = ["LLVM", "UnsafeAtomics"]
git-tree-sha1 = "ea37e6066bf194ab78f4e747f5245261f17a7175"
uuid = "d80eeb9a-aca5-4d75-85e5-170c8b632249"
version = "0.1.2"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+0"

[[deps.Zygote]]
deps = ["AbstractFFTs", "ChainRules", "ChainRulesCore", "DiffRules", "Distributed", "FillArrays", "ForwardDiff", "GPUArrays", "GPUArraysCore", "IRTools", "InteractiveUtils", "LinearAlgebra", "LogExpFunctions", "MacroTools", "NaNMath", "PrecompileTools", "Random", "Requires", "SparseArrays", "SpecialFunctions", "Statistics", "ZygoteRules"]
git-tree-sha1 = "5be3ddb88fc992a7d8ea96c3f10a49a7e98ebc7b"
uuid = "e88e6eb3-aa80-5325-afca-941959d7151f"
version = "0.6.62"

    [deps.Zygote.extensions]
    ZygoteColorsExt = "Colors"
    ZygoteDistancesExt = "Distances"
    ZygoteTrackerExt = "Tracker"

    [deps.Zygote.weakdeps]
    Colors = "5ae59095-9a9b-59fe-a467-6f913c188581"
    Distances = "b4f34e82-e78d-54a5-968a-f98e89d6e8f7"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"

[[deps.ZygoteRules]]
deps = ["ChainRulesCore", "MacroTools"]
git-tree-sha1 = "977aed5d006b840e2e40c0b48984f7463109046d"
uuid = "700de1a5-db45-46bc-99cf-38207098b444"
version = "0.2.3"

[[deps.cuDNN]]
deps = ["CEnum", "CUDA", "CUDNN_jll"]
git-tree-sha1 = "f65490d187861d6222cb38bcbbff3fd949a7ec3e"
uuid = "02a925ec-e4fe-4b08-9a7e-0d78e3d38ccd"
version = "1.0.4"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.8.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.48.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+0"
"""

# ╔═╡ Cell order:
# ╠═97ae4222-5a3e-4cbd-b4d1-aa028d3e4ca8
# ╠═d73472ff-9e09-45b0-8811-b7dd8d820358
# ╠═26fb86d5-c844-469a-aef5-ed3c2a9ba949
# ╠═d38ed782-19f0-403e-83d2-2b9069b43949
# ╟─29d41554-3a0a-4972-a9e5-54c998429acd
# ╠═87c020ab-3730-430c-8340-104a10c83006
# ╠═2b4bedc7-7d63-4a36-b203-c1b127c46abd
# ╠═6597a8f3-2396-4892-a28f-17f709df237a
# ╟─ae96f920-5828-4c5f-b69f-48d8c4fee378
# ╠═96aebf7d-2112-4a4d-9993-6f53f40ffca5
# ╠═4cc4fea4-2a3b-11ee-1341-d7fa7529b14a
# ╟─747680b0-3469-426c-8b9e-4ab8ca04a6de
# ╠═61297fb8-3da8-4b5c-9fe5-fe9adc382e8d
# ╠═f15ca5b5-42aa-4094-b0f3-81dd79206086
# ╠═b8ee77f8-f21e-488e-bdd6-7850511fc916
# ╠═5f2d0b04-2996-450b-958f-912da3030d9e
# ╠═a6eed27f-dfa7-45db-ab50-9a21b7f691bf
# ╠═5c35b60b-d163-4af4-a862-76377e76ffc1
# ╠═dc984d76-54e3-49df-82ec-c3cfd6c7c1f8
# ╠═3cd03057-1294-44c3-b541-57c8db847617
# ╠═54c7cd96-9faa-40ef-8ae4-b6a57749286b
# ╠═7cfad366-59d8-4b74-a8ec-a283150d5ddf
# ╟─66bddc43-ca9f-43cd-85a3-d33b11a6c033
# ╠═8684c192-d1b9-4821-a02e-2c7300af9b3c
# ╟─52dc9696-3e0b-42c7-b6cf-7a07ca3cb4dd
# ╠═fa646879-158a-4cbb-be0e-d375cf486ba0
# ╟─eafab001-87a7-423f-917f-1fbd46699186
# ╠═237ad98e-75db-41fc-b378-b895facdd8d9
# ╟─5ed89ee8-325b-4757-b348-e6c1a3d277ad
# ╠═946dd278-7ec4-4088-b63e-a7b05922f97e
# ╠═64d8bf8a-5ee2-463d-ba90-81bb188962ef
# ╠═04f9b328-edc8-4b1e-9a7c-79a215b1cf5f
# ╠═d74b7838-98c4-4356-8a0d-1a2388369788
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002