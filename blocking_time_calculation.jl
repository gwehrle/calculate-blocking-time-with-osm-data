### A Pluto.jl notebook ###
# v0.19.42

using Markdown
using InteractiveUtils

# ╔═╡ c30adb34-dfd3-4d8a-85cd-6bf1b8fa26f4
begin
	import Pkg;
	Pkg.add("TrainRuns");
	Pkg.add("DataFrames");
	Pkg.add("Makie");
end

# ╔═╡ 58375575-e87a-4f26-80b0-55fabdd7e218
begin
	using TrainRuns;
	using DataFrames;
end

# ╔═╡ 53601e79-c4a5-4453-8d26-1def17fc69c1
using CairoMakie

# ╔═╡ 972b32ee-dc4c-4c9c-a2db-24d968804d67
filename = "roetgesbuettel_gifhorn_2"

# ╔═╡ db4ccd0a-ef9f-4050-becd-25e6e2a4e7c9
blck_sct = Path("$filename.yaml");

# ╔═╡ 1f8f1056-5a6d-4613-b04b-9188ac26f026
passenger_train = Train("siemens_desiro_classic.yaml");

# ╔═╡ 7087926f-5380-49ec-8aee-f3566d396c33
function add_padding!(path, padding)
	prepend_block = deepcopy(first(path.sections))
	prepend_block[:s_end] = prepend_block[:s_start]
	prepend_block[:s_start] = prepend_block[:s_start] - padding

	append_block = deepcopy(last(path.sections))
	append_block[:s_start] = append_block[:s_end]
	append_block[:s_end] = append_block[:s_end] + padding

	pushfirst!(path.sections, prepend_block)
	push!(path.sections, append_block)
end

# ╔═╡ 355e05cf-05ad-4596-9ac6-52157a2239be
function remove_padding!(df, path)
	first_section = first(path.sections)
	df = filter(row -> !(row.s < first_section[:s_end]), df)

	last_section = last(path.sections)
	df = filter(row -> !(row.s > last_section[:s_start]), df)
	
	df
end

# ╔═╡ 30cc7569-9098-4a01-9b05-8c9d37fb0d42
function trainrun_with_padding(train, path, settings, padding = 0)
	path = deepcopy(path)
	settings = deepcopy(settings)

	add_padding!(path, padding)

	pushfirst!(path.poi, Dict(
		:station => first(path.sections)[:s_end],
		:label => "remove_time",
		:measure => "front"
	))

	# funktioniert irgendwie nicht wegen step variable?
	push!(path.poi, Dict(
		:station => last(path.sections)[:s_start],
		:label => "padding_last",
		:measure => "front"
	))

	df = trainrun(train, path, settings)
	
	df = remove_padding!(df, path)
	
	settings2 = Settings(
		massModel = settings.massModel,
		stepVariable = settings.stepVariable,
		stepSize = settings.stepSize,
		approxLevel = settings.approxLevel,
		outputDetail = :points_of_interest,
		outputFormat = :dataframe,
	)
	
	remove_time = trainrun(train, path, settings2)[1,:t]
	df.t = df.t .- remove_time
	
	return df
end;

# ╔═╡ 8f3a2c03-35d6-4a32-b28a-8971555f9651
df2 = trainrun_with_padding(passenger_train, blck_sct, Settings(outputDetail=:points_of_interest,), 3000)

# ╔═╡ 4e203c25-dffd-4850-822c-11702539e4a2
df3 = trainrun_with_padding(passenger_train, blck_sct, Settings(outputDetail=:data_points,), 3000)


# ╔═╡ d0201c8e-aff3-4b03-8c10-601637bb8d10
df4 = trainrun_with_padding(passenger_train, blck_sct, Settings(outputDetail=:driving_course,), 3000)

# ╔═╡ 264a1ef7-3437-45f2-8ffc-b9fdedb8c4bd
begin
	s_v_t_fig = Figure()
	
	Axis(s_v_t_fig[1, 1],
		xaxisposition =  :top,
		xlabel = "distance in km",
		ylabel = "speed in km/h",
	)
	lines!(df4.s / 1000, df4.v * 3.6)

	Axis(s_v_t_fig[2:3, 1], 
		yreversed = true,
		xlabel = "distance in km",
		ylabel = "time in min",
	)
	lines!(df4.s / 1000, df4.t / 60)
	
	s_v_t_fig
end

# ╔═╡ Cell order:
# ╠═c30adb34-dfd3-4d8a-85cd-6bf1b8fa26f4
# ╠═972b32ee-dc4c-4c9c-a2db-24d968804d67
# ╠═58375575-e87a-4f26-80b0-55fabdd7e218
# ╠═db4ccd0a-ef9f-4050-becd-25e6e2a4e7c9
# ╠═1f8f1056-5a6d-4613-b04b-9188ac26f026
# ╠═7087926f-5380-49ec-8aee-f3566d396c33
# ╠═355e05cf-05ad-4596-9ac6-52157a2239be
# ╠═30cc7569-9098-4a01-9b05-8c9d37fb0d42
# ╠═8f3a2c03-35d6-4a32-b28a-8971555f9651
# ╠═4e203c25-dffd-4850-822c-11702539e4a2
# ╠═d0201c8e-aff3-4b03-8c10-601637bb8d10
# ╠═53601e79-c4a5-4453-8d26-1def17fc69c1
# ╠═264a1ef7-3437-45f2-8ffc-b9fdedb8c4bd
