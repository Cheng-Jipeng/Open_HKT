#!/usr/bin/env julia

using Dates
using Plots
using Plots.PlotMeasures
using Printf

const ROOT = @__DIR__
const FIGDIR = joinpath(ROOT, "figures")
const SECTOR_INPUT = joinpath(ROOT, "plot_data", "sector_history.tsv")
const COUNTRY_INPUT = joinpath(ROOT, "plot_data", "country_history.tsv")
const SECTOR_OUTPUT = joinpath(ROOT, "long_run_sector_decomposition_quarterly.csv")
const FOREIGN_OUTPUT = joinpath(ROOT, "long_run_foreign_decomposition_monthly.csv")
const GRANULAR_FOREIGN_OUTPUT = joinpath(ROOT, "long_run_foreign_decomposition_granular_monthly.csv")
const GRANULAR_CROSSWALK_OUTPUT = joinpath(ROOT, "long_run_foreign_group_crosswalk.csv")

const SAMPLE_START = Date(1990, 1, 1)
const PERIOD_2_START = Date(2002, 1, 1)
const PERIOD_3_START = Date(2008, 1, 1)
const POST_AHP_START = Date(2023, 10, 1)

const SECTOR_GROUPS = [
    "Other domestic holders",
    "Federal Reserve",
    "Domestic government & public pensions",
    "Rest of world",
]
const SECTOR_COLORS = Dict(
    "Other domestic holders" => "#2A7F62",
    "Federal Reserve" => "#175CD3",
    "Domestic government & public pensions" => "#B54708",
    "Rest of world" => "#B42318",
)

const FOREIGN_GROUPS = [
    "All other foreign",
    "United Kingdom",
    "Mainland China",
    "Japan",
]
const FOREIGN_COLORS = Dict(
    "All other foreign" => "#667085",
    "United Kingdom" => "#7F56D9",
    "Mainland China" => "#B42318",
    "Japan" => "#175CD3",
)

const GRANULAR_FOREIGN_GROUPS = [
    "All other foreign",
    "EU-27 (identifiable)",
    "Middle East (reported/bridge)",
    "Four Asian dragons",
    "Canada",
    "United Kingdom",
    "Mainland China",
    "Japan",
]
const GRANULAR_FOREIGN_COLORS = Dict(
    "All other foreign" => "#98A2B3",
    "EU-27 (identifiable)" => "#039855",
    "Middle East (reported/bridge)" => "#F79009",
    "Four Asian dragons" => "#C11574",
    "Canada" => "#06AED4",
    "United Kingdom" => "#7F56D9",
    "Mainland China" => "#B42318",
    "Japan" => "#175CD3",
)

const EU27_2026 = [
    "Austria", "Belgium", "Bulgaria", "Croatia", "Cyprus", "Czechia",
    "Denmark", "Estonia", "Finland", "France", "Germany", "Greece",
    "Hungary", "Ireland", "Italy", "Latvia", "Lithuania", "Luxembourg",
    "Malta", "Netherlands", "Poland", "Portugal", "Romania", "Slovakia",
    "Slovenia", "Spain", "Sweden",
]
const MIDDLE_EAST_NAMED = [
    "Saudi Arabia", "United Arab Emirates", "Kuwait", "Israel", "Turkey",
    "Iraq", "Oman", "Egypt",
]
const FOUR_DRAGONS = ["Hong Kong", "Taiwan", "Singapore", "Korea, South"]
const TIC_REPORTING_BREAK = Date(2012, 1, 1)

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

function sector_period(date::Date)
    date < PERIOD_2_START && return "1990Q1-2001Q4"
    date < PERIOD_3_START && return "2002Q1-2007Q4"
    date < POST_AHP_START && return "2008Q1-2023Q3"
    "Post-AHP 2023Q4-present"
end

function foreign_period(date::Date)
    date < PERIOD_2_START && return "2000M03-2001M12"
    date < PERIOD_3_START && return "2002M01-2007M12"
    date < POST_AHP_START && return "2008M01-2023M09"
    "Post-AHP 2023M10-present"
