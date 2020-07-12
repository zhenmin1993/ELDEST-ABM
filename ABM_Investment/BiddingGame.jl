#include("Init.jl")
include("Agents/AbstractTypes/AbstractType.jl")
import PyPlot
using Statistics
using Random


mutable struct Bid <: Container
    bidPrice::Array{Float64,1}
    bidQuantity::Array{Float64,1}
    bidCondition::Symbol #Accepted, unaccepted
    expectedProfit::Float64
    expectedProfit_Type::Array{Float64,1}
    attempt::Int64
    lastProfit::Float64

    Update::Function

    function Bid(bidPrice::Array{Float64,1},unitCapacity::Float64)
        self = new()
        self.bidPrice = bidPrice
        self.bidQuantity = unitCapacity .* ones(length(self.bidPrice))
        self.expectedProfit = 0.0
        self.expectedProfit_Type = zeros(length(self.bidPrice))
        self.attempt = 0
        self.lastProfit = 0.0

        self.Update = function(typeProfit::Array{Float64,1},learningRate::Float64)
            newProfit = sum(typeProfit)
            self.lastProfit = sum(typeProfit)
            self.expectedProfit_Type = self.expectedProfit_Type .* (1-learningRate) .+ typeProfit .* learningRate
            self.expectedProfit = self.expectedProfit * (1-learningRate) + newProfit * learningRate
        end

        return self
    end
end

mutable struct TestTechnology <: Technology
    type::Symbol
    marginalCost::Float64
    commitment::Bool
    offerPrice::Float64
    offerQuantity::Float64
    acceptedQuantity::Float64
    owner::ActiveAgent

    function TestTechnology(type::Symbol,marginalCost::Float64)
        self = new()
        self.type = type
        self.marginalCost = marginalCost
        self.commitment = true
        self.offerPrice = 0.0
        self.offerQuantity = 0.0
        self.acceptedQuantity = 0.0

        return self
    end
end

mutable struct TestGenCo <: ActiveAgent
    name::String
    bidSpace::Array{Bid,1}
    commitment::Array{Bool,1}
    technologies::Array{Technology,1}
    baseBid::Bid
    lastBid::Bid


    Learn::Function
    SelectBid::Function
    SubmitBid::Function

    function TestGenCo(technologies::Array{TestTechnology,1},testGenCoName::String)
        self = new()
        self.name = testGenCoName
        self.technologies = technologies
        self.bidSpace = Array{Bid,1}(undef,0)
        self.commitment = [technology.commitment for technology in technologies]
        baseBidPrice = zeros(length(self.technologies))
        for techCount in 1:length(self.technologies)
            baseBidPrice[techCount] = self.technologies[techCount].marginalCost
        end
        self.baseBid = Bid(baseBidPrice,800.0)

        allMarkupLevel = collect(Iterators.product(ntuple(i-> 0:2:10, length(self.technologies))...))[:]
        for markupLevel in allMarkupLevel
            newBidPrice = deepcopy(baseBidPrice)
            [newBidPrice[i] = newBidPrice[i] *( markupLevel[i] *0.1 + 1) for i = 1:length(self.technologies)]
            #newBidPrice = newBidPrice .* (1 .+ newBidPrice*0.1)
            newBid = Bid(newBidPrice,800.0)
            push!(self.bidSpace,newBid)
        end

        self.Learn = function(newPrice::Float64,learningRate::Float64)
            unitProfit = (newPrice .- self.baseBid.bidPrice) #.* Int.(self.commitment)
            acceptedQuantity = [technology.acceptedQuantity for technology in self.technologies]
            #unitProfit = max.(newPrice .- self.baseBid.bidPrice,0)
            #println(unitProfit)
            #newProfit = sum(unitProfit .* acceptedQuantity)
            typeProfit = unitProfit .* acceptedQuantity
            self.lastBid.Update(typeProfit,learningRate)
            sort!(self.bidSpace, by = x -> x.expectedProfit,rev = true)
            [technology.acceptedQuantity = 0.0 for technology in self.technologies]
            #return newProfit
        end

        self.SelectBid = function(explorationRate::Float64)
            randomNumber = rand(1)[1]
            bidSelect = self.bidSpace[1]
            if randomNumber < explorationRate
                bidSelect = self.bidSpace[rand(2:length(self.bidSpace))]
            end
            bidSelect.attempt += 1
            return bidSelect
        end

        self.SubmitBid = function(bid::Bid)
            for techCount in 1:length(self.technologies)
                self.technologies[techCount].offerPrice = bid.bidPrice[techCount]
                self.technologies[techCount].offerQuantity = bid.bidQuantity[techCount]
            end
            self.lastBid = bid
        end

        return self
    end
