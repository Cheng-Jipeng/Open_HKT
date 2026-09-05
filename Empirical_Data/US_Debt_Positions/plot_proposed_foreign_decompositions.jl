#!/usr/bin/env julia

module ProposedForeignDecompositions

using Dates
using Plots
using Plots.PlotMeasures
using Printf

const ROOT = @__DIR__
const INPUT = joinpath(ROOT, "plot_data", "country_history.tsv")
const FIGDIR = joinpath(ROOT, "figures")

const FUNCTIONAL_OUTPUT = joinpath(ROOT, "long_run_foreign_decomposition_functional_monthly.csv")
const FUNCTIONAL_CROSSWALK = joinpath(ROOT, "long_run_foreign_functional_crosswalk.csv")
const STABLE_OUTPUT = joinpath(ROOT, "long_run_foreign_decomposition_stable_panel_monthly.csv")
const STABLE_CROSSWALK = joinpath(ROOT, "long_run_foreign_stable_panel_crosswalk.csv")

const PERIOD_2_START = Date(2002, 1, 1)
const PERIOD_3_START = Date(2008, 1, 1)
const POST_AHP_START = Date(2023, 10, 1)
const TIC_REPORTING_BREAK = Date(2012, 1, 1)

const EU27_2026 = [
    "Austria", "Belgium", "Bulgaria", "Croatia", "Cyprus", "Czechia",
    "Denmark", "Estonia", "Finland", "France", "Germany", "Greece",
    "Hungary", "Ireland", "Italy", "Latvia", "Lithuania", "Luxembourg",
    "Malta", "Netherlands", "Poland", "Portugal", "Romania", "Slovakia",
    "Slovenia", "Spain", "Sweden",
]

const FUNCTIONAL_GROUPS = [
    "All other foreign",
    "Canada & other advanced",
    "Commodity exporters",
    "Core EU-27 (identifiable)",
    "Financial/offshore centres",
    "Other East Asian exporters",
    "United Kingdom",
    "Mainland China",
    "Japan",
]
const FUNCTIONAL_COLORS = Dict(
    "All other foreign" => "#98A2B3",
    "Canada & other advanced" => "#06AED4",
    "Commodity exporters" => "#F79009",
    "Core EU-27 (identifiable)" => "#039855",
    "Financial/offshore centres" => "#C11574",
    "Other East Asian exporters" => "#0E9384",
    "United Kingdom" => "#7F56D9",
    "Mainland China" => "#B42318",
    "Japan" => "#175CD3",
)

const STABLE_GROUPS = [
    "All other foreign",
    "South Korea",
    "Singapore",
    "Taiwan",
    "Hong Kong",
    "United Kingdom",
    "Mainland China",
    "Japan",
]
const STABLE_COLORS = Dict(
    "All other foreign" => "#98A2B3",
    "South Korea" => "#0E9384",
    "Singapore" => "#06AED4",
    "Taiwan" => "#C11574",
    "Hong Kong" => "#F79009",
    "United Kingdom" => "#7F56D9",
    "Mainland China" => "#B42318",
    "Japan" => "#175CD3",
)

mkpath(FIGDIR)
gr()
default(
    fontfamily="Helvetica",
    foreground_color_axis="#475467",
    foreground_color_text="#344054",
    gridalpha=0.30,
    gridcolor="#98A2B3",
    framestyle=:axes,
    linewidth=2.0,
    dpi=220,
)

function read_tsv(path::String)
    lines = readlines(path)
    isempty(lines) && error("Empty input: $path")
    header = split(lines[1], '\t'; keepempty=true)
    rows = Vector{Dict{String,String}}()
    for line in lines[2:end]
        isempty(strip(line)) && continue
        fields = split(line, '\t'; keepempty=true)
        length(fields) < length(header) && append!(fields, fill("", length(header) - length(fields)))
        push!(rows, Dict(header[i] => fields[i] for i in eachindex(header)))
    end
    rows
end

function parse_number(value::AbstractString)
    text = strip(value)
    isempty(text) && return NaN
    parsed = tryparse(Float64, text)
    parsed === nothing ? NaN : parsed
end

parse_date(value::AbstractString) = Date(first(split(value, 'T')))

