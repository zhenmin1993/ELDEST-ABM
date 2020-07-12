dataPath = "scenarios/input_data"
resultsPath = "scenarios/results/BE_test"

function RetrieveResults(resultsPath::String)
    selected_representative_days_file = normpath(joinpath(@__DIR__, resultsPath, "decision_variables_short.csv"))
    selected_representativeDays_raw = CSV.read(selected_representative_days_file,delim=';')
    selected_representativeDays = zeros(size(selected_representativeDays_raw)[1],2)
    for day in 1:size(selected_representativeDays_raw)[1]
        selected_representativeDays[day,1] = parse(Float64,selected_representativeDays_raw[day,:periods][2:end])
        selected_representativeDays[day,2] = selected_representativeDays_raw[day,:weights]
    end
    return selected_representativeDays
end


function RetrieveData(dataPath::String, representativeDays::Matrix)


    load_file = normpath(joinpath(@__DIR__, dataPath, "BE2015Load.csv"))
    allLoad = CSV.read(load_file,delim=';')

    onShoreWind_file = normpath(joinpath(@__DIR__, dataPath, "BE2015Onshore.csv"))
    allOnShore = CSV.read(onShoreWind_file,delim=';')

    offShoreWind_file = normpath(joinpath(@__DIR__, dataPath, "BE2015Offshore.csv"))
    allOffShore = CSV.read(offShoreWind_file,delim=';')

    solar_file = normpath(joinpath(@__DIR__, dataPath, "BE2015Sun.csv"))
    allSolar = CSV.read(solar_file,delim=';')

    totalDays = size(representativeDays,1)
    day2hour = 24
    representativeLoad = zeros(totalDays,day2hour)
    representativeOnShoreWind = zeros(totalDays,day2hour)
    representativeOffShoreWind = zeros(totalDays,day2hour)
    representativeSolar = zeros(totalDays,day2hour)
    for day in 1:totalDays
        thisSelectedDay = representativeDays[day,1]
        startHour = Int((thisSelectedDay-1) * 24 + 1)

        #representativeLoad[day,:] = allLoad[:AvgOfRealTime][startHour:startHour+24-1]
        representativeLoad[day,:] = allLoad[startHour:startHour+24-1, :AvgOfRealTime]
        representativeOnShoreWind[day,:] = allOnShore[startHour:startHour+24-1,:capacity_factor]
        representativeOffShoreWind[day,:] = allOffShore[startHour:startHour+24-1,:capacity_factor]
        representativeSolar[day,:] = allSolar[startHour:startHour+24-1,:capacity_factor]
        #println(allOnShore[:capacity_factor][startHour:startHour+24-1])
    end
    return representativeLoad,representativeOnShoreWind,representativeOffShoreWind,representativeSolar
end

selected_representativeDays = RetrieveResults(resultsPath)
representativeLoad,representativeOnShoreWind,representativeOffShoreWind,representativeSolar = RetrieveData(dataPath, selected_representativeDays)

representativeData = Dict{Symbol,Matrix}()
representativeData[:Weights] = selected_representativeDays
representativeData[:Load] = representativeLoad
representativeData[:OnShoreWind] = representativeOnShoreWind
representativeData[:OffShoreWind] = representativeOffShoreWind
representativeData[:Solar] = representativeSolar

unsupplyLoad = Array{Float64,1}(undef,0)
weight_unsupplyLoad = Array{Float64,1}(undef,0)
for day in 1:year2day
    for hour in 1:24
        if representativeLoad[day,hour] >= 13100
            push!(unsupplyLoad,representativeLoad[day,hour])
            push!(weight_unsupplyLoad,selected_representativeDays[day,2])
        end
    end
end