end



#MO,allGenCos,systemLoad,allPowerFlows,technologyPool,systemState,systemHistory = InitSystem(systemSettings,genCoHorizon)


#testGenCo3 = TestGenCo(deepcopy([baseTech,midTech,peakTech,peakTech]))

function ClearMarket(allTechnologies::Array{TestTechnology,1}, load::Float64)
    onlineTechnologies = allTechnologies
    #NOTE:start clear the market
    marketPrice = 0
    if length(onlineTechnologies) == 0
        println("No Technology!")
        marketPrice = 3000
    end

    if length(onlineTechnologies) > 0
        sort!(onlineTechnologies, by = x -> x.offerPrice)
        generatorCount = 1 #initialize generator number
         #this is a variable indicating the energy gap of one consumer when switching generators
        maxLoad = deepcopy(load)
        residualTechnology = 0

        while generatorCount <= length(onlineTechnologies)
            thisQuantity = onlineTechnologies[generatorCount].offerQuantity
            maxLoad += - thisQuantity
            #onlineTechnologies[generatorCount].commitment = true
            onlineTechnologies[generatorCount].acceptedQuantity = thisQuantity
            if maxLoad <= 0
                residualTechnology = -maxLoad
                marketPrice = onlineTechnologies[generatorCount].offerPrice
                onlineTechnologies[generatorCount].acceptedQuantity += maxLoad
                break
            end
            generatorCount += 1
        end
        #println(maxLoad)
        #println("Generator count ", generatorCount)
        if maxLoad > 0
            marketPrice = 3000
            residualTechnology = 0
        end
    end
    return marketPrice,onlineTechnologies[generatorCount].type,marketPrice/onlineTechnologies[generatorCount].marginalCost
end

function PlotTrade(allTestGenCos::Array{TestGenCo,1},load::Float64)
    allTechnologies = Array{TestTechnology,1}(undef,0)
    for testGenCo in allTestGenCos
        for technology in testGenCo.technologies
            push!(allTechnologies,deepcopy(technology))
        end
    end
    sort!(allTechnologies, by = x -> x.offerPrice)
    [println(technology.offerPrice) for technology in allTechnologies]
    allGenCoNames = [string(technology.owner.name) for technology in allTechnologies]
    println(allGenCoNames)
    allOfferPrice = [technology.offerPrice for technology in allTechnologies]
    allMarginalCost = [technology.marginalCost for technology in allTechnologies]
    allMarkupLevel = [technology.offerPrice/technology.marginalCost for technology in allTechnologies]
    allOfferQuantity = [technology.offerQuantity for technology in allTechnologies]
    allOfferQuantity_Cum = cumsum(allOfferQuantity)
    pushfirst!(allOfferQuantity_Cum,0.0)
    pushfirst!(allOfferPrice,allOfferPrice[1])
    pushfirst!(allMarginalCost,allMarginalCost[1])

    println(allOfferPrice)
    println(allMarginalCost)

    allTechNames = [string(technology.type,"(",round((technology.offerPrice/technology.marginalCost-1),digits = 1)*100,"%)") for technology in allTechnologies]
    println(allTechNames)
    PyPlot.step(allOfferQuantity_Cum, allOfferPrice, linestyle="-",label = "Bid")
    PyPlot.step(allOfferQuantity_Cum, allMarginalCost, linestyle=":",label = "Marginal cost")
    PyPlot.plot(load .* ones(100), collect(1:100),label = "Load")
    for txt_tech in zip(allOfferQuantity_Cum[1:end-1],allOfferQuantity_Cum[2:end], allOfferPrice[2:end], allTechNames)
        PyPlot.text(x=(txt_tech[1]+txt_tech[2])/2, y=txt_tech[3]+1, s=txt_tech[4])
    end

    for txt_tech in zip(allOfferQuantity_Cum[1:end-1],allOfferQuantity_Cum[2:end], allOfferPrice[2:end], allGenCoNames)
        PyPlot.text(x=(txt_tech[1]+txt_tech[2])/2, y=txt_tech[3]+5, s=txt_tech[4])
    end

    PyPlot.xlim([0,sum(allOfferQuantity)])
    PyPlot.xlabel("Load [MW]",fontsize=16)
    PyPlot.ylabel("Price [€/MWh]",fontsize=16)
    PyPlot.xticks(fontsize=16)
    PyPlot.yticks(fontsize=16)
    PyPlot.legend(fontsize = 16)
    PyPlot.grid(true)
