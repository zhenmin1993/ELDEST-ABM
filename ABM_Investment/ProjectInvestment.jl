import Statistics

function SimulateInvestment(systemSettings::SystemSettings, MO::MarketOperator, allGenCos::Vector{GenCo}, systemLoad::Load,allPowerFlows::Vector{PowerFlow}, technologyPool::Vector{Technology},systemState::SystemState,systemHistory::SystemHistory)
    totalHorizon = systemSettings.totalHorizon
    milestoneYear = systemSettings.milestoneYear
    weightFactors = systemSettings.simulationSettings.representativeData[:Weights]
    year2day = systemSettings.simulationSettings.year2day
    day2hour = systemSettings.simulationSettings.day2hour
    investmentSequence = systemSettings.simulationSettings.investmentSequence

    for year in 1:totalHorizon
        ########################################################################
        #NOTE:Technology decommission and record the amount each agent has decommissioned
        decomissionedCapacity = zeros(1,length(allGenCos))
        for genCoCount in 1:length(allGenCos)
            technologyToDecomission = allGenCos[genCoCount].Decomission(year, allPowerFlows)
            for technology in technologyToDecomission
                decomissionedCapacity[genCoCount] += technology.designProperties.installedCapacity
            end
        end

        ########################################################################

        println("This is year ", year)

        if year % milestoneYear == 0
            push!(systemHistory.systemDecisionSequence, Array{Int64,1}(undef,0))
            ##########################################################################
            #NOTE:start investment process here
            roundCount = 0
            addNew = true
            while addNew == true
                roundCount += 1
                sequence = randperm(length(allGenCos))
                push!(systemHistory.systemDecisionSequence[end],sequence)
                addNew = false
                println("This sequence: ", sequence)
                for i in sequence
                    thisGenCo = allGenCos[i]
                    investmentIndicator,bestTechnology = thisGenCo.InvestmentDecision(allGenCos,MO,technologyPool,systemLoad,year,systemSettings,systemHistory)

                    addNew = addNew || investmentIndicator
                    if investmentIndicator == true
                        #NOTE:build essential connection for new investment decision
                        thisGenCo.ExecuteInvestmentDecision(bestTechnology,allPowerFlows,MO,year)
                        push!(systemHistory.InvestmentHistory,bestTechnology.type)
                        println(bestTechnology.type)
                    end
                    if investmentIndicator != true
                        println(investmentIndicator)
                        push!(systemHistory.InvestmentHistory,:NoNew)
                    end
                end
            end
        end

        ##########################################################################
        #NOTE: system state/environment changes each year
        yearlyTechnologyMix = Array{Technology,1}(undef,0)
        for genCo in allGenCos
            for technology in genCo.technologyPortfolio.technologies
                push!(yearlyTechnologyMix, technology)
            end
        end
        push!(systemHistory.systemCapacityMix, deepcopy(yearlyTechnologyMix))
        ##########################################################################

        ##########################################################################
        #NOTE: real world spot market simulation
        yearlyPriceStream = Array{Float64,1}(undef,0)
        for day in 1:year2day
            dailyPriceStream = Array{Float64,1}(undef,0)
            for hour in 1:day2hour
                systemState.TimeSeries(day,hour,systemLoad,yearlyTechnologyMix)
                thisMarketPrice = MO.ClearMarket(yearlyTechnologyMix, allPowerFlows, systemLoad)
                push!(dailyPriceStream, deepcopy(thisMarketPrice))
                MO.Payment(allPowerFlows,day,hour,:real,systemSettings)
            end
            dailyAveragePrice = Statistics.mean(dailyPriceStream)
            push!(yearlyPriceStream, deepcopy(dailyAveragePrice))
        end


        yearlyAveragePrice = (yearlyPriceStream' * weightFactors[:,2])/sum(weightFactors[:,2])
        append!(systemHistory.systemElectricityPrice , yearlyAveragePrice)
        ##########################################################################



        ##########################################################################
        #NOTE: record history of this year
        for genCo in allGenCos
            push!(genCo.history.investmentHistory, TechnologyPortfolio(genCo.history.yearlyInvestment))
            push!(genCo.history.technologyMixHistory, deepcopy(genCo.technologyPortfolio))
            genCo.history.yearlyInvestment = Array{Technology}(undef,0)
        end
    end
end
