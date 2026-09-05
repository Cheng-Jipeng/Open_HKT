#!/usr/bin/env julia

using Dates
using Plots
using Plots.PlotMeasures

const ROOT = @__DIR__
const FIGDIR = joinpath(ROOT, "figures")
mkpath(FIGDIR)

gr()
default(
    fontfamily="Helvetica",
    foreground_color_axis="#475467",
    foreground_color_text="#344054",
    gridalpha=0.28,
    gridcolor="#98A2B3",
    framestyle=:axes,
    linewidth=1.8,
    size=(1050, 650),
    dpi=220,
)

function read_tsv(path)
    lines = readlines(path)
    header = split(lines[1], '\t'; keepempty=true)
    rows = Vector{Dict{String,String}}()
    for line in lines[2:end]
        fields = split(line, '\t'; keepempty=true)
        length(fields) < length(header) && append!(fields, fill("", length(header) - length(fields)))
        push!(rows, Dict(header[i] => fields[i] for i in eachindex(header)))
    end
    rows
end

parsefloat(s) = isempty(strip(s)) ? NaN : tryparse(Float64, s) === nothing ? NaN : parse(Float64, s)
parsedate(s) = Date(first(split(s, 'T')))

function saveboth(p, stem)
    savefig(p, joinpath(FIGDIR, stem * ".png"))
    savefig(p, joinpath(FIGDIR, stem * ".pdf"))
end

sector_rank = read_tsv(joinpath(ROOT, "plot_data", "sector_ranking.tsv"))
sector_hist = read_tsv(joinpath(ROOT, "plot_data", "sector_history.tsv"))
country_rank = read_tsv(joinpath(ROOT, "plot_data", "country_ranking.tsv"))
country_hist = read_tsv(joinpath(ROOT, "plot_data", "country_history.tsv"))

# 1. Latest sector ranking.
top_sector = sector_rank[1:min(12, length(sector_rank))]
top_sector = reverse(top_sector)
sector_values = [parsefloat(r["value_usd_billions"]) / 1000 for r in top_sector]
sector_labels = [r["holder"] for r in top_sector]
sector_colors = [r["holder"] == "Rest of world" ? "#B42318" : "#175CD3" for r in top_sector]
sector_date = parsedate(sector_rank[1]["date"])
p1 = plot(
    yticks=(collect(1:length(sector_labels)), sector_labels),
    ylims=(0.4, length(sector_values) + 0.6),
    xlims=(0, maximum(sector_values) * 1.27),
    legend=false,
    xlabel="Trillions of U.S. dollars",
    title="Largest holders of marketable U.S. Treasury securities, $(year(sector_date))Q$(quarterofyear(sector_date))",
    left_margin=18mm,
    right_margin=10mm,
    bottom_margin=8mm,
    xgrid=true,
    ygrid=false,
)
for (i, row) in enumerate(top_sector)
    value = parsefloat(row["value_usd_billions"]) / 1000
    share = 100 * parsefloat(row["share_of_total_assets"])
    barshape = Shape([0, value, value, 0], [i - 0.38, i - 0.38, i + 0.38, i + 0.38])
    plot!(p1, barshape; color=sector_colors[i], linecolor="#101828", linewidth=1, label=false)
    annotate!(p1, value + 0.09, i, text("\$$(round(value; digits=2))T  ($(round(share; digits=1))%)", 8, :left, "#344054"))
end
saveboth(p1, "01_latest_sector_holders")

# 2. Major-sector history.
selected_sector = [
    "Rest of world",
    "Federal Reserve",
    "Money market funds",
    "Households and nonprofits",
    "U.S.-chartered banks",
    "Mutual funds",
    "State and local governments",
]
sector_palette = ["#B42318", "#175CD3", "#F79009", "#039855", "#7F56D9", "#06AED4", "#667085"]
p2 = plot(
    xlabel="",
    ylabel="Trillions of U.S. dollars",
    title="U.S. Treasury holdings by major sector",
    legend=:topleft,
    legend_columns=2,
    left_margin=8mm,
    bottom_margin=7mm,
    ygrid=true,
    xgrid=false,
)
for (name, color) in zip(selected_sector, sector_palette)
    rows = filter(r -> r["holder"] == name && !isnan(parsefloat(r["value_usd_billions"])), sector_hist)
    sort!(rows; by=r -> parsedate(r["date"]))
    plot!(
        p2,
        [parsedate(r["date"]) for r in rows],
        [parsefloat(r["value_usd_billions"]) / 1000 for r in rows];
        label=name,
        color=color,
        linewidth=name == "Rest of world" ? 2.5 : 1.8,
    )
end
saveboth(p2, "02_sector_holdings_history")