end


function RunBidding(allTestGenCos::Array{TestGenCo,1},totalEpisode::Int64,load::Float64)
    profitHistory = zeros(length(allTestGenCos),totalEpisode)
    marginalMarkupHistory = zeros(length(allTestGenCos),totalEpisode)
    marketPriceHistory = zeros(totalEpisode)
    for episode in 1:totalEpisode
        progressIndex = 1-episode/totalEpisode
        explorationRate = progressIndex^(1/20)
        exploitationRate = 1-explorationRate
        allTechnologies = Array{TestTechnology,1}(undef,0)
        for testGenCo in allTestGenCos
            testGenCo.SubmitBid(testGenCo.SelectBid(explorationRate))
            append!(allTechnologies,testGenCo.technologies)
        end

        shuffle!(allTechnologies)
        #if changeSequence[episode] == true
        #    reverse!(allTechnologies)
        #end
        #=
        randomNumber = rand(1)[1]
        if randomNumber > 0.5
            reverse!(allTechnologies)
        end
        =#


        #testGenCo3.SubmitBid(testGenCo3.SelectBid(explorationRate))
        #allTechnologies = vcat(testGenCo1.technologies,testGenCo2.technologies)
        #allTechnologies = testGenCo1.technologies
        marketPrice,marginalGenerator,markup = ClearMarket(allTechnologies, load)

        marketPriceHistory[episode] = marketPrice
        #println(marketPrice)

        for genCoCount in 1:length(allTestGenCos)
            marginalMarkupHistory[genCoCount,episode] = allTestGenCos[genCoCount].bidSpace[1].bidPrice[end]/allTestGenCos[genCoCount].baseBid.bidPrice[end]
            allTestGenCos[genCoCount].Learn(marketPrice,0.1)
            profitHistory[genCoCount,episode] = allTestGenCos[genCoCount].bidSpace[1].expectedProfit
        end
        #testGenCo3.Learn(marketPrice,0.05)

        #profitHistory_3[episode] = testGenCo3.bidSpace[1].expectedProfit
    end
    optimalGenCos = deepcopy(allTestGenCos)
    allTechnologies_optimal = Array{TestTechnology,1}(undef,0)
    for testGenCo in optimalGenCos
        testGenCo.SubmitBid(testGenCo.bidSpace[1])
        append!(allTechnologies_optimal,testGenCo.technologies)
    end
    optimalMarketPrice,marginalGenerator,markup = ClearMarket(allTechnologies_optimal, load)
    return optimalMarketPrice,marginalGenerator,markup,profitHistory,marginalMarkupHistory,marketPriceHistory
end

#baseTech = TestTechnology(:Base, 12.5)
#midTech = TestTechnology(:Mid,21.5)
#peakTech = TestTechnology(:Peak,45.67)

baseTech = TestTechnology(:Base, 10.0)
midTech = TestTechnology(:Mid,30.0)
peakTech = TestTechnology(:Peak,70.0)
testTechnologyPool = [baseTech,midTech,peakTech]





testGenCo1 = TestGenCo(deepcopy([baseTech,midTech,peakTech]),"GenCo1")
testGenCo2 = TestGenCo(deepcopy([baseTech,midTech,peakTech]),"GenCo2")
testGenCo3 = TestGenCo(deepcopy([baseTech,midTech,peakTech]),"GenCo3")
testGenCo4 = TestGenCo(deepcopy([baseTech,midTech,peakTech]),"GenCo4")
testGenCo5 = TestGenCo(deepcopy([baseTech,midTech,peakTech]),"GenCo5")
#allTestGenCos = [testGenCo1,testGenCo2,testGenCo3,testGenCo4,testGenCo5]
allTestGenCos = [testGenCo1,testGenCo2,testGenCo3]
for testGenCo in allTestGenCos
    for technology in testGenCo.technologies
        technology.owner = testGenCo
    end
end
totalInstalledCapacity = length(allTestGenCos) * 3 * 800.0
loadList = collect(100.0:200.0:(totalInstalledCapacity-100))

newAllTestGenCos = deepcopy(allTestGenCos)




totalEpisode = 100000
simulationTimes = 20

optimalMarketPriceList = Array{Real,1}(undef,0)
marginalGeneratorList = Array{Symbol,1}(undef,0)


