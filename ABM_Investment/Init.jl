import Combinatorics
using Random
using DataFrames
import CSV
using Printf
#import PyPlot

using JuMP
#using GLPK
using Gurobi

using PyPlot, PyCall
#@pyimport mpl_toolkits.axes_grid1 as axes_grid1
axes_grid1 = pyimport("mpl_toolkits.axes_grid1")

include("DataLog.jl")
include("Agents/ScenarioTree.jl")

include("Agents/Parameters.jl")
include("Agents/PowerFlow.jl")
include("Agents/EnergyProducer.jl")


include("Agents/System.jl")

#include("RepresentativeDays_ABM/RepresentativeDays.jl")
include("RepresentativeDays_ABM/RepresentativeData.jl")

#GUROBI_ENV = Gurobi.Env()
#setparams!(GUROBI_ENV, OutputFlag = 0,Method = 1)

Random.seed!(12)

#Initialize global parameters
investmentModelSelection = :GEP # :EMCAS, :EMLab, :GEP
investmentSequence = :sequential
simulationSettings = SimulationSettings(day2hour,year2day,segmentNumbers,downpaymentRatio,representativeData,investmentSequence,investmentModelSelection)
systemSettings = SystemSettings(GenCoNumbers,totalHorizon,milestoneYear,interestRate,simulationSettings)


function InitSystem(systemSettings::SystemSettings,genCoHorizon::Real; kwargs...)
    V = Dict(kwargs)
    if haskey(V,:gapCoverPercentage) && haskey(V,:divisionTypeShare)
        gapCoverPercentage = V[:gapCoverPercentage]
        divisionTypeShare = V[:divisionTypeShare]
    end
##########################################################################################################
    #Initialize technology pool
    technologyPool = Array{Technology,1}(undef,0)
    initialTechnologyHistory = TechnologyHistory(systemSettings)


    for i in 1:length(technologyType)
        thisDesignProperty = DesignProperty(availability[i], constructionTimeStamp[i],constructionTime[i],deconstructionTime[i],efficiency[i],emission_ton_perMWh[i],lifeTime[i],unitCapacity[i])
        thisEconomicProperty = EconomicProperty(unitConstructionCost[i], unitDeconstructionCost[i], unitVOMCost[i],unitFOMCost[i],systemSettings)

        if technologyType[i] in [:Base,:Mid,:Peak]
            thisTechnology = ConventionalPlants(technologyType[i],thisDesignProperty, thisEconomicProperty,systemSettings)
            thisTechnology.UpdateCost(emissionPrice,fuelPrice[i])
        end

        #if technologyType[i] in [:OnShoreWind,:OffShoreWind,:Solar]
        #    thisTechnology = RenewablePlants(technologyType[i],thisDesignProperty, thisEconomicProperty, capacityFactorImproveRate,[:offline,:subsidized],systemSettings)
        #end


        thisTechnology.MultipleUnits(1,systemSettings)
        println(thisTechnology.economicProperties.constructionCost)
        push!(technologyPool, thisTechnology)
    end



    ##########################################################################################################
    initial_ExistingCapacity_TimeStamp = [11 11 11 11;
                                          11 11 11 11;
                                          11 11 11 11]
    initial_Capacity = Array{Technology,1}(undef,0)

    for pre_TimeStamp in 1:size(initial_ExistingCapacity_TimeStamp)[2]
        for techCount in 1:length(technologyPool)
            thisInitialPlant = deepcopy(technologyPool[techCount])
            for techNum in 1:initial_ExistingCapacity_TimeStamp[techCount,pre_TimeStamp]
                thisInitialPlant.designProperties.constructionTimeStamp = (pre_TimeStamp-4) * systemSettings.milestoneYear
                push!(initial_Capacity,deepcopy(thisInitialPlant))
            end
        end
    end






    ##########################################################################################################
    #Initialize GenCos and ownerships

    systemCapacityMix = Array{Array{Technology,1},1}(undef,0)
    systemHistory = SystemHistory()
    allGenerators = Array{Technology,1}(undef,0)
    allOwnerShips = Array{GenCoPortfolioOwnership,1}(undef,0)
    allGenCos = Array{GenCo,1}(undef,0)
    for i in 1:systemSettings.GenCoNumbers
        thisName = string("GenCo", i)
        thisTechnologies = Array{Technology,1}(undef,0)
        thisTechnologyPortfolio = TechnologyPortfolio(Array{Technology,1}(undef,0))
        thisCompetitorExpansion = Array{CapacityExpansionEdge,1}(undef,0)
        thisCompetitorDivision=Array{CapacityDivisionEdge,1}(undef,0)

        if haskey(V,:gapCoverPercentage) && haskey(V,:divisionTypeShare)
            for m in 1:length(gapCoverProbability[i])
                push!(thisCompetitorExpansion, CapacityExpansionEdge(gapCoverProbability[i][m],gapCoverPercentage[i][m]))
            end
            for k in 1:length(divisionProbability[i])
                push!(thisCompetitorDivision, CapacityDivisionEdge(divisionProbability[i][k],divisionTypeShare[i][k]))
            end
        end


        thisGenCo = GenCo(thisName, genCoHorizon,thisTechnologyPortfolio,deepcopy(technologyPool);competitorExpansion = thisCompetitorExpansion,competitorDivision=thisCompetitorDivision)
        thisOwnerShip = GenCoPortfolioOwnership(thisGenCo, thisTechnologyPortfolio)
        for thisType in technologyType
            thisGenCo.history.investmentYearByType[thisType] = zeros(totalHorizon)
        end
        push!(allOwnerShips,thisOwnerShip)
        push!(allGenCos,thisGenCo)
    end

    #Randomly distribute initial capacities
    for n in 1:length(initial_Capacity)
        luckyGenCo = allGenCos[rand(1:GenCoNumbers)]
        push!(luckyGenCo.technologyPortfolio.technologies, initial_Capacity[n])
        push!(allGenerators, initial_Capacity[n])
    end


    #push!(systemHistory.systemCapacityMix, deepcopy(allGenerators))
    println("Generator numbers: ", length(allGenerators))

    println("OwnerShips: ", length(allOwnerShips))

    ##########################################################################################################
    #Initialize consumers
    #priceCap = 200.0 #€/MWh
    #averageLoad = 10000 #MWh
    systemLoad = Load(priceCap,0.0,representativeData[:Load])

    systemState = SystemState(1,allGenerators)
    ##########################################################################################################
    #Initialize market operators
    MO = MarketOperator("MarketOperator")

    ##########################################################################################################
    #Initialize powerflows
    allPowerFlows = Array{PowerFlow,1}(undef,0)
    for generator in allGenerators
        #if typeof(generator) != VirtualPlants
        thisPowerFlow = PowerFlow(generator, MO, 0,0)
        push!(allPowerFlows, thisPowerFlow)
        #end
    end

    return MO,allGenCos,systemLoad,allPowerFlows,technologyPool,systemState,systemHistory
end