# 3. Domestic versus foreign shares.
totals = Dict(parsedate(r["date"]) => parsefloat(r["value_usd_billions"]) for r in sector_hist if r["holder"] == "Total assets" && !isnan(parsefloat(r["value_usd_billions"])))
foreign = Dict(parsedate(r["date"]) => parsefloat(r["value_usd_billions"]) for r in sector_hist if r["holder"] == "Rest of world" && !isnan(parsefloat(r["value_usd_billions"])))
share_dates = sort(collect(intersect(keys(totals), keys(foreign))))
foreign_share = [foreign[d] / totals[d] for d in share_dates]
p3 = plot(
    share_dates,
    foreign_share;
    label="Rest of world",
    color="#B42318",
    linewidth=2.4,
    xlabel="",
    ylabel="Share of reported sector assets",
    yformatter=y -> "$(round(Int, 100y))%",
    ylims=(0, 1),
    title="Domestic and foreign shares of reported Treasury holdings",
    legend=:right,
    left_margin=9mm,
    ygrid=true,
    xgrid=false,
)
plot!(p3, share_dates, 1 .- foreign_share; label="All domestic sectors", color="#175CD3", linewidth=2.2)
saveboth(p3, "03_domestic_foreign_shares")

# 4. Latest foreign-country ranking.
top_country = reverse(country_rank[1:min(15, length(country_rank))])
country_values = [parsefloat(r["value_usd_billions"]) for r in top_country]
country_labels = [r["country_or_group"] for r in top_country]
country_date = parsedate(country_rank[1]["date"])
p4 = plot(
    yticks=(collect(1:length(country_labels)), country_labels),
    ylims=(0.4, length(country_values) + 0.6),
    xlims=(0, maximum(country_values) * 1.31),
    legend=false,
    xlabel="Billions of U.S. dollars",
    title="Largest foreign holders of U.S. Treasury securities, $(monthname(country_date)) $(year(country_date))",
    left_margin=17mm,
    right_margin=11mm,
    bottom_margin=8mm,
    xgrid=true,
    ygrid=false,
)
for (i, row) in enumerate(top_country)
    value = parsefloat(row["value_usd_billions"])
    share = 100 * parsefloat(row["share_of_foreign_total"])
    barshape = Shape([0, value, value, 0], [i - 0.38, i - 0.38, i + 0.38, i + 0.38])
    plot!(p4, barshape; color="#175CD3", linecolor="#101828", linewidth=1, label=false)
    annotate!(p4, value + 15, i, text("\$$(round(value; digits=1))B  ($(round(share; digits=1))%)", 8, :left, "#344054"))
end
saveboth(p4, "04_latest_foreign_country_holders")

# 5. History of the six largest current country holders.
top_names = [r["country_or_group"] for r in country_rank[1:min(6, length(country_rank))]]
country_palette = ["#175CD3", "#B42318", "#039855", "#F79009", "#7F56D9", "#06AED4"]
p5 = plot(
    xlabel="",
    ylabel="Billions of U.S. dollars",
    title="Treasury holdings of the largest foreign economies",
    legend=:topleft,
    legend_columns=2,
    left_margin=8mm,
    bottom_margin=7mm,
    ygrid=true,
    xgrid=false,
)
for (name, color) in zip(top_names, country_palette)
    rows = filter(r -> r["country_or_group"] == name && parsedate(r["date"]) >= Date(2012, 1, 1) && !isnan(parsefloat(r["value_usd_billions"])), country_hist)
    sort!(rows; by=r -> parsedate(r["date"]))
    plot!(p5, [parsedate(r["date"]) for r in rows], [parsefloat(r["value_usd_billions"]) for r in rows]; label=name, color=color, linewidth=1.9)
end
saveboth(p5, "05_foreign_country_history")

# 6. Foreign official versus other foreign holders.
grand_total = Dict(parsedate(r["date"]) => parsefloat(r["value_usd_billions"]) for r in country_hist if r["country_or_group"] == "Grand Total" && !isnan(parsefloat(r["value_usd_billions"])))
official = Dict(parsedate(r["date"]) => parsefloat(r["value_usd_billions"]) for r in country_hist if r["country_or_group"] == "Foreign official" && !isnan(parsefloat(r["value_usd_billions"])))
official_dates = sort(collect(intersect(keys(grand_total), keys(official))))
p6 = plot(
    official_dates,
    [official[d] / 1000 for d in official_dates];
    label="Foreign official",
    color="#175CD3",
    linewidth=2.2,
    xlabel="",
    ylabel="Trillions of U.S. dollars",
    title="Foreign official and other foreign Treasury holdings",
    legend=:topleft,
    left_margin=8mm,
    ygrid=true,
    xgrid=false,
)
plot!(p6, official_dates, [(grand_total[d] - official[d]) / 1000 for d in official_dates]; label="Private and other foreign", color="#B54708", linewidth=2.2)
saveboth(p6, "06_foreign_official_private_history")

println("Saved six PNG and six PDF figures to $(FIGDIR)")