end

function year_ticks(first_year::Int, last_date::Date)
    years = collect(first_year:5:year(last_date))
    if isempty(years) || last(years) <= year(last_date) - 3
        push!(years, year(last_date))
    end
    (Date.(years, 1, 1), string.(years))
end

function add_period_structure!(plot_object, first_date::Date, last_date::Date, label_y::Float64)
    if first_date < PERIOD_2_START
        vspan!(plot_object, [PERIOD_2_START, min(PERIOD_3_START, last_date)];
            color="#F5C66A", alpha=0.11, linealpha=0, label=false)
    end
    if last_date > PERIOD_3_START
        vspan!(plot_object, [PERIOD_3_START, last_date];
            color="#90AFC5", alpha=0.06, linealpha=0, label=false)
    end
    vline!(plot_object, [PERIOD_2_START, PERIOD_3_START];
        color="#98A2B3", linewidth=0.8, linestyle=:dash, label=false)
    if last_date >= POST_AHP_START
        vline!(plot_object, [POST_AHP_START];
            color="#344054", linewidth=1.1, linestyle=:dot, label=false)
    end

    first_period_label = year(first_date) == 1990 ? "1990–2001" : "$(year(first_date))–2001"
    spans = [
        (first_date, min(PERIOD_2_START - Day(1), last_date), first_period_label),
        (max(first_date, PERIOD_2_START), min(PERIOD_3_START - Day(1), last_date), "2002–2007"),
        (max(first_date, PERIOD_3_START), min(POST_AHP_START - Day(1), last_date), "2008–2023Q3"),
        (max(first_date, POST_AHP_START), last_date, "post-AHP"),
    ]
    for (left, right, label) in spans
        left > right && continue
        midpoint = left + Day(div(Dates.value(right - left), 2))
        annotate!(plot_object, midpoint, label_y, text(label, 7, :center, "#475467"))
    end
    plot_object
end

function add_stacked_area!(plot_object, dates, values_by_group, groups, colors)
    lower = zeros(length(dates))
    for group in groups
        values = values_by_group[group]
        upper = lower .+ values
        plot!(plot_object, dates, upper;
            fillrange=lower,
            fillcolor=colors[group],
            fillalpha=0.86,
            linecolor="#FFFFFF",
            linewidth=0.7,
            label=group)
        lower = upper
    end
    plot_object
end

function build_sector_decomposition(rows)
    by_date = Dict{Date,Dict{String,Float64}}()
    component_total = Dict{Date,Float64}()
    for row in rows
        date = parse_date(row["date"])
        date < SAMPLE_START && continue
        value = parse_number(row["value_usd_billions"])
        isnan(value) && continue
        holder = row["holder"]
        by_date_values = get!(by_date, date, Dict{String,Float64}())
        by_date_values[holder] = value
        holder != "Total assets" && (component_total[date] = get(component_total, date, 0.0) + value)
    end

    government_holders = [
        "State and local governments",
        "Federal government pension funds",
        "State and local pension funds",
    ]
    dates = Date[]
    values = Dict(group => Float64[] for group in SECTOR_GROUPS)
    totals = Float64[]
    output_rows = Vector{Vector{Any}}()
    max_component_gap = 0.0

    for date in sort(collect(keys(by_date)))
        holder_values = by_date[date]
        required = vcat(["Total assets", "Federal Reserve", "Rest of world"], government_holders)
        all(haskey(holder_values, holder) for holder in required) || continue
        total = holder_values["Total assets"]
        federal_reserve = holder_values["Federal Reserve"]
        foreign = holder_values["Rest of world"]
        government = sum(holder_values[holder] for holder in government_holders)
        other_domestic = total - federal_reserve - foreign - government
        other_domestic >= -1e-6 || error("Negative domestic residual at $date: $other_domestic")
        max_component_gap = max(max_component_gap, abs(get(component_total, date, total) - total))

        grouped = Dict(
            "Other domestic holders" => max(other_domestic, 0.0),
            "Federal Reserve" => federal_reserve,
            "Domestic government & public pensions" => government,
            "Rest of world" => foreign,
        )
        push!(dates, date)
        push!(totals, total)
        for group in SECTOR_GROUPS
            group_value = grouped[group]
            push!(values[group], group_value)
            push!(output_rows, Any[
                string(date), "$(year(date))Q$(quarterofyear(date))", sector_period(date),
                group, @sprintf("%.6f", group_value), @sprintf("%.10f", group_value / total),
                @sprintf("%.6f", total),
            ])
        end
    end

    isempty(dates) && error("No complete sector observations")
    max_component_gap < 1e-4 || error("L.210 components fail to add to total: max gap = $max_component_gap")
    write_csv(
        SECTOR_OUTPUT,
        ["date", "quarter", "AHP_period", "holder_group", "value_usd_billions", "share_of_total", "total_usd_billions"],
        output_rows,
    )
    dates, values, totals, max_component_gap
