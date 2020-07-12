include("AbstractTypes/AbstractType.jl")


mutable struct TechnologyHistory <: Buffer
    cashFlow::Array{Real,1} # 7 columns: Revenue, subsidy,VOM, fuelCost, emissionCost ,FOM, CAPEX, NPV
    dispatchHistory::Array{Real,1} # 3 columns: profitableHours,marginalHours,unprofitableHours
    hourlyHistory::Array{Real,2} # 4 columns:  Revenue, VOM, fuelCost, emissionCost
    dailyHistory::Array{Real,2} # 4 columns:  Revenue, VOM, fuelCost, emissionCost
    yearlyHistory::Array{Real,2} # 6 columns:  Revenue, VOM, fuelCost, emissionCost, FOM, CAPEX

    day2hour::Int64
    year2day::Int64

    Reinitialize!::Function # Reinitialize the history after prefiltering

    function TechnologyHistory(systemSettings::SystemSettings)
        self = new()
        self.cashFlow = zeros(8)
        self.dispatchHistory = zeros(3)
        self.day2hour = systemSettings.simulationSettings.day2hour
        self.year2day = systemSettings.simulationSettings.year2day
        self.hourlyHistory = zeros(self.day2hour,5)
        self.dailyHistory = zeros(self.year2day,5)
        self.yearlyHistory = Array{Real,2}(undef,0,7)

        self.Reinitialize! = function()
            self.cashFlow = zeros(8)
            self.dispatchHistory = zeros(3)
            self.hourlyHistory = zeros(self.day2hour,5)
            self.dailyHistory = zeros(self.year2day,5)
            self.yearlyHistory = Array{Real,2}(undef,0,7)
        end
        return self
    end
end



mutable struct DesignProperty <: Property
    availability::Real # range 0.0 - 1.0
    constructionTimeStamp::Real # The year that the plant is built
    constructionTime::Real # lead time
    deconstructionTime::Real # required time to dismantle
    efficiency::Real # Fuel -> electricity, range 0.0 - 1.0
    emissionLevel::Real #ton/MWh
    lifeTime::Real # life expectance of the plant
    installedUnitNumber::Real # The installed unit number of this plant
    unitCapacity::Real # capacity of each unit

    installedCapacity::Real # This is not direct input, calculated use its internal function
    maximumOutPut::Real

    CalculateInstalledCapacity::Function

    function DesignProperty(availability::Real, constructionTimeStamp::Real, constructionTime::Real, deconstructionTime::Real, efficiency::Real, emissionLevel::Real,lifeTime::Real, unitCapacity::Real)
        self = new()
        self.availability = availability
        self.constructionTimeStamp = constructionTimeStamp
        self.constructionTime = constructionTime
        self.deconstructionTime = deconstructionTime
        self.efficiency = efficiency
        self.emissionLevel = emissionLevel
        self.lifeTime = lifeTime
        self.unitCapacity = unitCapacity

        self.CalculateInstalledCapacity =function(unitNumber::Real)
            self.installedUnitNumber = unitNumber
            self.installedCapacity = self.installedUnitNumber * self.unitCapacity
            self.maximumOutPut = self.installedUnitNumber * self.unitCapacity
        end


        return self
    end
end

mutable struct EconomicProperty <: Property
    #Cost of each unit
    unitConstructionCost::Real #€/unit
    unitDeconstructionCost::Real #€/unit
    unitVOMCost::Real #€/MWh
    unitFOMCost::Real #€/unit/year

    domesticLearningRate::Real
    nonDomesticLearningRate::Real

    #Cost of the plant (which is composed of several plants)
    constructionCost::Real #€
    deconstructionCost::Real #€
    VOMCost::Real  #€/MWh
    fuelCost::Real #€/MWh
    emissionCost::Real #€/MWh
    FOMCost::Real #€/year
    yearlyInstallment::Float64  #€/year
    virtualHistory::TechnologyHistory # Store information during virtual auction
    realHistory::TechnologyHistory # Store information during real auction

    CalculatePlantParameter::Function


    function EconomicProperty(unitConstructionCost::Real,unitDeconstructionCost::Real, unitVOMCost::Real,unitFOMCost::Real,systemSettings::SystemSettings)
        self = new()
        self.unitConstructionCost = unitConstructionCost
        self.unitDeconstructionCost = unitDeconstructionCost
        self.unitVOMCost = unitVOMCost
        self.unitFOMCost = unitFOMCost
        self.virtualHistory = TechnologyHistory(systemSettings)
        self.realHistory = TechnologyHistory(systemSettings)


        #Calculate plant parameters if there are more than 1 unit
        self.CalculatePlantParameter = function(unitNumber::Real)
            self.constructionCost = self.unitConstructionCost * unitNumber
            self.deconstructionCost = self.unitDeconstructionCost * unitNumber
            self.VOMCost = self.unitVOMCost
            self.FOMCost = self.unitFOMCost * unitNumber
        end

        return self
    end