function csv_escape(value)
    text = string(value)
    if occursin(',', text) || occursin('"', text) || occursin('\n', text)
        return "\"" * replace(text, "\"" => "\"\"") * "\""
    end
    text
end

function write_csv(path::String, header::Vector{String}, rows::Vector{Vector{Any}})
    open(path, "w") do io
        println(io, join(csv_escape.(header), ','))
        for row in rows
            println(io, join(csv_escape.(row), ','))
        end
    end
end

function ahp_period(date::Date)
    date < PERIOD_2_START && return "2000M03-2001M12"
    date < PERIOD_3_START && return "2002M01-2007M12"
    date < POST_AHP_START && return "2008M01-2023M09"
    "Post-AHP 2023M10-present"
end

sum_available(values::Dict{String,Float64}, names) = sum(get(values, name, 0.0) for name in names)

function build_country_panel(rows)
    by_date = Dict{Date,Dict{String,Float64}}()
    for row in rows
        value = parse_number(row["value_usd_billions"])
        isnan(value) && continue
        date = parse_date(row["date"])
        values = get!(by_date, date, Dict{String,Float64}())
        values[row["country_or_group"]] = value
    end
    by_date
end

function belgium_luxembourg(values)
    haskey(values, "Belgium-Luxembourg") && return values["Belgium-Luxembourg"]
    get(values, "Belgium", 0.0) + get(values, "Luxembourg", 0.0)
end

function caribbean_centres(values)
    haskey(values, "Carib Bnkng Ctrs") && return values["Carib Bnkng Ctrs"]
    sum_available(values, ["Cayman Islands", "Bahamas", "Bermuda"])
end

function core_eu27(values)
    financial_centre_members = Set(["Belgium", "Luxembourg", "Ireland", "Netherlands"])
    core_members = filter(name -> !(name in financial_centre_members), EU27_2026)
    sum_available(values, core_members)
end

function financial_centres(values)
    belgium_luxembourg(values) + caribbean_centres(values) + sum_available(values, [
        "Ireland", "Netherlands", "Switzerland", "Hong Kong", "Singapore",
    ])
end

function commodity_exporters(date::Date, values)
    if date < TIC_REPORTING_BREAK && haskey(values, "Oil Exporters")
        return values["Oil Exporters"]
    end
    sum_available(values, ["Saudi Arabia", "United Arab Emirates", "Kuwait", "Iraq", "Oman"])
end

function functional_values(date::Date, values::Dict{String,Float64})
    grouped = Dict(
        "Japan" => values["Japan"],
        "Mainland China" => values["China, Mainland"],
        "United Kingdom" => values["United Kingdom"],
        "Other East Asian exporters" => sum_available(values, ["Taiwan", "Korea, South"]),
        "Financial/offshore centres" => financial_centres(values),
        "Core EU-27 (identifiable)" => core_eu27(values),
        "Commodity exporters" => commodity_exporters(date, values),
        "Canada & other advanced" => sum_available(values, ["Canada", "Australia", "Norway", "Israel"]),
    )
    grouped["All other foreign"] = values["Grand Total"] - sum(Base.values(grouped))
    grouped
end

function stable_values(values::Dict{String,Float64})
    grouped = Dict(
        "Japan" => values["Japan"],
        "Mainland China" => values["China, Mainland"],
        "United Kingdom" => values["United Kingdom"],
        "Hong Kong" => values["Hong Kong"],
        "Taiwan" => values["Taiwan"],
        "Singapore" => values["Singapore"],
        "South Korea" => values["Korea, South"],
    )
    grouped["All other foreign"] = values["Grand Total"] - sum(Base.values(grouped))
    grouped
end

function write_panel(path, dates, values_by_group, totals, groups, definition)
    output_rows = Vector{Vector{Any}}()
    for (i, date) in enumerate(dates)
        total = totals[i]
        for group in groups
            value = values_by_group[group][i]
            push!(output_rows, Any[
                string(date), ahp_period(date), group,
                @sprintf("%.6f", value), @sprintf("%.10f", value / total),
                @sprintf("%.6f", total), definition,
            ])
        end
    end
    write_csv(path,
        ["date", "AHP_period", "foreign_group", "value_usd_billions", "share_of_foreign_total", "foreign_total_usd_billions", "classification"],
        output_rows)
end