end

function build_foreign_decomposition(rows)
    by_date = Dict{Date,Dict{String,Float64}}()
    for row in rows
        value = parse_number(row["value_usd_billions"])
        isnan(value) && continue
        date = parse_date(row["date"])
        by_date_values = get!(by_date, date, Dict{String,Float64}())
        by_date_values[row["country_or_group"]] = value
    end

    exact_names = Dict(
        "Japan" => "Japan",
        "Mainland China" => "China, Mainland",
        "United Kingdom" => "United Kingdom",
    )
    dates = Date[]
    values = Dict(group => Float64[] for group in FOREIGN_GROUPS)
    totals = Float64[]
    output_rows = Vector{Vector{Any}}()

    for date in sort(collect(keys(by_date)))
        entity_values = by_date[date]
        required = vcat(["Grand Total"], collect(Base.values(exact_names)))
        all(haskey(entity_values, name) for name in required) || continue
        total = entity_values["Grand Total"]
        grouped = Dict(
            group => entity_values[source_name] for (group, source_name) in exact_names
        )
        grouped["All other foreign"] = total - sum(Base.values(grouped))
        grouped["All other foreign"] >= -1e-6 || error("Negative foreign residual at $date")

        push!(dates, date)
        push!(totals, total)
        for group in FOREIGN_GROUPS
            group_value = max(grouped[group], 0.0)
            push!(values[group], group_value)
            push!(output_rows, Any[
                string(date), foreign_period(date), group,
                @sprintf("%.6f", group_value), @sprintf("%.10f", group_value / total),
                @sprintf("%.6f", total),
            ])
        end
    end

    isempty(dates) && error("No complete foreign-holder observations")
    write_csv(
        FOREIGN_OUTPUT,
        ["date", "AHP_period", "foreign_group", "value_usd_billions", "share_of_foreign_total", "foreign_total_usd_billions"],
        output_rows,
    )
    dates, values, totals
end

function sum_available(entity_values::Dict{String,Float64}, names)
    sum(get(entity_values, name, 0.0) for name in names)
end

function identifiable_eu27(entity_values::Dict{String,Float64})
    # The historical file reports Belgium and Luxembourg jointly through 2001.
    belgium_luxembourg = if haskey(entity_values, "Belgium-Luxembourg")
        entity_values["Belgium-Luxembourg"]
    else
        get(entity_values, "Belgium", 0.0) + get(entity_values, "Luxembourg", 0.0)
    end
    other_eu_members = filter(name -> !(name in ["Belgium", "Luxembourg"]), EU27_2026)
    belgium_luxembourg + sum_available(entity_values, other_eu_members)
end

function middle_east_position(date::Date, entity_values::Dict{String,Float64})
    named_non_oil = sum_available(entity_values, ["Israel", "Turkey", "Egypt"])
    if date < TIC_REPORTING_BREAK && haskey(entity_values, "Oil Exporters")
        # TIC's former Oil Exporters memorandum group is the only historical
        # observation that captures Saudi Arabia and most Gulf holders. It also
        # contains some non-Middle-Eastern oil exporters, so this is a bridge,
        # not an exact geographic aggregate.
        return entity_values["Oil Exporters"] + named_non_oil
    end
    sum_available(entity_values, MIDDLE_EAST_NAMED)