end


mutable struct ConventionalPlants <: Technology
    name::Symbol
    type::Symbol
    designProperties::DesignProperty
    economicProperties::EconomicProperty
    offerPrice::Float64 # €/MWh
    offerQuantity::Float64 # MWh
    state::Array{Symbol,1} # state1: online/offline; state2: subsidized/unsubsidized


    ChangeState::Function
    UpdateCost::Function
    MultipleUnits::Function
    CalculateYearlyInstallment::Function
    UpdateHistory!::Function
    AggregateHistory!::Function


    function ConventionalPlants(type::Symbol, designProperties::DesignProperty,economicProperties::EconomicProperty,systemSettings::SystemSettings)
        self = new()
        self.type = type
        self.designProperties = designProperties
        self.economicProperties = economicProperties

        self.UpdateCost = function(newEmissionPrice::Real,newFuelPrice::Real)
            self.economicProperties.emissionCost = newEmissionPrice * self.designProperties.emissionLevel
            self.economicProperties.fuelCost = newFuelPrice / self.designProperties.efficiency
            self.offerPrice = self.economicProperties.unitVOMCost + self.economicProperties.fuelCost
        end

        # NOTE: source: https://en.wikipedia.org/wiki/Mortgage_calculator
        self.CalculateYearlyInstallment = function(systemSettings::SystemSettings)
            interestRate = systemSettings.interestRate
            capital = self.economicProperties.constructionCost *(1-systemSettings.simulationSettings.downpaymentRatio)
            if interestRate > 0.0
                payBackPeriod = self.designProperties.lifeTime
                self.economicProperties.yearlyInstallment = (interestRate*(1 + interestRate) ^ payBackPeriod) / ((1 + interestRate) ^ payBackPeriod - 1) * capital
            end
            # When interest rate is 0, the formula is not valid
            if interestRate == 0.0
                self.economicProperties.yearlyInstallment = capital/self.designProperties.lifeTime
            end
        end

        # NOTE: some necessary initilization of this plant
        self.MultipleUnits = function(unitNumber::Real,systemSettings::SystemSettings)
            self.designProperties.CalculateInstalledCapacity(unitNumber)
            self.economicProperties.CalculatePlantParameter(unitNumber)
            self.offerPrice = self.economicProperties.VOMCost + self.economicProperties.fuelCost
            self.offerQuantity = self.designProperties.maximumOutPut
            self.CalculateYearlyInstallment(systemSettings)
        end

        # NOTE: Record the evaluation history or real life auction history
        self.UpdateHistory! = function(auctionIdentify::Symbol,history::TechnologyHistory,powerFlow::PowerFlow, hour::Int64,day::Int64,subsidyAmount::Real,systemSettings::SystemSettings)
            if auctionIdentify == :real
                repeatTime = 1
            end

            if auctionIdentify == :virtual
                repeatTime = systemSettings.milestoneYear
            end
            marketPrice = powerFlow.marketPrice
            quantity = powerFlow.quantity

            representativeDayWeightFactors = systemSettings.simulationSettings.representativeData[:Weights]
            year2day = systemSettings.simulationSettings.year2day
            day2hour = systemSettings.simulationSettings.day2hour

            #NOTE: update Revenue, VOM, FOM, CAPEX
            thisRevenue = marketPrice * quantity
            thisSubsidy = subsidyAmount * quantity
            thisVOM = self.economicProperties.unitVOMCost * quantity
            thisFuelCost = self.economicProperties.fuelCost * quantity
            thisEmissionCost = self.economicProperties.emissionCost * quantity


            history.hourlyHistory[hour,1] = thisRevenue
            history.hourlyHistory[hour,2] = thisSubsidy
            history.hourlyHistory[hour,3] = thisVOM
            history.hourlyHistory[hour,4] = thisFuelCost
            history.hourlyHistory[hour,5] = thisEmissionCost

            if hour == day2hour
                history.dailyHistory[day,:] = sum(history.hourlyHistory,dims=1) .* representativeDayWeightFactors[day,2]
                history.hourlyHistory = zeros(day2hour,5)
            end

            if day == year2day && hour == day2hour #End of a year
                thisYearlyRevenue = sum(history.dailyHistory[:,1])
                thisYearlySubsidy = sum(history.dailyHistory[:,2])
                thisYearlyVOM = sum(history.dailyHistory[:,3])
                thisYearlyFuelCost = sum(history.dailyHistory[:,4])
                thisYearlyEmissionCost = sum(history.dailyHistory[:,5])
                thisYearlyFOM = self.economicProperties.FOMCost
                thisYearlyHistory = repeat([thisYearlyRevenue thisYearlySubsidy thisYearlyVOM thisYearlyFuelCost thisYearlyEmissionCost thisYearlyFOM self.economicProperties.yearlyInstallment], repeatTime)
                #println("one year",size(thisYearlyHistory))
                #println(day," ",hour)
                history.yearlyHistory = vcat(history.yearlyHistory, thisYearlyHistory)
                history.dailyHistory = zeros(year2day,5)
                #println("Yearly: ", size(history.yearlyHistory))
            end


            #NOTE:update dispatch history
            if marketPrice > self.offerPrice
                history.dispatchHistory[1] += representativeDayWeightFactors[day,2] * repeatTime
            end
            if marketPrice == self.offerPrice
                history.dispatchHistory[2] += representativeDayWeightFactors[day,2] * repeatTime
            end
            if marketPrice < self.offerPrice
                history.dispatchHistory[3] += representativeDayWeightFactors[day,2] * repeatTime
            end
        end

        #NOTE: calculate total 1-> Revenue, 2-> VOM, 3-> FOM, 4-> CAPEX, 5-> NPV
        self.AggregateHistory! = function(history::TechnologyHistory,systemSettings::SystemSettings)
            interestRate = systemSettings.interestRate
            cashFlowHorizon = size(history.yearlyHistory)[1]
            if cashFlowHorizon>=1
                yearVector = collect(0:1:(cashFlowHorizon-1))
                lifeDiscountVector = exp.(-interestRate .* yearVector)
                history.cashFlow[1:7] = lifeDiscountVector' * history.yearlyHistory
                history.cashFlow[8] = sum(history.cashFlow[1:2]) - sum(history.cashFlow[3:7]) - self.economicProperties.constructionCost * systemSettings.simulationSettings.downpaymentRatio
            end
        end
        return self
    end
