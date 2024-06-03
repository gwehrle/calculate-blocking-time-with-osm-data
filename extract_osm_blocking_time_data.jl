### A Pluto.jl notebook ###
# v0.19.42

using Markdown
using InteractiveUtils

# ╔═╡ d0095fd5-120d-4567-a9c1-89ac4fe95546
begin
	import Pkg;
	Pkg.add("DataFrames");
	Pkg.add("JSON3");
	Pkg.add("Geodesy");
	Pkg.add("CairoMakie");
	Pkg.add("GeoMakie");
	Pkg.add("IterTools");
	Pkg.add("CircleFit");
	Pkg.add("HTTP");
	Pkg.add("EasyFit");
	Pkg.add("Interpolations");
	Pkg.add("PlutoUI");
	Pkg.add("YAML");
end

# ╔═╡ a127931d-c0fa-4302-8c47-c7d89ded7987
using JSON3;

# ╔═╡ c44c30bf-1720-49c4-927e-e1fcbf9db687
using DataFrames;

# ╔═╡ 2fad0fb7-fdcd-4b43-a16a-4f5a64e672d9
using Geodesy;

# ╔═╡ ce18fb48-ff76-4da1-b070-acd06dc7cdb4
using IterTools, CircleFit;

# ╔═╡ f89da717-e534-4774-b5ee-e70cc265c3c1
using GeoMakie, CairoMakie;

# ╔═╡ 28c53785-3834-4e60-bf70-5ab9834890e5
using EasyFit, Interpolations;

# ╔═╡ 4e3543e3-1d7c-483a-8670-2c39fd198bbb
using YAML

# ╔═╡ 158b97dd-d7b9-4818-b470-93447e984556
using PlutoUI

# ╔═╡ e0cde4b0-cb81-4c62-a163-ab7311b7e6c9
md"# Setup"

# ╔═╡ b7e7ecb6-03f2-4844-949b-51cce11266ce
md"# Get Overpass Data"

# ╔═╡ c91e3dc9-1f3c-4a36-be05-342390a02e1e
# ╠═╡ disabled = true
#=╠═╡
begin
	way_ids_bs_wolfenbuettel = [
		42401019,
		42401020,
		413682966,
		421341112,
		413682970,
		42400880,
		42400881,
		42400882,
		42400883,
		136701521,
		42400884,
		175499870,
	];
	starting_point_id = 529379395;
	wayIds = join(way_ids_bs_wolfenbuettel, ",");
	filename = "bs_wolfenbuettel_v1"
end
  ╠═╡ =#

# ╔═╡ 12659906-a692-402f-bfb5-6cebc1529e9c
begin
	way_ids_roetgesbuettel_gifhorn = [
		823159220,
		909376489,
		515354711,
		23657867,
		515354714,
		23657868,
		1289051667,
		515354717,
		293217428,
		515354722,
		515354723,
		293217429,
		25265683,
		25265683,
		25265462,
		38358480,
		1289051668,
		13489243,
		948517342,
		1289051669,
		170660006,
		170660004,
		170660005,
		170660003,
		30138463,
	];
	starting_point_id = 7685218110;
	wayIds = join(way_ids_roetgesbuettel_gifhorn, ",");
	filename = "roetgesbuettel_gifhorn_2"
end

# ╔═╡ de1771ff-5266-4057-882d-0c08453684ae
begin
	using HTTP
	response = ""
	overpass_response_file = "./$filename.overpass.json"
	overpass_endpoint = "https://overpass-api.de/api/interpreter"
	# overpass_endpoint = "https://maps.mail.ru/osm/tools/overpass/api/interpreter"
	
	if !isfile(overpass_response_file)
		# response = String(HTTP.post(overpass_endpoint,body=overpass_string).body)	
		# write(overpass_response_file, response)
	end
end

# ╔═╡ 45966a87-5baa-4c53-9afb-b52ccefb7932
md"## Download data
Request Data via Overpass API from OpenStreetMap and save it to JSON file
"