profitHistory_all = zeros(length(allTestGenCos),totalEpisode*simulationTimes)
marginalMarkupHistory_all = zeros(length(allTestGenCos),totalEpisode*simulationTimes)
marketPriceHistory_all = zeros(totalEpisode*simulationTimes)
averageMarkupHistory_all = Array{Float64,1}(undef,0)
allTestGenCos_history = Array{Array{TestGenCo,1},1}(undef,0)

for load in loadList
    println(load)
    allTestGenCos = deepcopy(newAllTestGenCos)
    markupList = Array{Float64,1}(undef,0)
    randomSeedList = rand(1:1000,simulationTimes)
    for randomSeedCount in 1:length(randomSeedList)
        Random.seed!(randomSeedList[randomSeedCount])
        println(randomSeedCount)
        optimalMarketPrice,marginalGenerator,markup,profitHistory,marginalMarkupHistory,marketPriceHistory = RunBidding(allTestGenCos,totalEpisode,load)
        thisStart = (randomSeedCount-1)*totalEpisode+1
        thisStop = randomSeedCount * totalEpisode
        profitHistory_all[:,thisStart:thisStop] = profitHistory
        marginalMarkupHistory_all[:,thisStart:thisStop] = marginalMarkupHistory
        marketPriceHistory_all[thisStart:thisStop] = marketPriceHistory
        push!(optimalMarketPriceList,optimalMarketPrice)
        push!(marginalGeneratorList,marginalGenerator)
        push!(markupList,markup)
    end
    push!(allTestGenCos_history,allTestGenCos)
    averageMarkup = Statistics.mean(markupList.-1)
    push!(averageMarkupHistory_all,averageMarkup)
end

PyPlot.figure(6)
PyPlot.plot(averageMarkupHistory_all.*100,marker = "o",label = "markup percentage")

PyPlot.xticks(collect(0:(length(averageMarkupHistory_all)-1)),loadList,rotation = 80)
PyPlot.title("Markup percentage vs load level")
PyPlot.xlabel("Load (MW)",fontsize=16)
PyPlot.ylabel("Markup percentage [%]",fontsize=16)

PyPlot.yticks(fontsize=16)
PyPlot.grid(true)
loadDivisionList = (loadList.+100) .% 800.0 .== 0
for loadDivision in collect(1:length(averageMarkupHistory_all))[loadDivisionList]
    PyPlot.plot((loadDivision-0.5) * ones(100),collect(0:99))
end

allTechnologies_plot = Array{TestTechnology,1}(undef,0)
for testGenCo in allTestGenCos
    append!(allTechnologies_plot,testGenCo.technologies)
end
sort!(allTechnologies_plot, by = x -> x.marginalCost)
#allMarginalCost = [technology.marginalCost for technology in allTechnologies_plot]
allTechNames = [string(technology.type) for technology in allTechnologies_plot]
for txt_tech in zip(collect(1:length(averageMarkupHistory_all))[loadDivisionList], allTechNames)
    PyPlot.text(x=txt_tech[1]-4, y=5, s=txt_tech[2])
    PyPlot.text(x=txt_tech[1]-4, y=3, s="(800 MW)")
end
PyPlot.legend(loc = 2)

PyPlot.twinx()
averageElectricityPrice = zeros(length(averageMarkupHistory_all))
for markupCount in 1:length(averageMarkupHistory_all)
    if loadList[markupCount] <= length(allTestGenCos) * 800
        averageElectricityPrice[markupCount] = (averageMarkupHistory_all[markupCount] +1) * baseTech.marginalCost
    elseif loadList[markupCount] <= length(allTestGenCos) * 2 * 800
        averageElectricityPrice[markupCount] = (averageMarkupHistory_all[markupCount] +1) * midTech.marginalCost
    else
        averageElectricityPrice[markupCount] = (averageMarkupHistory_all[markupCount] +1) * peakTech.marginalCost
    end
