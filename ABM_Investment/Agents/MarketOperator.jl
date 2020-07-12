include("Load.jl")
include("Technology.jl")

mutable struct MarketOperator <: PassiveAgent
    name::String

    Match::Function # Match technology with power flow
    ClearMarket::Function # Market clearing
    Payment::Function

    function MarketOperator(name::String)
        self = new()
        self.name = name

        self.Match = function(technology::Technology, allPowerFlows::Vector{PowerFlow})
            for powerFlow in allPowerFlows
                if powerFlow.from == technology
                    return powerFlow
                end
            end
        end

        self.ClearMarket = function(allTechnologies::Array{Technology,1}, allPowerFlows::Array{PowerFlow,1}, systemLoad::Load)
            onlineTechnologies = allTechnologies
            #NOTE:start clear the market
            marketPrice = 0
            if length(onlineTechnologies) == 0
                println("No Technology!")
                marketPrice = systemLoad.priceCap
            end

            if length(onlineTechnologies) > 0
                sort!(onlineTechnologies, by = x -> x.offerPrice)
                generatorCount = 1 #initialize generator number
                 #this is a variable indicating the energy gap of one consumer when switching generators
                maxLoad = deepcopy(systemLoad.hourlyLoad)
                residualTechnology = 0

                while generatorCount <= length(onlineTechnologies)
                    thisQuantity = onlineTechnologies[generatorCount].offerQuantity
                    maxLoad += - thisQuantity
                    if maxLoad <= 0
                        residualTechnology = -maxLoad
                        marketPrice = onlineTechnologies[generatorCount].offerPrice
                        break
                    end
                    generatorCount += 1
                end
                #println(maxLoad)
                #println("Generator count ", generatorCount)
                if maxLoad > 0
                    marketPrice = systemLoad.priceCap
                    residualTechnology = 0
                end

                for thisCount in 1:length(onlineTechnologies)
                    if thisCount < generatorCount
                        thisPowerFlow = self.Match(onlineTechnologies[thisCount], allPowerFlows)
                        if typeof(thisPowerFlow)==Nothing
                            println(onlineTechnologies[thisCount].type)
                            println(generatorCount)
                        end
                        thisPowerFlow.quantity = onlineTechnologies[thisCount].offerQuantity
                        thisPowerFlow.marketPrice = marketPrice
                    end

                    if thisCount == generatorCount
                        thisPowerFlow = self.Match(onlineTechnologies[thisCount], allPowerFlows)
                        thisPowerFlow.quantity = onlineTechnologies[thisCount].offerQuantity - residualTechnology
                        thisPowerFlow.marketPrice = marketPrice
                    end

                    if thisCount > generatorCount
                        thisPowerFlow = self.Match(onlineTechnologies[thisCount], allPowerFlows)
                        thisPowerFlow.quantity = 0.0
                        thisPowerFlow.marketPrice = marketPrice
                    end
                end
            end
            #println("price:",marketPrice)
            return marketPrice
        end

        self.Payment = function(allPowerFlows::Vector{PowerFlow}, day::Int64,hour::Int64,auctionIdentify::Symbol, systemSettings::SystemSettings)
            for powerFlow in allPowerFlows
                thisTechnology = powerFlow.from
                subsidyAmount = 0.0
                #NOTE: in the case of different auction process, update different histories
                if auctionIdentify == :virtual
                    thisTechnology.UpdateHistory!(auctionIdentify, thisTechnology.economicProperties.virtualHistory,powerFlow, hour,day,subsidyAmount,systemSettings)
                    #println("Yearly: ", size(thisTechnology.economicProperties.virtualHistory.yearlyHistory))
                end
                if auctionIdentify == :real
                    thisTechnology.UpdateHistory!(auctionIdentify,thisTechnology.economicProperties.realHistory,powerFlow, hour,day,subsidyAmount,systemSettings)
                end
            end
        end
        return self
    end
end