# ╔═╡ 70c06ad5-f87b-4c2c-90a1-749ca37677db
overpass_string = "[out:json][timeout:25];
(
	way(id:$wayIds);
	node(w)[~\".\"~\".\"]; // 
);
out geom;";

# ╔═╡ 4b66e66c-afee-40d6-8d3a-48185ca762ee
overpass_string

# ╔═╡ af481143-32e2-4626-b35c-2052157e0865
md"## Read and parse overpass data"

# ╔═╡ 901724b5-9888-43e8-8cb5-fe7f635114c8
overpass_data = JSON3.read(read(overpass_response_file, String));

# ╔═╡ 4899b953-ef2e-417a-b746-9a79ad9a7cc7
md"# Create DataFrame"

# ╔═╡ 104cd307-d8ea-4a37-b896-d2aea3c8dfdc
md"## Functions"

# ╔═╡ e7ee3614-58ec-481e-9baa-cccc4458f6c5
md"### Recursive function to add way data to dataframe"

# ╔═╡ 74152ccd-0bd5-45a1-932b-3d10997fef5b
md"### Turn way in correct direction"

# ╔═╡ 8cc93d3d-3947-4573-910e-0e966c20bacd
function turn_way_in_correct_direction(prev_node_id::Int64, way)
	way_nodes = way.nodes
	way_geometry = way.geometry
	way_tags = Dict()
	reversed = false
	
	if !(prev_node_id in way_nodes)
		way_id = way.id
		throw(ErrorException("$prev_node_id in $way_id not found, cant progress"));
	end
	
	if prev_node_id == last(way_nodes)
		way_nodes = reverse(way_nodes)
		way_geometry = reverse(way_geometry)
		reversed = true
	end

	for (tag_name, value) in way.tags		
		tag_name = string(tag_name)

		if !reversed
			way_tags[tag_name] = value
			continue
		end
		
		if occursin(":forward", tag_name)			
			tag_name = replace(tag_name, ":forward" => ":backward")
		elseif occursin(":backward", tag_name)
			tag_name = replace(tag_name, ":backward" => ":forward")
		end

		way_tags[tag_name] = value
	end
	
	return (
		id = way.id,
		tags = way_tags,
		nodes = way_nodes,
		geometry = way_geometry,
		reversed = reversed,
	)
end;

# ╔═╡ e676ff90-0171-4ae6-b8ad-a257ff404ca0
function next_way(df, ways)
	last_id = last(df).id

	row_has_with_last_id = map(n -> last_id in n.nodes, ways) 
	rows_widh_last_id = ways[row_has_with_last_id, :]
		
	if size(rows_widh_last_id, 1) > 1
		throw(ErrorException("Found way / $last_id multiple times!"));
	elseif size(rows_widh_last_id, 1) == 0
		throw(ErrorException("Found no way / $last_id !"));
	end

	deleteat!(ways, row_has_with_last_id)

	way = turn_way_in_correct_direction(last_id, rows_widh_last_id[1])

	return way
end

# ╔═╡ 52901aad-bab9-4fe9-a0ad-cbc2a4772d04
md"### Calculate distance between two latlon points"

# ╔═╡ 6004e837-ea54-4e57-8263-bbe423dbbea5
function distance_between_geo(start_geo, end_geo)
	start_latlon = LatLon(start_geo.lat, start_geo.lon)
	end_latlon = LatLon(end_geo.lat, end_geo.lon)
	return euclidean_distance(start_latlon, end_latlon)
end;

# ╔═╡ ef4bbfc5-ba6d-465c-b480-50962cd981dc
md"### Extract maxspeed for way"

# ╔═╡ d1d0bf2d-f459-42fd-b583-b00a89db58b2
function way_maxspeed_fw(way)
	if haskey(way.tags, "maxspeed:forward")
		parsedspeed = tryparse(Int64, way.tags["maxspeed:forward"])
		if parsedspeed != nothing
			return parsedspeed
		end
	end

	return missing
end

# ╔═╡ 5e3feb1c-739a-493a-a374-0726d2b9171f
function way_maxspeed(way)
	if haskey(way.tags, "maxspeed")
		parsedspeed = tryparse(Int64, way.tags["maxspeed"])
		if parsedspeed != nothing
			return parsedspeed
		end
	end

	return missing
end

# ╔═╡ 5425698c-5947-4a48-b9c6-43fb0cbcebfd
function way_speed(way)
	if way_maxspeed_fw(way) !== missing
		return way_maxspeed_fw(way)
	elseif way_maxspeed(way) !== missing
		return way_maxspeed(way)
	end

	return missing 
end;

# ╔═╡ 9b73cb72-0d78-11ef-388a-2f21ddfb2e48
function ways2dataframe!(df::DataFrame, ways::Vector{})
	# Stop execution when no ways are left
	if size(ways, 1) == 0
		return df
	end

	# Get next way in correct direction
	way = next_way(df, ways)
	speed = way_speed(way)
	max_speed = way_maxspeed(way)
	max_speed_fw = way_maxspeed_fw(way)

	try
		last(df).max_speed = max_speed
   	catch e
   	end
	try
		last(df).max_speed_fw = max_speed_fw
   	catch e
   	end
	

	last(df).speed = speed
	
	
	
	for (index, id) in enumerate(way.nodes[2:end])
		geo = way.geometry[index + 1]
		geo_prev = way.geometry[index]
		position = last(df).position + distance_between_geo(geo, geo_prev)
		
		push!(df, (
			id = id,
			lat = geo.lat,
			lon = geo.lon,
			position = position,
			speed = speed,
			max_speed=max_speed,
			max_speed_fw=max_speed_fw,
			func = :node,
			reversed = way.reversed,
			),
			promote=true
		)
	end

	return ways2dataframe!(df, ways)
end;

# ╔═╡ 66cca094-d0d5-4eca-9327-005aa83b64b9
md"## Define starting point"

# ╔═╡ 9a1c56c1-a7f7-40aa-a4ae-338fca5800fd
begin
	ways = filter(n -> n.type == "way", overpass_data.elements);
	way = ways[map(n -> starting_point_id in n.nodes, ways) , :][1];
	geometry = first(way.geometry);
end;

# ╔═╡ 36f22465-04d7-4493-b6b6-987f9f22ba95
md"## Create DataFrame"

# ╔═╡ 967aad91-50e4-4fc7-b49f-2972344f737c
begin
	df = DataFrame(
		id=Int[starting_point_id],
		lat=Float64[geometry.lat],
		lon=Float64[geometry.lon],
		position=Float64[0],
		speed=way_speed(way),
		max_speed=way_maxspeed(way),
		max_speed_fw=way_maxspeed_fw(way),
		func = :node,
		reversed=false,
	);
	allowmissing!(df)
	
	ways2dataframe!(df, deepcopy(ways));
end;

# ╔═╡ 3296bc3a-d2d7-4d31-85cb-ac9c69ee8a13
md"# Enrich dataframe with data"

# ╔═╡ 7ab532e3-4466-425e-a237-752ea032162b
md"## Add radius"

# ╔═╡ 5bb58a41-b42e-4ea1-9f28-5f1dd688de06
function addradius!(df::DataFrame)
	node_count = 5
	df[!, :radius] .= fill(NaN, size(df)[1])

	for rows in partition(eachrow(df), node_count, 1)
		geos_for_circle = DataFrame((x = [], y = [], z = [],))
		
		for row in rows
			LatLon = Geodesy.LatLon(row.lat, row.lon)
			ECEF = ECEFfromLLA(wgs84)(LLA(LatLon))
			push!(geos_for_circle, ECEF)
		end

		result = CircleFit.kasa(geos_for_circle.x, geos_for_circle.y)
		
		rows[(node_count - 1) / 2 ].radius = result[3]
	end
end;

# ╔═╡ 1682196c-2cf8-42bd-aaf7-56bf63988397
addradius!(df);

# ╔═╡ 53e4580f-25b1-493f-a233-a3cd84e7fd4a
md"## Add elevation"

# ╔═╡ de789f2b-574b-4af7-90a1-ce3ec8d396bc
function addelevation!(df::DataFrame)
	opentopodata_endpoint = "https://api.opentopodata.org/v1/eudem25m?locations="

	topos = Float64[]
	
	for rows in Iterators.partition(eachrow(df), 100)
		str = ""
		for row in rows
			str = string(str, row.lat, ",", row.lon, "|")
		end
		
		topodata = String(HTTP.get(string(opentopodata_endpoint, str)).body)
		for topodate in JSON3.read(topodata).results
			push!(topos, topodate.elevation)
		end
	end

	df[!, :elevation] = topos
end;

# ╔═╡ f094cef9-ce2c-4403-992b-37eae599f6d9
addelevation!(df);

# ╔═╡ 639b6f1e-3553-4c0e-93df-210cec136c19
md"## Add signals"

# ╔═╡ 5b6eaf52-3e83-4a9f-a716-ca49a694ed09
md"### Extract maxspeed for speed signal"

# ╔═╡ 78779d23-9826-4353-a832-373a51ecad78
function signal_maxspeed(signal)
	speed = get(signal.tags, "railway:signal:speed_limit:speed", nothing)

	if tryparse(Int64, speed) !== nothing
		return parse(Int64, speed)
	end
	
	return missing
end;

# ╔═╡ ff552313-b6e9-4882-a4e9-1ba3bb535925
md"### Add signals"

# ╔═╡ ad93d842-106c-416f-b169-db6f0ecf3fe1
function nodes2dataframe!(df::DataFrame)
	for (index, row) in enumerate(reverse(eachrow(df)))
		if row.func != :node
			continue
		end
		
		for node in filter(n -> n.type == "node", overpass_data.elements)
			if node.id == row.id
				if row.reversed
					direction = "backward"
				else
					direction = "forward"
				end

				if get(node.tags, "railway", "") == "vacancy_detection"
					insert!(df, 1, (
						id=node.id,
						lat=node.lat,
						lon=node.lon,
						func=:vacancy_detection,
						position=row.position,
					), cols=:union)
				end
				
				if get(node.tags, "railway:signal:direction", "") != direction
					continue
				end
				
				if get(node.tags, "railway:signal:speed_limit", "") == "DE-ESO:zs3"
					insert!(df, 1, (
						id=node.id,
						lat=node.lat,
						lon=node.lon,
						func=:speed_limit_diverging,
						position=row.position,
						speed=signal_maxspeed(node),
					), cols=:union)
				end

				if haskey(node.tags, "railway:signal:speed_limit")
					insert!(df, 1, (
						id=node.id,
						lat=node.lat,
						lon=node.lon,
						func=:speed_limit,
						position=row.position,
						speed=signal_maxspeed(node),
					), cols=:union)
				end

				if haskey(node.tags, "railway:signal:main")
					insert!(df, 1, (
						id=node.id,
						lat=node.lat,
						lon=node.lon,
						func=:main_signal,
						position=row.position,
					), cols=:union)
				end

				if haskey(node.tags, "railway:signal:distant")
					if get(node.tags, "railway:signal:distant:repeated", "") != "yes"
						insert!(df, 1, (
							id=node.id,
							lat=node.lat,
							lon=node.lon,
							func=:distant_signal,
							position=row.position,
						), cols=:union)
					end
				end

				if haskey(node.tags, "railway:signal:combined")
					insert!(df, 1, (
						id=node.id,
						lat=node.lat,
						lon=node.lon,
						func=:main_signal,
						position=row.position,
					), cols=:union)

					insert!(df, 1, (
						id=node.id,
						lat=node.lat,
						lon=node.lon,
						func=:distant_signal,
						position=row.position,
					), cols=:union)
				end
			end
		end
	end
end;

# ╔═╡ 55d940eb-2886-43bf-810b-a438da943191
nodes2dataframe!(df);

# ╔═╡ d6553a8a-180a-4936-bcc5-3a39546c240b
df

# ╔═╡ d9f047a6-94d8-4e50-8b03-6cb66e558924
md"# Graphs"

# ╔═╡ 7533e7d7-3092-4b86-9efa-63f731563a94
md"## Prepare data"

# ╔═╡ c3db7c4d-1cd6-4e8e-a7bb-dba5c9406ecc
geopoints = df[(df.func .== :node), :];

# ╔═╡ 7db7f763-fe37-44a5-865c-7c1e757d63cd
speed_signals_diverging = df[(df.func .== :speed_limit_diverging), :];

# ╔═╡ 40364f69-3460-463b-a729-272decd2f6c1
speed_signals = df[(df.func .== :speed_limit), :];

# ╔═╡ da00b539-340f-4349-9d33-bf1857d2f855
main_signals = df[(df.func .== :main_signal), :];

# ╔═╡ fd518881-bfbc-445d-977a-e0bc30579541
distant_signals = df[(df.func .== :distant_signal), :];

# ╔═╡ d92d76ba-e9c8-4836-bf37-65f0b739bb82
vacancy_detection = df[(df.func .== :vacancy_detection), :];

# ╔═╡ 1e39a139-0e75-4af9-8d5b-0c2257b407bd
md"## Radius"

# ╔═╡ 97a7ce5c-1a9c-423a-b9a9-ca02b060bd44
begin
	raius_figure = Figure(size = (1000, 800))
	GeoAxis(raius_figure[1, 1]; dest = "+proj=merc")

	color = Vector{Float64}(geopoints.radius)
	# Draw edges
	scatterlines!(geopoints.lon, geopoints.lat, color=color, nan_color=:gray, linewidth=5, markersize=10)

	lines!(geopoints.lon .+ 0.005, geopoints.lat, color=color, nan_color=:gray, linewidth=5, colorrange=(0, 700), highclip=:gray)
	scatter!(geopoints.lon .+ 0.005, geopoints.lat, color=color, nan_color=:gray, markersize=10, colorrange=(0, 700), highclip=:gray)

	raius_figure
end

# ╔═╡ 2789e554-5410-4d67-9f5a-88beaafe56d0
md"## Signals"

# ╔═╡ f3fe3b21-100e-4227-a375-b3f18766aa38
begin
	# Define graph
	signal_figure = Figure(size = (800, 800))
	GeoAxis(signal_figure[1, 1]; dest = "+proj=merc")
	
	# Draw edges
	lines!(geopoints.lon, geopoints.lat, color=:gray, label="")

	# Draw signals	
	main = scatter!(main_signals.lon, main_signals.lat, markersize=20)
	distant = scatter!(distant_signals.lon, distant_signals.lat, markersize=10)

	# div_speed = scatter!(speed_signals_diverging.lon, speed_signals_diverging.lat, markersize=15)

	vac = scatter!(vacancy_detection.lon, vacancy_detection.lat, markersize=15)


	Legend(signal_figure[1, 2],
	    [main, distant, vac],
	    ["Hauptsignal", "Vorsignal", "Gleisfreimeldeanlage"])
	
	# Legend(signal_figure[1, 2], "Quellen")

	# Write graph
	signal_figure
end

# ╔═╡ 0b3f7822-b151-4e28-a67d-e20436d24f3e
md"## Streckenband"

# ╔═╡ dbb1bfa9-d3fd-4ed9-9b6b-ff0908845d3f
begin
	streckenband = Figure(size = (900, 400))
	
	ax_speed = Axis(streckenband[1, 1], xlabel = "km", ylabel = "v_max [km/h]")
	# ylims!(low=0)

	stairs!(geopoints.position ./ 1000, geopoints.speed, step=:post, label = "Analysierte Maximalgeschwindigkeit", nan_color=:red)

	
	# if size(speed_signals_diverging, 1) > 0
	# 	stairs!(speed_signals_diverging.position ./ 1000, speed_signals_diverging.speed, step=:post, label = "diverging speed of ways")
	# 	scatter!(speed_signals_diverging.position ./ 1000, speed_signals_diverging.speed)
	# end


	if size(speed_signals, 1) > 0
		vlines!(speed_signals.position ./ 1000, step=:post, label = "Position der Geschwindigkeitsanzeiger", color=:gray, linestyle=:dot)
	end

	
	scatter!(geopoints.position ./ 1000, geopoints.max_speed, label = "Geschwindigkeit aus maxspeed")
	# scatter!(geopoints.position ./ 1000, geopoints.max_speed_fw, label = "Geschwindigkeit aus maxspeed:forward")


	Legend(streckenband[1, 2], ax_speed)

	########

	ax_signals = Axis(streckenband[2, 1], height=40)
	hideydecorations!(ax_signals)
	hidexdecorations!(ax_signals, ticks=false, ticklabels=false)
	hidespines!(ax_signals, :l, :t, :r)

	scatter!(main_signals.position ./ 1000, [3], markersize=14, label="Hauptsignal")
	scatter!(distant_signals.position ./ 1000, [2], markersize=14, label="Vorsignal")
	scatter!(vacancy_detection.position ./ 1000, [1], markersize=14, label="Gleisfreimeldeanlage")
	scatter!(speed_signals_diverging.position ./ 1000, [0], markersize=14, label = "Zs3 Geschwindigkeitssignal")




	Legend(streckenband[2, 2], ax_signals)
	linkxaxes!(ax_speed, ax_signals)


	streckenband
end

# ╔═╡ 8df2b4ca-3dfe-4c39-b4fe-17b1bcc2acab
md"## Elevation"

# ╔═╡ 97198bbc-4b12-481e-8d0c-239c0505c0ba
begin

	elevation_fig = Figure(size = (2000, 1000))

	ax_elevation = Axis(elevation_fig[1, 1])

	# TODO average ignores position
	elevation = Vector{Float64}(geopoints.elevation)
	elevation_averge = EasyFit.fitspline(geopoints.position ./ 1000, elevation)
	elevation_averge2 = EasyFit.fitspline(elevation_averge.x, elevation_averge.y)
	scatterlines!(geopoints.position ./ 1000, elevation, label="Elevation")
	scatterlines!(elevation_averge.x, elevation_averge.y, label="Spline")
	scatterlines!(elevation_averge2.x, elevation_averge2.y, label="Spline")


	Legend(elevation_fig[1, 2], ax_elevation)
	
	elevation_fig
end

# ╔═╡ a997e169-c9e2-41fb-b8fc-c83f2c074c89
md"## Radius linear"

# ╔═╡ f70b3b7b-3000-4d23-8900-9a6286d685fc
begin
	radius = Figure(size = (2000, 500))
	ay_radius = Axis(radius[1, 1])

	hlines!(1 / 700)
	hlines!(1 / 2500)
	scatterlines!(geopoints.position ./ 1000, 1 ./ geopoints.radius)
	
	linkxaxes!(ax_speed, ay_radius)
	radius
end

# ╔═╡ c3a43f5a-dacc-42b8-b4b9-5f5158e5333d
md"# Export as YAML"

# ╔═╡ 0d474531-90c6-4070-b6da-2ae6206f6931
function is_speed_change(funcs, speeds)
	curr_speed = speeds[1]
	keep::Vector{Bool} = [true]
	
	for (index, speed) in enumerate(speeds[2:end-1])

		if !(funcs[index + 1] in [:speed_signal_diverging, :node])
			push!(keep, false)
			continue
		end
		
		if curr_speed !== speed
			curr_speed = speed
			push!(keep, true)
			continue
		end

		push!(keep, false)
	end

	push!(keep, true)
	
	return keep
end

# ╔═╡ c5cfd803-90ff-46ab-9ea5-9e6d370a8098
points_of_interest = df[df.func .== :main_signal .|| df.func .== :distant_signal .|| df.func .== :vacancy_detection, [:id, :position, :func]]

# ╔═╡ 3a2d7f85-b85e-4c59-a36a-34ee339a324f
points_of_interest.direction = [row.func == :vacancy_detection ? :back : :front for row in eachrow(points_of_interest)]

# ╔═╡ b5a4c5c5-2928-4308-a79d-c8751098305b
p_o_i = points_of_interest[:, [:position, :func, :direction]]

# ╔═╡ c5cb9e8c-9012-4584-9871-662ce6a1012b
poi = [Vector(row) for row in eachrow(p_o_i)]

# ╔═╡ 8cfe1eaf-bdbe-4c98-b751-101ed0f9a62e
characteristic_sections = subset(sort!(df, [:position]), [:func, :speed] => is_speed_change)[:, [:position, :speed]]

# ╔═╡ 57177943-a58b-424e-b06f-77b83eeb2e2d
characteristic_sections.resistance = [0.0 for row in eachrow(characteristic_sections)]

# ╔═╡ 20f58199-df8e-4f09-ab95-3cd2688112e7
char_sec = [Vector(row) for row in eachrow(characteristic_sections)]

# ╔═╡ 9fdc2a22-0cca-4bd5-8c7c-f7b2743f616d
yaml_content = Dict(
	:schema => "https://railtoolkit.org/schema/running-path.json",
	:schema_version => "2022.05",
	:paths => [
		Dict(
			:name => "Blocks",
			:id => :block_sections,
			:characteristic_sections => char_sec,
			:points_of_interest => poi,
		),
	]
)

# ╔═╡ ab62305a-b331-4311-9825-016be6dc095e
YAML.write_file("$filename.yaml", yaml_content)

# ╔═╡ c7e49aee-aa42-43cd-a4c4-d6b70e2158fb
TableOfContents(title="📚 Table of Contents")

# ╔═╡ Cell order:
# ╟─e0cde4b0-cb81-4c62-a163-ab7311b7e6c9
# ╠═d0095fd5-120d-4567-a9c1-89ac4fe95546
# ╟─b7e7ecb6-03f2-4844-949b-51cce11266ce
# ╠═c91e3dc9-1f3c-4a36-be05-342390a02e1e
# ╠═12659906-a692-402f-bfb5-6cebc1529e9c
# ╠═45966a87-5baa-4c53-9afb-b52ccefb7932
# ╠═70c06ad5-f87b-4c2c-90a1-749ca37677db
# ╠═4b66e66c-afee-40d6-8d3a-48185ca762ee
# ╠═de1771ff-5266-4057-882d-0c08453684ae
# ╟─af481143-32e2-4626-b35c-2052157e0865
# ╠═a127931d-c0fa-4302-8c47-c7d89ded7987
# ╠═901724b5-9888-43e8-8cb5-fe7f635114c8
# ╟─4899b953-ef2e-417a-b746-9a79ad9a7cc7
# ╠═c44c30bf-1720-49c4-927e-e1fcbf9db687
# ╟─104cd307-d8ea-4a37-b896-d2aea3c8dfdc
# ╠═e676ff90-0171-4ae6-b8ad-a257ff404ca0
# ╟─e7ee3614-58ec-481e-9baa-cccc4458f6c5
# ╠═9b73cb72-0d78-11ef-388a-2f21ddfb2e48
# ╟─74152ccd-0bd5-45a1-932b-3d10997fef5b
# ╠═8cc93d3d-3947-4573-910e-0e966c20bacd
# ╟─52901aad-bab9-4fe9-a0ad-cbc2a4772d04
# ╠═2fad0fb7-fdcd-4b43-a16a-4f5a64e672d9
# ╠═6004e837-ea54-4e57-8263-bbe423dbbea5
# ╟─ef4bbfc5-ba6d-465c-b480-50962cd981dc
# ╠═5425698c-5947-4a48-b9c6-43fb0cbcebfd
# ╠═d1d0bf2d-f459-42fd-b583-b00a89db58b2
# ╠═5e3feb1c-739a-493a-a374-0726d2b9171f
# ╟─66cca094-d0d5-4eca-9327-005aa83b64b9
# ╠═9a1c56c1-a7f7-40aa-a4ae-338fca5800fd
# ╠═36f22465-04d7-4493-b6b6-987f9f22ba95
# ╠═967aad91-50e4-4fc7-b49f-2972344f737c
# ╟─3296bc3a-d2d7-4d31-85cb-ac9c69ee8a13
# ╟─7ab532e3-4466-425e-a237-752ea032162b
# ╠═ce18fb48-ff76-4da1-b070-acd06dc7cdb4
# ╠═5bb58a41-b42e-4ea1-9f28-5f1dd688de06
# ╠═1682196c-2cf8-42bd-aaf7-56bf63988397
# ╟─53e4580f-25b1-493f-a233-a3cd84e7fd4a
# ╠═de789f2b-574b-4af7-90a1-ce3ec8d396bc
# ╠═f094cef9-ce2c-4403-992b-37eae599f6d9
# ╟─639b6f1e-3553-4c0e-93df-210cec136c19
# ╟─5b6eaf52-3e83-4a9f-a716-ca49a694ed09
# ╠═78779d23-9826-4353-a832-373a51ecad78
# ╟─ff552313-b6e9-4882-a4e9-1ba3bb535925
# ╠═ad93d842-106c-416f-b169-db6f0ecf3fe1
# ╠═55d940eb-2886-43bf-810b-a438da943191
# ╠═d6553a8a-180a-4936-bcc5-3a39546c240b
# ╟─d9f047a6-94d8-4e50-8b03-6cb66e558924
# ╟─7533e7d7-3092-4b86-9efa-63f731563a94
# ╠═c3db7c4d-1cd6-4e8e-a7bb-dba5c9406ecc
# ╠═7db7f763-fe37-44a5-865c-7c1e757d63cd
# ╠═40364f69-3460-463b-a729-272decd2f6c1
# ╠═da00b539-340f-4349-9d33-bf1857d2f855
# ╠═fd518881-bfbc-445d-977a-e0bc30579541
# ╠═d92d76ba-e9c8-4836-bf37-65f0b739bb82
# ╠═f89da717-e534-4774-b5ee-e70cc265c3c1
# ╟─1e39a139-0e75-4af9-8d5b-0c2257b407bd
# ╠═97a7ce5c-1a9c-423a-b9a9-ca02b060bd44
# ╟─2789e554-5410-4d67-9f5a-88beaafe56d0
# ╠═f3fe3b21-100e-4227-a375-b3f18766aa38
# ╟─0b3f7822-b151-4e28-a67d-e20436d24f3e
# ╠═28c53785-3834-4e60-bf70-5ab9834890e5
# ╠═dbb1bfa9-d3fd-4ed9-9b6b-ff0908845d3f
# ╠═8df2b4ca-3dfe-4c39-b4fe-17b1bcc2acab
# ╠═97198bbc-4b12-481e-8d0c-239c0505c0ba
# ╟─a997e169-c9e2-41fb-b8fc-c83f2c074c89
# ╠═f70b3b7b-3000-4d23-8900-9a6286d685fc
# ╟─c3a43f5a-dacc-42b8-b4b9-5f5158e5333d
# ╠═0d474531-90c6-4070-b6da-2ae6206f6931
# ╠═c5cfd803-90ff-46ab-9ea5-9e6d370a8098
# ╠═3a2d7f85-b85e-4c59-a36a-34ee339a324f
# ╠═b5a4c5c5-2928-4308-a79d-c8751098305b
# ╠═c5cb9e8c-9012-4584-9871-662ce6a1012b
# ╠═8cfe1eaf-bdbe-4c98-b751-101ed0f9a62e
# ╠═57177943-a58b-424e-b06f-77b83eeb2e2d
# ╠═20f58199-df8e-4f09-ab95-3cd2688112e7
# ╠═4e3543e3-1d7c-483a-8670-2c39fd198bbb
# ╠═9fdc2a22-0cca-4bd5-8c7c-f7b2743f616d
# ╠═ab62305a-b331-4311-9825-016be6dc095e
# ╠═158b97dd-d7b9-4818-b470-93447e984556
# ╠═c7e49aee-aa42-43cd-a4c4-d6b70e2158fb