end

function write_granular_crosswalk()
    rows = Vector{Vector{Any}}()
    for member in EU27_2026
        push!(rows, Any[
            "EU-27 (identifiable)", member, "2026 EU membership",
            "Included when separately reported by TIC; otherwise remains in All other foreign",
        ])
    end
    push!(rows, Any[
        "EU-27 (identifiable)", "Belgium-Luxembourg", "Historical bridge through 2001",
        "Used instead of separate Belgium and Luxembourg when the joint row is reported",
    ])
    for member in MIDDLE_EAST_NAMED
        push!(rows, Any[
            "Middle East (reported/bridge)", member, "Named country",
            "Included when separately reported by TIC; otherwise remains in All other foreign",
        ])
    end
    push!(rows, Any[
        "Middle East (reported/bridge)", "Oil Exporters", "Historical bridge before 2012",
        "Captures Saudi Arabia and most Gulf holders but also includes some non-Middle-Eastern oil exporters",
    ])
    for member in FOUR_DRAGONS
        push!(rows, Any["Four Asian dragons", member, "Exact named country/economy", "Included whenever reported"])
    end
    for member in ["Japan", "China, Mainland", "United Kingdom", "Canada"]
        group = member == "China, Mainland" ? "Mainland China" : member
        push!(rows, Any[group, member, "Exact named country/economy", "Included whenever reported"])
    end
    push!(rows, Any[
        "All other foreign", "Residual", "Grand Total less all displayed groups",
        "Includes nonreported countries and any EU or Middle-East members not separately identified",
    ])
    write_csv(
        GRANULAR_CROSSWALK_OUTPUT,
        ["foreign_group", "component", "treatment", "coverage_note"],
        rows,
    )
end

function build_granular_foreign_decomposition(rows)
    by_date = Dict{Date,Dict{String,Float64}}()
    for row in rows
        value = parse_number(row["value_usd_billions"])
        isnan(value) && continue
        date = parse_date(row["date"])
        entity_values = get!(by_date, date, Dict{String,Float64}())
        entity_values[row["country_or_group"]] = value
    end

    required_exact = ["Grand Total", "Japan", "China, Mainland", "United Kingdom", "Canada"]
    dates = Date[]
    group_values = Dict(group => Float64[] for group in GRANULAR_FOREIGN_GROUPS)
    totals = Float64[]
    output_rows = Vector{Vector{Any}}()

    for date in sort(collect(keys(by_date)))
        entity_values = by_date[date]
        all(haskey(entity_values, name) for name in required_exact) || continue
        total = entity_values["Grand Total"]
        grouped = Dict(
            "Japan" => entity_values["Japan"],
            "Mainland China" => entity_values["China, Mainland"],
            "United Kingdom" => entity_values["United Kingdom"],
            "Canada" => entity_values["Canada"],
            "EU-27 (identifiable)" => identifiable_eu27(entity_values),
            "Middle East (reported/bridge)" => middle_east_position(date, entity_values),
            "Four Asian dragons" => sum_available(entity_values, FOUR_DRAGONS),
        )
        displayed_total = sum(Base.values(grouped))
        residual = total - displayed_total
        grouped["All other foreign"] = residual
        residual >= -1e-6 || error(
            "Granular groups exceed the TIC total at $date by $(-residual) USD billions"
        )

        push!(dates, date)
        push!(totals, total)
        for group in GRANULAR_FOREIGN_GROUPS
            group_value = max(grouped[group], 0.0)
            push!(group_values[group], group_value)
            push!(output_rows, Any[
                string(date), foreign_period(date), group,
                @sprintf("%.6f", group_value), @sprintf("%.10f", group_value / total),
                @sprintf("%.6f", total), date < TIC_REPORTING_BREAK ? "pre-2012 TIC classification" : "2012+ TIC classification",
            ])
        end
    end

    isempty(dates) && error("No complete observations for granular foreign decomposition")
    write_csv(
        GRANULAR_FOREIGN_OUTPUT,
        ["date", "AHP_period", "foreign_group", "value_usd_billions", "share_of_foreign_total", "foreign_total_usd_billions", "TIC_classification_vintage"],
        output_rows,
    )
    write_granular_crosswalk()
    dates, group_values, totals