end
PyPlot.plot(averageElectricityPrice,marker = ".",label = "electricity price [€/MWh]",color = "green")
PyPlot.ylabel("Electricity price",fontsize=16,color = "green")
PyPlot.legend(loc = 1)
#PyPlot.xticks(collect(0:(length(averageMarkupHistory_all)-1)),loadList,rotation = 80)
#=
expectedProfit_Type = zeros(3,length(loadList))
expectedProfit_std = zeros(3,length(loadList))
for allTestGenCosCount in 1:length(allTestGenCos_history)
    thisExpect = zeros(3)
    tempStd = Array{Float64,2}(undef,3,0)
    for testGenCo in allTestGenCos_history[allTestGenCosCount]
        thisExpect = thisExpect + testGenCo.bidSpace[1].expectedProfit_Type
        tempStd = hcat(tempStd,thisExpect)

    end
    println(tempStd)
    for i in 1:3
        expectedProfit_std[i,allTestGenCosCount] = Statistics.std(tempStd[i,:])
    end

    thisExpect = thisExpect ./ length(allTestGenCos)# ./ sum(thisExpect) * 50
    expectedProfit_Type[:,allTestGenCosCount] = thisExpect
end

PyPlot.bar(collect(0:length(loadList)-1),expectedProfit_Type[1,:],0.5,alpha = 0.5,label = "Base")
PyPlot.bar(collect(0:length(loadList)-1),expectedProfit_Type[2,:],0.5,bottom = expectedProfit_Type[1,:],alpha = 0.5,label = "Mid")
PyPlot.bar(collect(0:length(loadList)-1),expectedProfit_Type[3,:],0.5,bottom = expectedProfit_Type[1,:] + expectedProfit_Type[2,:],alpha = 0.5,label = "Peak")
PyPlot.legend()
=#


#=


PyPlot.figure(5)
explorationRateHistory = (1 .- collect(1:totalEpisode)./totalEpisode).^(1/20)
PyPlot.plot(explorationRateHistory)
PyPlot.xlabel("Episode",fontsize=16)
PyPlot.ylabel("Exploration rate",fontsize=16)
PyPlot.xticks(fontsize=16)
PyPlot.yticks(fontsize=16)
#PyPlot.legend(fontsize = 16)
PyPlot.grid(true)


PyPlot.figure(1)
for genCoCount in 1:length(allTestGenCos)
    PyPlot.plot(1:(totalEpisode*simulationTimes),profitHistory_all[genCoCount,:],label = allTestGenCos[genCoCount].name)
    PyPlot.xlabel("Episode",fontsize=16)
    PyPlot.ylabel("Maximum expected profit [€]",fontsize=16)
    PyPlot.xticks(fontsize=16)
    PyPlot.yticks(fontsize=16)
    PyPlot.legend(fontsize = 16)
    PyPlot.title("Max. expected profit vs. simulation")
    PyPlot.grid(true)
end

PyPlot.twinx()
explorationRateHistory = (1 .- collect(1:totalEpisode)./totalEpisode).^(1/20)
PyPlot.plot(repeat(explorationRateHistory,simulationTimes),color = "red")
PyPlot.ylim([0,2])
PyPlot.ylabel("Exploration rate",color = "red")
#PyPlot.plot(1:length(profitHistory_2),profitHistory_3,label = "GenCo3")

PyPlot.figure(2)
for genCoCount in 1:length(allTestGenCos)
    PyPlot.plot(1:(totalEpisode*simulationTimes),marginalMarkupHistory_all[genCoCount,:],label = allTestGenCos[genCoCount].name)
    PyPlot.xlabel("Episode",fontsize=16)
    PyPlot.ylabel("Markup",fontsize=16)
    PyPlot.xticks(fontsize=16)
    PyPlot.yticks(fontsize=16)
    PyPlot.title("Markup percentage of the peak tech. in the optimal bid")
    PyPlot.legend(fontsize = 16)
    PyPlot.grid(true)
end

PyPlot.twinx()
explorationRateHistory = (1 .- collect(1:totalEpisode)./totalEpisode).^(1/20)
PyPlot.plot(repeat(explorationRateHistory,simulationTimes),color = "red")
PyPlot.ylim([0,2])
PyPlot.ylabel("Exploration rate",color = "red")

PyPlot.figure(3)
PyPlot.plot((markupList.-1) .* 100)
PyPlot.xticks(collect(0:(simulationTimes-1)),string.(marginalGeneratorList))
PyPlot.title("Markup percentage of the marginal generator")
PyPlot.xlabel("Marginal technology type",fontsize=16)
PyPlot.ylabel("Markup percentage",fontsize=16)
PyPlot.xticks(fontsize=16)
PyPlot.yticks(fontsize=16)

PyPlot.grid(true)

PyPlot.figure(4)
plotGenCos = deepcopy(allTestGenCos)
for testGenCo in plotGenCos
    testGenCo.SubmitBid(testGenCo.bidSpace[1])
end
PlotTrade(plotGenCos,loadList[1])
=#
