
include("MarketOperator.jl")
include("System.jl")


mutable struct TechnologyPortfolio <: Container
    technologies::Array{Technology,1}
    Decomission::Function
    CheckAge::Function
    CheckProfitability::Function
    FindTechnologyDecomission::Function

    function TechnologyPortfolio(technologies::Array{Technology,1})
        self = new()
        self.technologies = technologies

        #Reach life expectancy?
        self.CheckAge = function(currentYear::Real, technology::Technology)
            retire = false
            if (technology.designProperties.constructionTimeStamp + technology.designProperties.lifeTime) <= currentYear
                retire = true
            end
            return retire
        end

        #Select the corresponding technologies that should be decomissioned
        self.FindTechnologyDecomission = function(currentYear::Real)
            technologyToDecomission = Array{Technology,1}(undef,0)
            for technology in self.technologies
                retire = self.CheckAge(currentYear,technology)
                #Retirement creteria is different in different processes
                if retire == true
                    push!(technologyToDecomission, technology)
                end
            end
            return technologyToDecomission
        end
        return self
    end
end

mutable struct GenCoHistory <: Buffer
    #The generation portfolio evolution history of a generation company
    technologyMixHistory::Array{TechnologyPortfolio,1}
    #The new investments of this generation companies in each year
    yearlyInvestment::Array{Technology,1}
    investmentHistory::Array{TechnologyPortfolio,1}
    investmentYearByType::Dict{Symbol,Array{Real,1}}
    allTechnologiesPossessed::Array{Technology,1}
    decomissionedTechnologies::Array{Technology,1}

    function GenCoHistory()
        self = new()
        self.technologyMixHistory = Array{TechnologyPortfolio,1}(undef,0)
        self.yearlyInvestment = Array{Technology,1}(undef,0)
        self.investmentHistory = Array{TechnologyPortfolio,1}(undef,0)
        self.investmentYearByType = Dict{Symbol,Array{Real,1}}()
        self.allTechnologiesPossessed = Array{Technology,1}(undef,0)
        self.decomissionedTechnologies = Array{Technology,1}(undef,0)
        return self
    end
end