function build_decomposition(by_date, groups, value_function; stable=false)
    required = stable ? [
        "Grand Total", "Japan", "China, Mainland", "United Kingdom", "Hong Kong",
        "Taiwan", "Singapore", "Korea, South",
    ] : ["Grand Total", "Japan", "China, Mainland", "United Kingdom"]
    dates = Date[]
    totals = Float64[]
    output = Dict(group => Float64[] for group in groups)
    for date in sort(collect(keys(by_date)))
        values = by_date[date]
        all(haskey(values, name) for name in required) || continue
        grouped = value_function(date, values)
        residual = grouped["All other foreign"]
        residual >= -1e-6 || error("Groups exceed TIC total at $date by $(-residual) USD billions")
        push!(dates, date)
        push!(totals, values["Grand Total"])
        for group in groups
            push!(output[group], max(grouped[group], 0.0))
        end
    end
    dates, output, totals
end

function year_ticks(last_date::Date)
    years = collect(2000:5:year(last_date))
    (Date.(years, 1, 1), string.(years))
end

function add_period_structure!(p, first_date, last_date, label_y)
    vspan!(p, [PERIOD_2_START, min(PERIOD_3_START, last_date)]; color="#F5C66A", alpha=0.11, linealpha=0, label=false)
    vspan!(p, [PERIOD_3_START, last_date]; color="#90AFC5", alpha=0.06, linealpha=0, label=false)
    vline!(p, [PERIOD_2_START, PERIOD_3_START]; color="#98A2B3", linewidth=0.8, linestyle=:dash, label=false)
    last_date >= POST_AHP_START && vline!(p, [POST_AHP_START]; color="#344054", linewidth=1.1, linestyle=:dot, label=false)
    spans = [
        (first_date, PERIOD_2_START - Day(1), "2000–2001"),
        (PERIOD_2_START, PERIOD_3_START - Day(1), "2002–2007"),
        (PERIOD_3_START, min(POST_AHP_START - Day(1), last_date), "2008–2023Q3"),
        (POST_AHP_START, last_date, "post-AHP"),
    ]
    for (left, right, label) in spans
        left > right && continue
        midpoint = left + Day(div(Dates.value(right - left), 2))
        annotate!(p, midpoint, label_y, text(label, 7, :center, "#475467"))
    end
end

function add_stack!(p, dates, values_by_group, groups, colors; scale=1.0)
    lower = zeros(length(dates))
    for group in groups
        values = values_by_group[group] ./ scale
        upper = lower .+ values
        plot!(p, dates, upper; fillrange=lower, fillcolor=colors[group], fillalpha=0.87,
            linecolor="#FFFFFF", linewidth=0.6, label=group)
        lower = upper
    end
end

function save_decomposition(stem, title, dates, values_by_group, totals, groups, colors; show_tic_break=false)
    last_date = last(dates)
    maximum_level = maximum(totals ./ 1000)
    ticks = year_ticks(last_date)

    p_level = plot(xlabel="", ylabel="Trillions of U.S. dollars", title="A. Dollar decomposition",
        xlims=(first(dates), last_date), ylims=(0, maximum_level * 1.11), xticks=ticks,
        legend=:outerright, legendfontsize=7, left_margin=9mm, right_margin=5mm,
        top_margin=4mm, ygrid=true, xgrid=false)
    add_stack!(p_level, dates, values_by_group, groups, colors; scale=1000)
    add_period_structure!(p_level, first(dates), last_date, maximum_level * 1.06)

    shares = Dict(group => values_by_group[group] ./ totals for group in groups)
    p_share = plot(xlabel="", ylabel="Share of TIC foreign total", title="B. Composition shares",
        xlims=(first(dates), last_date), ylims=(0, 1.08), xticks=ticks, yticks=0:0.2:1.0,
        yformatter=y -> "$(round(Int, 100y))%", legend=:outerright, legendfontsize=7,
        left_margin=9mm, right_margin=5mm, top_margin=4mm, ygrid=true, xgrid=false)
    add_stack!(p_share, dates, shares, groups, colors)
    add_period_structure!(p_share, first(dates), last_date, 1.035)

    if show_tic_break
        for (p, y) in [(p_level, maximum_level * 0.91), (p_share, 0.91)]
            vline!(p, [TIC_REPORTING_BREAK]; color="#101828", linewidth=1.0, linestyle=:dashdot, label=false)
            annotate!(p, TIC_REPORTING_BREAK + Month(2), y, text("2012 TIC classification break", 6, :left, "#344054"))
        end
    end

    combined = plot(p_level, p_share; layout=(2, 1), size=(1320, 940),
        plot_title=title, plot_titlefontsize=16, bottom_margin=7mm)
    savefig(combined, joinpath(FIGDIR, stem * ".png"))
    savefig(combined, joinpath(FIGDIR, stem * ".pdf"))