end

function save_both(plot_object, stem::String)
    savefig(plot_object, joinpath(FIGDIR, stem * ".png"))
    savefig(plot_object, joinpath(FIGDIR, stem * ".pdf"))
end

function plot_sector_decomposition(dates, values, totals)
    last_date = last(dates)
    tick_spec = year_ticks(1990, last_date)
    maximum_level = maximum(totals ./ 1000)

    p_level = plot(
        xlabel="",
        ylabel="Trillions of U.S. dollars",
        title="A. Dollar positions",
        xlims=(first(dates), last_date),
        ylims=(0, maximum_level * 1.10),
        xticks=tick_spec,
        legend=:outerright,
        legend_columns=1,
        legendfontsize=8,
        left_margin=9mm,
        right_margin=5mm,
        top_margin=4mm,
        ygrid=true,
        xgrid=false,
    )
    add_period_structure!(p_level, first(dates), last_date, maximum_level * 1.055)
    for group in SECTOR_GROUPS
        plot!(p_level, dates, values[group] ./ 1000;
            label=group, color=SECTOR_COLORS[group],
            linewidth=group == "Rest of world" ? 2.7 : 2.1)
    end

    share_values = Dict(group => values[group] ./ totals for group in SECTOR_GROUPS)
    p_share = plot(
        xlabel="",
        ylabel="Share of L.210 total",
        title="B. Composition shares",
        xlims=(first(dates), last_date),
        ylims=(0, 1.08),
        xticks=tick_spec,
        yticks=0:0.2:1.0,
        yformatter=y -> "$(round(Int, 100y))%",
        legend=:outerright,
        legendfontsize=8,
        left_margin=9mm,
        right_margin=5mm,
        top_margin=4mm,
        ygrid=true,
        xgrid=false,
    )
    add_stacked_area!(p_share, dates, share_values, SECTOR_GROUPS, SECTOR_COLORS)
    add_period_structure!(p_share, first(dates), last_date, 1.035)

    combined = plot(
        p_level, p_share;
        layout=(2, 1),
        size=(1250, 920),
        plot_title="Long-run decomposition of U.S. marketable Treasury holders, 1990–present",
        plot_titlefontsize=16,
        bottom_margin=7mm,
    )
    save_both(combined, "07_long_run_coarse_holder_decomposition")
end

function plot_foreign_decomposition(dates, values, totals)
    last_date = last(dates)
    tick_spec = year_ticks(2000, last_date)
    maximum_level = maximum(totals ./ 1000)

    p_level = plot(
        xlabel="",
        ylabel="Trillions of U.S. dollars",
        title="A. Dollar positions",
        xlims=(first(dates), last_date),
        ylims=(0, maximum_level * 1.11),
        xticks=tick_spec,
        legend=:outerright,
        legend_columns=1,
        legendfontsize=8,
        left_margin=9mm,
        right_margin=5mm,
        top_margin=4mm,
        ygrid=true,
        xgrid=false,
    )
    add_period_structure!(p_level, first(dates), last_date, maximum_level * 1.06)
    for group in FOREIGN_GROUPS
        plot!(p_level, dates, values[group] ./ 1000;
            label=group, color=FOREIGN_COLORS[group],
            linewidth=group == "All other foreign" ? 2.6 : 2.1)
    end

    share_values = Dict(group => values[group] ./ totals for group in FOREIGN_GROUPS)
    p_share = plot(
        xlabel="",
        ylabel="Share of TIC foreign total",
        title="B. Composition shares",
        xlims=(first(dates), last_date),
        ylims=(0, 1.08),
        xticks=tick_spec,
        yticks=0:0.2:1.0,
        yformatter=y -> "$(round(Int, 100y))%",
        legend=:outerright,
        legendfontsize=8,
        left_margin=9mm,
        right_margin=5mm,
        top_margin=4mm,
        ygrid=true,
        xgrid=false,
    )
    add_stacked_area!(p_share, dates, share_values, FOREIGN_GROUPS, FOREIGN_COLORS)
    add_period_structure!(p_share, first(dates), last_date, 1.035)

    combined = plot(
        p_level, p_share;
        layout=(2, 1),
        size=(1250, 920),
        plot_title="Foreign holdings of U.S. Treasury securities: selected economies and residual",
        plot_titlefontsize=16,
        bottom_margin=7mm,
    )
    save_both(combined, "08_long_run_foreign_decomposition")