mutable struct GenCo <: ActiveAgent
    name::String
    investmentHorizon::Real
    technologyPortfolio::TechnologyPortfolio
    availableTechnologyPool::Array{Technology,1}
    competitorExpansion::Array{CapacityExpansionEdge,1}
    competitorDivision::Array{CapacityDivisionEdge,1}
    history::GenCoHistory

    #NOTE:Common functions
    Decomission::Function
    CalculateTotalCapacity::Function
    EvaluateTechnology::Function
    InvestmentDecision::Function
    ExecuteInvestmentDecision::Function
    ################################
    #NOTE:for GEP investment algorithm
    BuildExistingCapacity::Function
    FindFutureDecomission::Function
    FindFutureExisting::Function
    PriceProjection::Function
    #################################
    #NOTE:for :EMLab and EMCAS investment algorithm
    CreatVirtualEnvironment::Function
    SummarizeTechnologyList::Function
    TimeSeries::Function
    VirtualAuction::Function
    CompetitorInvestment::Function
    CalculateCompetitorExpansion::Function
    SelectExpansionPath::Function
    SelectDivisionPath::Function
    #################################

    function GenCo(name::String,investmentHorizon::Real,technologyPortfolio::TechnologyPortfolio,availableTechnologyPool::Array{Technology,1};kwargs...)
        self = new()
        self.name = name
        self.investmentHorizon = investmentHorizon
        self.technologyPortfolio = technologyPortfolio
        self.availableTechnologyPool = availableTechnologyPool
        V = Dict(kwargs)
        if haskey(V,:competitorExpansion) && haskey(V,:competitorDivision)
            self.competitorExpansion = V[:competitorExpansion]
            self.competitorDivision = V[:competitorDivision]
        end
        self.history = GenCoHistory()
        push!(self.history.technologyMixHistory, deepcopy(self.technologyPortfolio))
        for technology in self.technologyPortfolio.technologies
            push!(self.history.allTechnologiesPossessed,technology)
        end

        #NOTE: Dismantle technologies of this agent
        self.Decomission = function(currentYear::Real, allPowerFlows::Array{PowerFlow,1})
            technologyToDecomission = self.technologyPortfolio.FindTechnologyDecomission(currentYear)
            powerFlowToDelete = Array{PowerFlow,1}(undef,0)
            for powerFlow in allPowerFlows
                if powerFlow.from in technologyToDecomission
                    push!(powerFlowToDelete,powerFlow)
                end
            end
            append!(self.history.decomissionedTechnologies,technologyToDecomission)
            deleteat!(self.technologyPortfolio.technologies, findall(x->x in technologyToDecomission, self.technologyPortfolio.technologies))
            deleteat!(allPowerFlows, findall(x->x in powerFlowToDelete, allPowerFlows))
            return technologyToDecomission
        end


        #NOTE: calculate total system installed capacity
        self.CalculateTotalCapacity = function(allGenCos::Array{GenCo,1})
            totalCapacity = 0.0
            for genCo in allGenCos
                for technology in genCo.technologyPortfolio.technologies
                    totalCapacity += technology.offerQuantity
                end
            end
            return totalCapacity
        end

        #################################################################################################################
        ##############################:NOTE:These functions are for GEP only #############################################
        #NOTE:initial capacity for input of the GEP
        self.BuildExistingCapacity = function(allGenCos::Array{GenCo,1},technologyPool::Array{Technology,1},year::Real,systemSettings::SystemSettings)
            longestTechnologyLifeTime = 20 #TODO:Note this is temporary for this version;
            historicalCapacitySpan = Int(longestTechnologyLifeTime / systemSettings.milestoneYear)
            initialCapacityMatrix = zeros(length(technologyPool) , historicalCapacitySpan) #-15,-10,-5,0 (where 0 refers to the real investment in the current milestone year)
            technologyType = [:Base,:Mid,:Peak]
            for genCo in allGenCos
                for technology in genCo.technologyPortfolio.technologies
                    for techCount in 1:length(technologyPool)
                        if technology.type == technologyType[techCount]
                            initialCapacityMatrix[techCount, historicalCapacitySpan - Int((year - technology.designProperties.constructionTimeStamp)/systemSettings.milestoneYear)] += technology.designProperties.installedCapacity
                        end
                    end
                end
            end
            return initialCapacityMatrix
        end

        #NOTE:return a vector storing the expected decomissioning in future years
        self.FindFutureDecomission = function(allGenCos::Array{GenCo,1},year::Real,systemSettings::SystemSettings)
            decomissionHorizon = Int(self.investmentHorizon / systemSettings.milestoneYear)
            futureDecomission = zeros(1,decomissionHorizon)
            newAllGenCos = deepcopy(allGenCos)
            firstDecomissionTime = year
            finalDecomissionTime = year + self.investmentHorizon - systemSettings.milestoneYear
            for thisYear in firstDecomissionTime:systemSettings.milestoneYear:finalDecomissionTime
                for genCo in newAllGenCos
                    technologyToDecomission = genCo.technologyPortfolio.FindTechnologyDecomission(thisYear, :virtual)
                    for technology in technologyToDecomission
                        futureDecomission[Int((thisYear-year)/systemSettings.milestoneYear)+1] += technology.designProperties.installedCapacity
                    end
                    deleteat!(genCo.technologyPortfolio.technologies, findall(x->x in technologyToDecomission, genCo.technologyPortfolio.technologies))
                end
            end
            return futureDecomission
        end

        #NOTE:return a vector storing the existing generators in future years (including those new investments)
        self.FindFutureExisting = function(allGenCos::Array{GenCo,1},year::Real,systemSettings::SystemSettings)
            futureHorizon = Int(self.investmentHorizon / systemSettings.milestoneYear)
            futureExisting = zeros(1,futureHorizon)
            newAllGenCos = deepcopy(allGenCos)
            firstExistingTime = year
            finalExistingTime = year + self.investmentHorizon -  systemSettings.milestoneYear
            for thisYear in firstExistingTime:systemSettings.milestoneYear:finalExistingTime
                for genCo in newAllGenCos
                    for technology in genCo.technologyPortfolio.technologies
                        if (technology.designProperties.constructionTimeStamp + technology.designProperties.lifeTime) > thisYear
                            futureExisting[Int((thisYear-year)/systemSettings.milestoneYear)+1] += technology.designProperties.installedCapacity
                        end
                    end
                end
            end
            return futureExisting
        end

        #NOTE: GEP investment algorithm. Run GEP to get price projection
        self.PriceProjection = function(technologyPool::Array{Technology,1},allGenCos::Array{GenCo,1},systemLoad::Load,
                                        year::Real,systemSettings::SystemSettings)
            initialCapacityMatrix = self.BuildExistingCapacity(allGenCos,technologyPool,year,systemSettings)

            variable_cost = [technology.economicProperties.VOMCost + technology.economicProperties.fuelCost for technology in technologyPool]
            fixed_cost = [(technology.economicProperties.FOMCost + technology.economicProperties.yearlyInstallment)/technology.designProperties.unitCapacity for technology in technologyPool]
            representative_day = systemSettings.simulationSettings.year2day
            representative_hour = systemSettings.simulationSettings.day2hour
            year2hour = year2day * day2hour
            VoLL = priceCap
            weight_year = systemSettings.milestoneYear
            allTechnologyLifeTime = [technology.designProperties.lifeTime for technology in technologyPool]
            scaledAllTechnologyLifeTime = Int.(allTechnologyLifeTime/systemSettings.milestoneYear)
            longestTechnologyLifeTime = 20 #TODO:Note this is temporary for this version;
                                            #NOTE: the pre-opt year information has to cover what can still exist until the end of the investment horizon
            preOpt_Year = Int(longestTechnologyLifeTime/systemSettings.milestoneYear - 1) #-15,-10,5
            optimizeYear = Int(self.investmentHorizon/systemSettings.milestoneYear)
            #gep= Model(with_optimizer(Gurobi.Optimizer,GUROBI_ENV))
            gep=JuMP.direct_model(Gurobi.Optimizer(Method=1, OutputFlag = 0,Presolve=0))
            #gep=JuMP.direct_model(Gurobi.Optimizer(Presolve=0))

            start_hour = preOpt_Year * representative_day * representative_hour + 1 #Hour 1
            initial_hour = preOpt_Year * representative_day * representative_hour #Hour 0
            stop_hour = initial_hour + optimizeYear * representative_day * representative_hour #Final hour


            #NOTE:Claim variables from past(-preOpt_Year) to future (+optimizeYear)
            @variable(gep,g_j_t[1:length(technologyPool),1:stop_hour]) #generation
            @variable(gep,x_j_t[1:length(technologyPool),1:(optimizeYear+preOpt_Year)]) #Investment
            @variable(gep,y_j_t[1:length(technologyPool),1:(optimizeYear+preOpt_Year)]) #Online capacity
            @variable(gep,z_j_t[1:length(technologyPool),1:(optimizeYear+preOpt_Year)]) #decomission
            @variable(gep,LL_t[1:stop_hour]) #Load loss

            @variable(gep,g_j_t_y[1:length(technologyPool),1:stop_hour,1:4])
            @variable(gep,y_j_t_y[1:length(technologyPool),1:optimizeYear,1:4]) #Online capacity

            #The weights of representative days, and repeat for the whole optimization horizon
            representativeDayWeightFactors = systemSettings.simulationSettings.representativeData[:Weights][:,2]
            dailyWeight = repeat(representativeDayWeightFactors,optimizeYear + preOpt_Year)
            hourlyWeight_vector = repeat(dailyWeight, inner = (day2hour,1))

            #Define objective function
            #obj = 0
            obj = AffExpr(0.0)

            for year in (preOpt_Year+1):(optimizeYear+preOpt_Year)
                for j in 1:length(technologyPool)
                    @constraint(gep, x_j_t[j,year] >= 0)
                    for yy in 1:4
                        @constraint(gep,y_j_t_y[j,year-preOpt_Year,yy] == x_j_t[j, year-yy+1])
                        add_to_expression!(obj, fixed_cost[j]* weight_year,  y_j_t_y[j,year-preOpt_Year,yy])
                    end
                end
            end

            for j = 1:length(technologyPool)
                @constraint(gep, x_j_t[j,4] >= initialCapacityMatrix[j,4])
            end

            #Assign value to previous investments, so that future decommissioning information can be derived
            for year in 1 : preOpt_Year
                for j = 1:length(technologyPool)
                    @constraint(gep, x_j_t[j,year] == initialCapacityMatrix[j,year])
                    @constraint(gep, z_j_t[j,year] == 0)
                end
            end
            for j = 1:length(technologyPool)
                @constraint(gep, z_j_t[j,preOpt_Year+1] == 0)
            end

            #Objective function: variable costs + fixed costs
            for hour in start_hour:stop_hour
                thisYear = Int(ceil(hour / year2hour))
                for j in 1:length(technologyPool)
                    for yy in 1:4
                        add_to_expression!(obj, variable_cost[j] * hourlyWeight_vector[hour] * weight_year,  g_j_t_y[j,hour,yy] )
                    end
                end
                add_to_expression!(obj, VoLL * hourlyWeight_vector[hour] * weight_year,  LL_t[hour])

            end
            @objective(gep,Min,obj)
            constraintDict = Dict{String, Array}()

            for internalYear = 1:(preOpt_Year+optimizeYear)
                for day = 1:year2day
                    for hour = 1:day2hour
                        thisHour = (internalYear-1) * year2hour + (day-1) * day2hour + hour
                        #Load loss in the past, set to zero (optional)
                        if internalYear <= preOpt_Year
                            @constraint(gep, LL_t[thisHour] == 0)
                        end
                    end
                end
            end

            demand = repeat(vec(systemLoad.representativeLoad'),optimizeYear + preOpt_Year) #load for all hours
            demandSupplyConstraints = Array{Any,1}(undef,0)
            #println(size(demand))
            for hour in start_hour:stop_hour
                thisYear = Int(ceil(hour / year2hour))
                thisDemandSupply = @constraint(gep, sum(g_j_t_y[:,hour,:]) + LL_t[hour] == demand[hour])
                push!(demandSupplyConstraints,thisDemandSupply)

                @constraint(gep, LL_t[hour] >= 0)

                for j in 1:length(technologyPool)
                    for yy in 1:4
                        @constraint(gep, g_j_t_y[j,hour,yy] <= y_j_t_y[j,thisYear-preOpt_Year,yy])
                        @constraint(gep, g_j_t_y[j,hour,yy] >= 0)
                    end
                end
            end
            status = optimize!(gep)

            futureCapacityMix = zeros(length(technologyPool),optimizeYear)

            for year in (preOpt_Year+1) : (optimizeYear+preOpt_Year)
                for j in 1:length(technologyPool)
                    for yy in 1:4
                        futureCapacityMix[j,year-preOpt_Year] += value(gep[:y_j_t_y][j,year-preOpt_Year,yy])
                    end
                end
            end
            price = (JuMP.dual.(demandSupplyConstraints))./hourlyWeight_vector[start_hour:stop_hour]/weight_year

            # priceSpikes = price[findall(x -> x>=50, price)]
            # println("Price spikes: ",priceSpikes)
            return price,futureCapacityMix
        end


        #################################################################################################################
        ##############################:NOTE:These functions are for EMLab and EMCAS #############################################
        #Create a virtual play ground w.r.t. the current system capacity mix
        #Preparation for virtual market clearing simulation
        self.CreatVirtualEnvironment = function(allGenCos::Array{GenCo,1},MO::MarketOperator)
            newAllGenCos = deepcopy(allGenCos)
            newAllPowerFlows = Array{PowerFlow,1}(undef,0)
            for genCo in newAllGenCos
                for technology in genCo.technologyPortfolio.technologies
                    newPowerFlow  = PowerFlow(technology, MO, 0,0)
                    push!(newAllPowerFlows, newPowerFlow)
                end
            end
            return newAllGenCos, newAllPowerFlows
        end

        #build a list of all generators
        self.SummarizeTechnologyList = function(allGenCos::Array{GenCo,1},allPowerFlows::Array{PowerFlow,1},MO::MarketOperator,newTechnologyUnderEvaluation::Technology,competitorInvestment::Array{Technology,1})

            allTechnologiesVirtual = Array{Technology,1}(undef,0)
            for genCo in allGenCos
                for technology in genCo.technologyPortfolio.technologies
                    push!(allTechnologiesVirtual, technology)
                end
            end
            push!(allTechnologiesVirtual,newTechnologyUnderEvaluation)
            for technology in competitorInvestment
                push!(allTechnologiesVirtual,technology)
                push!(allPowerFlows,PowerFlow(technology,MO,0,0))
            end
            return allTechnologiesVirtual
        end

        #for renewables only
        self.TimeSeries = function(day::Int64,hour::Int64, load::Load, technologyList::Array{Technology,1})
            load.TimeSeries(day,hour)
            #for renewables only, not considered in this study
            for technology in technologyList
                if typeof(technology) == RenewablePlants
                    technology.TimeSeries(day,hour)
                end
            end
        end

        #Calculate maximum supply gap
        self.CalculateCompetitorExpansion = function(allGenCos::Array{GenCo,1},systemLoad::Load,capacityExpansionEdge::CapacityExpansionEdge)
            totalSupply = self.CalculateTotalCapacity(allGenCos)

            alreadyInvested_self = 0
            for technology in self.history.yearlyInvestment
                alreadyInvested_self += technology.designProperties.installedCapacity
            end

            maxLoad = findmax(systemLoad.representativeLoad)[1]
            totalExpansion = max(capacityExpansionEdge.gapCoverPercentage * maxLoad - totalSupply + alreadyInvested_self,0)
            #println(totalExpansion)
            return totalExpansion
        end

        #how much of the gap is filled by competitors
        self.SelectExpansionPath = function()
            return self.competitorExpansion[1] #This can be changed by the user if desired
        end

        #types of technologies invested by competitors (as expected by the agent)
        self.SelectDivisionPath = function()
            return self.competitorDivision[1] #This can be changed by the user if desired
        end

        # competitors' investment (if any)
        self.CompetitorInvestment = function(allGenCos::Array{GenCo,1}, thisYear::Real,technologyPool::Array{Technology,1},systemLoad::Load,systemSettings::SystemSettings)
            competitorInvestment =Array{Technology,1}(undef,0)
            if systemSettings.simulationSettings.investmentModelSelection == :EMCAS
                capacityExpansionEdge = self.SelectExpansionPath()
                capacityDivisionEdge = self.SelectDivisionPath()
                totalExpansion = self.CalculateCompetitorExpansion(allGenCos,systemLoad,capacityExpansionEdge)

                for typeCount in 1:length(technologyPool)
                    thisType = technologyPool[typeCount].type
                    thisProportion = get(capacityDivisionEdge.typeShare, thisType,0)
                    newTechnology = deepcopy(technologyPool[typeCount])
                    thisUnitNumber = totalExpansion * thisProportion / newTechnology.designProperties.unitCapacity
                    newTechnology.MultipleUnits(thisUnitNumber,systemSettings)
                    newTechnology.designProperties.constructionTimeStamp = deepcopy(thisYear)
                    push!(competitorInvestment,newTechnology)
                end
            end
            return competitorInvestment
        end

        #virtual market clearing
        self.VirtualAuction = function(allGenCos::Array{GenCo,1},technologyPool::Array{Technology,1},newTechnologyUnderEvaluation::Technology,MO::MarketOperator,systemLoad::Load,year::Real,systemSettings::SystemSettings)
            newAllGenCos, newAllPowerFlows = self.CreatVirtualEnvironment(allGenCos,MO)
            push!(newAllPowerFlows,PowerFlow(newTechnologyUnderEvaluation,MO,0,0))
            newSystemLoad = deepcopy(systemLoad)
            year2day = systemSettings.simulationSettings.year2day
            day2hour = systemSettings.simulationSettings.day2hour
            milestoneYear = systemSettings.milestoneYear
            futureCapacityMix = zeros(length(technologyPool),Int(self.investmentHorizon/milestoneYear))
            for virtualYear in year:(year+self.investmentHorizon-1)
                if virtualYear % milestoneYear == 0
                    for genCo in newAllGenCos
                        #Decomission
                        genCo.Decomission(virtualYear,newAllPowerFlows)
                    end
                    competitorInvestment = self.CompetitorInvestment(newAllGenCos, virtualYear,technologyPool,newSystemLoad,systemSettings)

                    allTechnologiesVirtual = self.SummarizeTechnologyList(newAllGenCos,newAllPowerFlows,MO,newTechnologyUnderEvaluation,competitorInvestment)

                    for technology in allTechnologiesVirtual
                        for techCount in 1:length(technologyPool)
                            if technology.type == technologyPool[techCount].type
                                futureCapacityMix[techCount,Int((virtualYear-year)/milestoneYear)+1] += technology.designProperties.installedCapacity
                            end
                        end
                    end

                    for day in 1:year2day, hour in 1:day2hour
                        self.TimeSeries(day,hour,newSystemLoad,allTechnologiesVirtual)
                        marketPrice = MO.ClearMarket(allTechnologiesVirtual,newAllPowerFlows, newSystemLoad)
                        MO.Payment(newAllPowerFlows, day,hour, :virtual,systemSettings)
                    end
                end
            end
            return futureCapacityMix
        end
        #################################################################################################################
        #################################################################################################################


        self.EvaluateTechnology = function(allGenCos::Array{GenCo,1},technologyPool::Array{Technology,1},MO::MarketOperator,newTechnologyUnderEvaluation::Technology,systemLoad::Load,year::Real,systemSettings::SystemSettings)
            revenueComponents = Dict(:PriceSpikes => 0.0, :NormalMarket => 0.0)
            costComponents = Dict(:VariableCost => 0.0, :FixedCost => 0.0)
            futureCapacityMix = zeros(length(technologyPool),Int(self.investmentHorizon/milestoneYear))

            if systemSettings.simulationSettings.investmentModelSelection == :GEP
                priceProjection,futureCapacityMix = self.PriceProjection(technologyPool,allGenCos,systemLoad,year,systemSettings)
                Cost = zeros(newTechnologyUnderEvaluation.designProperties.lifeTime)
                Revenue = zeros(newTechnologyUnderEvaluation.designProperties.lifeTime)
                representativeDayWeightFactors = systemSettings.simulationSettings.representativeData[:Weights][:,2]
                representative_day = systemSettings.simulationSettings.year2day
                representative_hour = systemSettings.simulationSettings.day2hour
                dailyWeight = repeat(representativeDayWeightFactors,Int(newTechnologyUnderEvaluation.designProperties.lifeTime/systemSettings.milestoneYear))

                variable_cost = newTechnologyUnderEvaluation.economicProperties.VOMCost + newTechnologyUnderEvaluation.economicProperties.fuelCost
                fixed_cost = (newTechnologyUnderEvaluation.economicProperties.FOMCost + newTechnologyUnderEvaluation.economicProperties.yearlyInstallment)/newTechnologyUnderEvaluation.designProperties.unitCapacity
                hourlyFixedCost = fixed_cost/(sum(representativeDayWeightFactors)*representative_hour)

                for hour in 1:length(priceProjection)
                    thisWeightDay = dailyWeight[Int(ceil(hour/representative_hour))]
                    thisYearStart = (Int(ceil(hour/representative_day/representative_hour))-1) * systemSettings.milestoneYear + 1
                    thisYearEnd = Int(ceil(hour/representative_day/representative_hour))*systemSettings.milestoneYear

                    Cost[thisYearStart:thisYearEnd] .+= repeat([hourlyFixedCost * thisWeightDay],systemSettings.milestoneYear)
                    costComponents[:FixedCost] += hourlyFixedCost * thisWeightDay * systemSettings.milestoneYear
                    thisPrice = priceProjection[hour]
                    if variable_cost < thisPrice
                        Cost[thisYearStart:thisYearEnd] .+= repeat([variable_cost *  thisWeightDay],systemSettings.milestoneYear)
                        costComponents[:VariableCost] += variable_cost *  thisWeightDay * systemSettings.milestoneYear
                        #Revenue[thisYearStart:thisYearEnd] .+= repeat([thisPrice * markupPercent[Int(thisDayHour)] *  thisWeightDay],systemSettings.milestoneYear)
                        Revenue[thisYearStart:thisYearEnd] .+= repeat([thisPrice *  thisWeightDay],systemSettings.milestoneYear)
                        if thisPrice >= 500
                            revenueComponents[:PriceSpikes] += thisPrice *  thisWeightDay * systemSettings.milestoneYear
                        else
                            revenueComponents[:NormalMarket] += thisPrice *  thisWeightDay * systemSettings.milestoneYear
                        end
                    end
                end

                yearVector = collect(0:1:(newTechnologyUnderEvaluation.designProperties.lifeTime-1))
                lifeDiscountVector = (1-systemSettings.interestRate) .^ yearVector
                NPV = (Revenue - Cost)' * lifeDiscountVector

            else
                newTechnologyUnderEvaluation.designProperties.constructionTimeStamp = deepcopy(year)
                futureCapacityMix = self.VirtualAuction(allGenCos,technologyPool,newTechnologyUnderEvaluation,MO,systemLoad,year,systemSettings)
                newTechnologyUnderEvaluation.AggregateHistory!(newTechnologyUnderEvaluation.economicProperties.virtualHistory, systemSettings)
                NPV = newTechnologyUnderEvaluation.economicProperties.virtualHistory.cashFlow[8]
                newTechnologyUnderEvaluation.economicProperties.virtualHistory.Reinitialize!()
            end
            return NPV,revenueComponents,costComponents,futureCapacityMix
        end



        #NOTE: Make investment decision based filtered technologies
        self.InvestmentDecision = function(allGenCos::Array{GenCo,1},MO::MarketOperator,technologyPool::Array{Technology,1},systemLoad::Load,year::Real,systemSettings::SystemSettings,systemHistory::SystemHistory)

            investmentIndicator = false
            bestTechnology = Nothing()

            #title_1 = string("Electricity price evolution as seen by \n", self.name," in year ", year)


            NPV_Dict = Dict(:Base => 0.0,:Mid => 0.0,:Peak => 0.0)
            revenueComponents_Dict = Dict(:Base => Dict{Symbol,Float64}(),:Mid => Dict{Symbol,Float64}(),:Peak => Dict{Symbol,Float64}())
            costComponents_Dict = Dict(:Base => Dict{Symbol,Float64}(),:Mid => Dict{Symbol,Float64}(),:Peak => Dict{Symbol,Float64}())
            bestNPV = -Inf
            #In each portfolio, every technology has a maximum number of units that can be invested, this loop is used to evaluate all these potential combination of numbers
            for technology in technologyPool
                newTechnologyUnderEvaluation = deepcopy(technology)
                thisNPV,revenueComponents,costComponents,futureCapacityMix = self.EvaluateTechnology(allGenCos,technologyPool,MO,newTechnologyUnderEvaluation,systemLoad,year,systemSettings)
                push!(systemHistory.capacityMixProjection,futureCapacityMix)
                NPV_Dict[technology.type] = thisNPV
                revenueComponents_Dict[technology.type] = revenueComponents
                costComponents_Dict[technology.type] = costComponents
                #println(newTechnologyUnderEvaluation.type, " NPV: ",thisNPV)
                if thisNPV >= -1e-5 && thisNPV > bestNPV
                    bestNPV = deepcopy(thisNPV)
                    #Store the best one and pop up the previous best one
                    bestTechnology = deepcopy(newTechnologyUnderEvaluation)
                    #println("bestNPV: ",thisNPV)
                    #println(unitNumber)
                    #println(bestTechnology.type, " ", bestTechnology.designProperties.installedCapacity)

                end
            end
            if typeof(bestTechnology) != Nothing
                investmentIndicator = true
                #println(bestTechnology.type, " ", bestTechnology.designProperties.installedCapacity)
            end

            #return NPV_Dict,revenueComponents_Dict,costComponents_Dict,investmentIndicator,bestTechnology,priceProjection,futureCapacityMix,capacityMix_Hour,cum_futureCapacityInvestment
            return investmentIndicator,bestTechnology

        end

        #NOTE: plug the new investment to the environment
        self.ExecuteInvestmentDecision = function(bestTechnology::Technology,allPowerFlows::Array{PowerFlow,1},MO::MarketOperator,year::Real)
            push!(self.technologyPortfolio.technologies, bestTechnology)
            bestTechnology.designProperties.constructionTimeStamp = deepcopy(year)
            newPowerFlow = PowerFlow(bestTechnology, MO, 0,0)
            push!(allPowerFlows,newPowerFlow)
            push!(self.history.yearlyInvestment, bestTechnology)
            push!(self.history.allTechnologiesPossessed,bestTechnology)
        end

        return self
    end
end


mutable struct GenCoPortfolioOwnership <: Ownership
    from::Agent
    to::Container
end