end

function write_crosswalks()
    functional_rows = Vector{Vector{Any}}()
    definitions = Dict(
        "Japan" => ["Japan"],
        "Mainland China" => ["China, Mainland"],
        "United Kingdom" => ["United Kingdom"],
        "Other East Asian exporters" => ["Taiwan", "Korea, South"],
        "Financial/offshore centres" => ["Belgium-Luxembourg (historical)", "Belgium", "Luxembourg", "Ireland", "Netherlands", "Switzerland", "Carib Bnkng Ctrs (historical)", "Cayman Islands", "Bahamas", "Bermuda", "Hong Kong", "Singapore"],
        "Core EU-27 (identifiable)" => filter(name -> !(name in Set(["Belgium", "Luxembourg", "Ireland", "Netherlands"])), EU27_2026),
        "Commodity exporters" => ["Oil Exporters (historical bridge)", "Saudi Arabia", "United Arab Emirates", "Kuwait", "Iraq", "Oman"],
        "Canada & other advanced" => ["Canada", "Australia", "Norway", "Israel"],
        "All other foreign" => ["Residual"],
    )
    for group in FUNCTIONAL_GROUPS, member in definitions[group]
        note = group == "All other foreign" ? "TIC Grand Total less all displayed groups" : "Included when separately reported; otherwise remains in residual"
        push!(functional_rows, Any[group, member, note])
    end
    write_csv(FUNCTIONAL_CROSSWALK, ["foreign_group", "component", "coverage_note"], functional_rows)

    stable_map = Dict(
        "Japan" => "Japan", "Mainland China" => "China, Mainland", "United Kingdom" => "United Kingdom",
        "Hong Kong" => "Hong Kong", "Taiwan" => "Taiwan", "Singapore" => "Singapore",
        "South Korea" => "Korea, South", "All other foreign" => "Residual",
    )
    stable_rows = [Any[group, stable_map[group], group == "All other foreign" ? "TIC Grand Total less the seven consistently reported economies" : "Reported in every month used"] for group in STABLE_GROUPS]
    write_csv(STABLE_CROSSWALK, ["foreign_group", "component", "coverage_note"], stable_rows)
end

function main()
    rows = read_tsv(INPUT)
    panel = build_country_panel(rows)
    functional_dates, functional_data, functional_totals = build_decomposition(
        panel, FUNCTIONAL_GROUPS, (date, values) -> functional_values(date, values))
    stable_dates, stable_data, stable_totals = build_decomposition(
        panel, STABLE_GROUPS, (date, values) -> stable_values(values); stable=true)

    write_panel(FUNCTIONAL_OUTPUT, functional_dates, functional_data, functional_totals,
        FUNCTIONAL_GROUPS, "Economic-function and custody-role grouping")
    write_panel(STABLE_OUTPUT, stable_dates, stable_data, stable_totals,
        STABLE_GROUPS, "Stable panel of economies reported in every month")
    write_crosswalks()

    save_decomposition("08_long_run_foreign_decomposition",
        "Foreign Treasury holders by economic function and custody role",
        functional_dates, functional_data, functional_totals, FUNCTIONAL_GROUPS, FUNCTIONAL_COLORS;
        show_tic_break=true)
    save_decomposition("09_long_run_foreign_decomposition_granular",
        "Stable-panel foreign decomposition: consistently reported economies",
        stable_dates, stable_data, stable_totals, STABLE_GROUPS, STABLE_COLORS)

    @printf("Functional decomposition: %s to %s (%d months)\n", first(functional_dates), last(functional_dates), length(functional_dates))
    @printf("Stable-panel decomposition: %s to %s (%d months)\n", first(stable_dates), last(stable_dates), length(stable_dates))
end

main()

end # module