end

function add_tic_reporting_break!(plot_object, label_y::Float64)
    vline!(plot_object, [TIC_REPORTING_BREAK];
        color="#101828", linewidth=1.0, linestyle=:dashdot, label=false)
    annotate!(plot_object, TIC_REPORTING_BREAK + Month(2), label_y,
        text("2012 TIC reporting break", 6, :left, "#344054"))
    plot_object
end

function plot_granular_foreign_decomposition(dates, values, totals)
    last_date = last(dates)
    tick_spec = year_ticks(2000, last_date)
    maximum_level = maximum(totals ./ 1000)
    level_values = Dict(group => values[group] ./ 1000 for group in GRANULAR_FOREIGN_GROUPS)
    share_values = Dict(group => values[group] ./ totals for group in GRANULAR_FOREIGN_GROUPS)

    p_level = plot(
        xlabel="",
        ylabel="Trillions of U.S. dollars",
        title="A. Dollar decomposition",
        xlims=(first(dates), last_date),
        ylims=(0, maximum_level * 1.11),
        xticks=tick_spec,
        legend=:outerright,
        legendfontsize=7,
        left_margin=9mm,
        right_margin=5mm,
        top_margin=4mm,
        ygrid=true,
        xgrid=false,
    )
    add_stacked_area!(p_level, dates, level_values, GRANULAR_FOREIGN_GROUPS, GRANULAR_FOREIGN_COLORS)
    add_period_structure!(p_level, first(dates), last_date, maximum_level * 1.06)
    add_tic_reporting_break!(p_level, maximum_level * 0.92)

    p_share = plot(
        xlabel="",
        ylabel="Share of TIC foreign total",
        title="B. Composition shares",
        xlims=(first(dates), last_date),
        ylims=(0, 1.08),
        xticks=tick_spec,
        yticks=0:0.2:1.0,
        yformatter=y -> "$(round(Int, 100y))%",
        legend=:outerright,
        legendfontsize=7,
        left_margin=9mm,
        right_margin=5mm,
        top_margin=4mm,
        ygrid=true,
        xgrid=false,
    )
    add_stacked_area!(p_share, dates, share_values, GRANULAR_FOREIGN_GROUPS, GRANULAR_FOREIGN_COLORS)
    add_period_structure!(p_share, first(dates), last_date, 1.035)
    add_tic_reporting_break!(p_share, 0.91)

    combined = plot(
        p_level, p_share;
        layout=(2, 1),
        size=(1300, 940),
        plot_title="Granular long-run foreign-holder decomposition of U.S. Treasury securities",
        plot_titlefontsize=16,
        bottom_margin=7mm,
    )
    save_both(combined, "09_long_run_foreign_decomposition_granular")
end

sector_rows = read_tsv(SECTOR_INPUT)

sector_dates, sector_values, sector_totals, sector_gap = build_sector_decomposition(sector_rows)
plot_sector_decomposition(sector_dates, sector_values, sector_totals)

@printf("Sector sample: %s to %s (%d quarters)\n", first(sector_dates), last(sector_dates), length(sector_dates))
@printf("Maximum L.210 component adding-up gap: %.9f USD billions\n", sector_gap)
include(joinpath(ROOT, "plot_proposed_foreign_decompositions.jl"))
println("Saved long-run CSVs and figures 07-09 in $FIGDIR")