end

mutable struct RenewablePlants <:Technology
    name::Symbol
    type::Symbol #:OnShoreWind,:OffShoreWind,:Solar
    designProperties::DesignProperty
    economicProperties::EconomicProperty
    offerPrice::Float64
    offerQuantity::Float64
    capacityFactors::Matrix{Float64}

    ChangeState::Function
    MultipleUnits::Function
    TimeSeries::Function
    CalculateYearlyInstallment::Function
    UpdateHistory!::Function
    AggregateHistory!::Function

    function RenewablePlants(type::Symbol,designProperties::DesignProperty,economicProperties::EconomicProperty,capacityFactorImproveRate::Float64,systemSettings::SystemSettings)
        self = new()
        self.type = type
        self.designProperties = designProperties
        self.economicProperties = economicProperties
        self.capacityFactorImproveRate = capacityFactorImproveRate
        self.capacityFactors = systemSettings.simulationSettings.representativeData[self.type]


        # NOTE: source: https://en.wikipedia.org/wiki/Mortgage_calculator
        self.CalculateYearlyInstallment = function(systemSettings::SystemSettings)
            interestRate = systemSettings.interestRate
            capital = self.economicProperties.constructionCost *(1-systemSettings.simulationSettings.downpaymentRatio)
            if interestRate > 0.0
                payBackPeriod = self.designProperties.lifeTime
                self.economicProperties.yearlyInstallment = (interestRate*(1 + interestRate) ^ payBackPeriod) / ((1 + interestRate) ^ payBackPeriod - 1) * capital
                #println(self.economicProperties.yearlyInstallment)
            end
            # When interest rate is 0, the formula is not valid
            if interestRate == 0.0
                self.economicProperties.yearlyInstallment = capital/self.designProperties.lifeTime
                #println(self.economicProperties.yearlyInstallment)
            end
        end

        # NOTE: some necessary initilization of this plant
        self.MultipleUnits = function(unitNumber::Real,systemSettings::SystemSettings)
            self.designProperties.CalculateInstalledCapacity(unitNumber)
            self.economicProperties.CalculatePlantParameter(unitNumber)
            self.offerPrice = self.economicProperties.VOMCost
            #self.offerQuantity = self.designProperties.installedCapacity
            self.CalculateYearlyInstallment(systemSettings)
        end

        self.TimeSeries = function(day::Int64,hour::Int64)
            self.offerQuantity = self.capacityFactors[day,hour] * self.designProperties.maximumOutPut
        end


        # NOTE: Record the evaluation history or real life auction history
        self.UpdateHistory! = function(auctionIdentify::Symbol, history::TechnologyHistory,powerFlow::PowerFlow, hour::Int64,day::Int64,subsidyAmount::Real,systemSettings::SystemSettings)
            if auctionIdentify == :real
                repeatTime = 1
            end

            if auctionIdentify == :virtual
                repeatTime = systemSettings.milestoneYear
            end
            marketPrice = powerFlow.marketPrice
            quantity = powerFlow.quantity

            representativeDayWeightFactors = systemSettings.simulationSettings.representativeData[:Weights]
            year2day = systemSettings.simulationSettings.year2day
            day2hour = systemSettings.simulationSettings.day2hour

            #NOTE: update Revenue, VOM, FOM, CAPEX
            thisRevenue = marketPrice * quantity
            thisSubsidy = subsidyAmount * quantity
            thisVOM = self.economicProperties.VOMCost * quantity
            thisFuelCost = 0
            thisEmissionCost = 0


            history.hourlyHistory[hour,1] = thisRevenue
            history.hourlyHistory[hour,2] = thisSubsidy
            history.hourlyHistory[hour,3] = thisVOM
            history.hourlyHistory[hour,4] = thisFuelCost
            history.hourlyHistory[hour,5] = thisEmissionCost

            if hour == day2hour
                history.dailyHistory[day,:] = sum(history.hourlyHistory,dims=1) * representativeDayWeightFactors[day,2]
                history.hourlyHistory = zeros(day2hour,5)
            end

            if day == year2day && hour == day2hour #End of a year
                thisYearlyRevenue = sum(history.dailyHistory[:,1])
                thisYearlySubsidy = sum(history.dailyHistory[:,2])
                thisYearlyVOM = sum(history.dailyHistory[:,3])
                thisYearlyFuelCost = sum(history.dailyHistory[:,4])
                thisYearlyEmissionCost = sum(history.dailyHistory[:,5])
                thisYearlyFOM = self.economicProperties.FOMCost
                thisYearlyHistory = repeat([thisYearlyRevenue thisYearlySubsidy thisYearlyVOM thisYearlyFuelCost thisYearlyEmissionCost thisYearlyFOM self.economicProperties.yearlyInstallment], repeatTime)
                #println("one year",size(thisYearlyHistory))
                #println(day," ",hour)
                history.yearlyHistory = vcat(history.yearlyHistory, thisYearlyHistory)
                history.dailyHistory = zeros(year2day,5)
                #println("Yearly: ", size(history.yearlyHistory))
            end


            #NOTE:update dispatch history
            if marketPrice > self.offerPrice
                history.dispatchHistory[1] += representativeDayWeightFactors[day,2] * repeatTime
            end
            if marketPrice == self.offerPrice
                history.dispatchHistory[2] += representativeDayWeightFactors[day,2] * repeatTime
            end
            if marketPrice < self.offerPrice
                history.dispatchHistory[3] += representativeDayWeightFactors[day,2] * repeatTime
            end
        end

        #NOTE: calculate total 1-> Revenue, 2-> VOM, 3-> FOM, 4-> CAPEX, 5-> NPV
        self.AggregateHistory! = function(history::TechnologyHistory,systemSettings::SystemSettings)
            interestRate = systemSettings.interestRate
            cashFlowHorizon = size(history.yearlyHistory)[1]
            if cashFlowHorizon>=1
                yearVector = collect(0:1:(cashFlowHorizon-1))
                lifeDiscountVector = exp.(-interestRate .* yearVector)
                history.cashFlow[1:7] = lifeDiscountVector' * history.yearlyHistory
                history.cashFlow[8] = sum(history.cashFlow[1:2]) - sum(history.cashFlow[3:7]) - self.economicProperties.constructionCost * systemSettings.simulationSettings.downpaymentRatio
            end
        end
        return self
    end
end
