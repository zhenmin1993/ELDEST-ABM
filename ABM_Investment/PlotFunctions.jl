function PlotStackBar(genCo::GenCo,systemHistory::SystemHistory,technologyType::Vector{Symbol})
    colorMix = ["blue","orange","red"]
    totalInvestmentHorizon = 1:length(genCo.history.investmentHistory)
    yearTechnologyInvestment = zeros(length(technologyType),length(genCo.history.investmentHistory))
    stackDataSets = zeros(length(technologyType),length(genCo.history.investmentHistory))
    bottom = zeros(1,length(genCo.history.investmentHistory))


    for typeCount in 1:length(technologyType)

        for year in totalInvestmentHorizon
            for generator in genCo.history.investmentHistory[year].technologies
                if generator.type==technologyType[typeCount]
                    yearTechnologyInvestment[typeCount,year] += generator.designProperties.installedCapacity
                    bottom[1,year] += generator.designProperties.installedCapacity
                end
            end
        end
        stackDataSets[typeCount,:] = deepcopy(bottom)
    end
    width = 0.9
    for typeCount in 1:length(technologyType)
        if typeCount == 1
            PyPlot.bar(totalInvestmentHorizon, yearTechnologyInvestment[typeCount,:], width,  label = String(technologyType[typeCount]),color=colorMix[typeCount])
        else
            PyPlot.bar(totalInvestmentHorizon, yearTechnologyInvestment[typeCount,:], width,  bottom = stackDataSets[typeCount-1,:],label = String(technologyType[typeCount]),color=colorMix[typeCount])
        end
    end

    PyPlot.grid(true)

    #textBottom = stackDataSets[length(technologyType),:] + yearTechnologyInvestment[length(technologyType),:]
    #for thisSequence in zip(totalInvestmentHorizon,textBottom,decisionSequence)
        #if thisSequence[1] % systemSettings.milestoneYear == 0
            #println(thisSequence)
            #PyPlot.text(x=thisSequence[1],y=thisSequence[2],s=Int(thisSequence[3]),fontsize = 16)
        #end
    #end
    PyPlot.ylim((0,2000))


end


function PlotCapacityMix(genCo::GenCo,technologyType::Vector{Symbol})
    capacityMixStream = genCo.history.technologyMixHistory
    totalHorizon = 1:length(capacityMixStream)
    yearTechnologyMix = zeros(length(capacityMixStream),length(technologyType))
    yearTechnologyCount = zeros(length(capacityMixStream),length(technologyType))
    for year in totalHorizon
        for generator in capacityMixStream[year].technologies
            for typeCount in 1:length(technologyType)
                if generator.type==technologyType[typeCount]
                    yearTechnologyMix[year,typeCount] += generator.designProperties.installedCapacity

                    yearTechnologyCount[year,typeCount] +=1
                end
            end
        end
    end
    totalInvestmentHorizon = 1:length(genCo.history.investmentHistory)
    yearTechnologyInvestment = zeros(length(genCo.history.investmentHistory),length(technologyType))
    for year in totalInvestmentHorizon
        for generator in genCo.history.investmentHistory[year].technologies
            for typeCount in 1:length(technologyType)
                if generator.type==technologyType[typeCount]
                    yearTechnologyInvestment[year,typeCount] += generator.designProperties.installedCapacity
                end
            end
        end
    end

    colorMix = ["blue","orange","red"]
    #PyPlot.subplot(2,1,1)
    PyPlot.stackplot(totalHorizon,yearTechnologyMix' ,colors = colorMix )
    subplotName = string(genCo.name," capacity mix")
    PyPlot.title(genCo.name, fontsize = 20)
    PyPlot.ylim((0,4500))
    PyPlot.xlabel("time[year]", fontsize = 20)
    PyPlot.ylabel("capacity mix [MW]", fontsize = 20)
    PyPlot.xticks(fontsize = 18)
    PyPlot.yticks(fontsize = 18)
    PyPlot.grid(true)
    for i in 1:length(technologyType)
        PyPlot.plot([],[],color=colorMix[i], label=String(technologyType[i]), lineWidth=5)
    end
    PyPlot.legend()


end


function PlotPriceEvolutionInvest(allGenCos::Vector{GenCo}, year::Int64)
    totalPlots = length(allGenCos)
    for genCoCount in 1:totalPlots
        PyPlot.subplot(totalPlots,1,genCoCount)
        titleName = string("Price Evolution Observed by GenCo ",genCoCount, "at year ",year)
        PyPlot.title(titleName, fontsize = 10)
        PyPlot.plot(allGenCos[genCoCount].history.investmentHistory[year].history.electricityPriceHistory)



        if genCoCount == (Int(round(totalPlots/2)) + totalPlots % 2)
            PyPlot.ylabel("Price[EUR/MWh]", fontsize = 20)
        end
        if genCoCount == totalPlots
            PyPlot.xlabel("time[hour]", fontsize = 20)
        end

        PyPlot.grid(true)
    end
end

function PlotNPVStream(allGenCos::Vector{GenCo}, year::Int64)
    totalPlots = length(allGenCos)
    for genCoCount in 1:totalPlots
        PyPlot.subplot(totalPlots,1,genCoCount)
        titleName = string("NPV Observed by GenCo ",genCoCount, " at year ",year)
        PyPlot.title(titleName, fontsize = 10)
        PyPlot.plot(1:length(allGenCos[genCoCount].history.NPVHistory[year,:]),allGenCos[genCoCount].history.NPVHistory[year,:])
        if genCoCount == (Int(round(totalPlots/2)) + totalPlots % 2)
            PyPlot.ylabel("NPV[EUR]", fontsize = 20)
        end
        if genCoCount == totalPlots
            PyPlot.xlabel("Number of generator units", fontsize = 20)
        end

        PyPlot.grid(true)
    end
end

function PlotLoadDurationCurve(systemSettings::SystemSettings)
    hourlyLoad = deepcopy(systemSettings.simulationSettings.representativeData)
    sort!(dailyLoadFactors, rev = true)
    PyPlot.title("Load duration curve of one day", fontsize = 20)
    PyPlot.step(365:365:length(dailyLoadFactors)*365,dailyLoadFactors)
    PyPlot.xlabel("Hour", fontsize = 20)
    PyPlot.ylabel("Load", fontsize = 20)
    PyPlot.grid(true)
end

function PlotLDCwithSC(systemSettings::SystemSettings,technologyPool::Array{Technology,1})
    ts = dft.time_series["DEM_BE_Z"]


    #PyPlot.figure(1)
    fig, ax1 = PyPlot.subplots()
    color = "tab:red"
    x = [x for x in range(1,stop=8760)/8760*100.]
    y = sort(ts.data, rev=true)
    ax1.plot(x, y, label="original", color = "black",linestyle="dashed")

    y = systemSettings.simulationSettings.representativeData[:Load]'[:]
    x = (systemSettings.simulationSettings.representativeData[:Weights][:,2] * ones(1, 24))'[:] / 8760 * 100.
    df2 = sort(DataFrame(x=x, y=y, legend="reduced"), [:y], rev=true)
    df2[:x] = cumsum(df2[:x])
    ax1.plot(df2.x, df2.y, label="reduced (by representative days)",color = "cyan")
    ax1.grid(true)
    ax1.set_ylabel("Load [MW]", fontsize = 24)

    ax1.tick_params( labelsize = 20)
    PyPlot.legend(fontsize = 20, loc = "best")
    ax2 = ax1.twinx()
    color = "tab:blue"
    timeList = collect(1:8760)
    colorMix = ["blue","orange","red"]
    for technologyCount in 1:length(technologyPool)
        if technologyType[technologyCount] in [:Base,:Mid,:Peak]
            technology = technologyPool[technologyCount]
            thisUnitFOM = technology.economicProperties.unitFOMCost/ technology.designProperties.unitCapacity
            thisTechnologyYearlyPay = technology.economicProperties.yearlyInstallment / technology.designProperties.installedCapacity
            thisUnitVOM = technology.economicProperties.unitVOMCost + technology.economicProperties.fuelCost + technology.economicProperties.emissionCost
            thisCurve =  (thisUnitFOM +thisTechnologyYearlyPay) * ones(8760) .+  thisUnitVOM * timeList
            thisLabel = String(technologyType[technologyCount])
            ax2.plot(timeList/8760*100,thisCurve,label = thisLabel,color = colorMix[technologyCount])
            #PyPlot.title("Screening curve", fontsize = 20)
            #PyPlot.xticks(fontsize = 18)
            #PyPlot.yticks(fontsize = 18)
            #PyPlot.grid(true)
        end
    end
    PyPlot.plot(timeList/8760*100, priceCap*timeList,label = "VoLL",color = "black")
    PyPlot.xlim((0,100))
    PyPlot.ylim((0,5e5))

    ax2.set_ylabel("Annual Cost [€]", fontsize = 24)
    ax2.tick_params( labelsize = 20)
    ax2.set_xlabel("Time in a year [%]", fontsize = 24)
    ax1.set_xlabel("Time in a year [%]", fontsize = 24)
    PyPlot.legend(fontsize = 20, loc = "best")

end




function PlotObservedPrice(systemHistory::SystemHistory,  systemLoad::Load, technologyType::Vector{Symbol}, sliceYear::Real, horizon::Int64)
    #sliceYear += -1
    thisCapacityMix = systemHistory.systemCapacityMix[sliceYear]
    newCapacityMix = Array{Technology,1}(undef,0)
    for generator in thisCapacityMix

        if generator.designProperties.constructionTimeStamp <  sliceYear
            push!(newCapacityMix,deepcopy(generator))
        end

    end
    capacityMixAnticipation = Array{Array{Technology,1},1}(undef,0)
    for virtualYear in sliceYear:(sliceYear+horizon)
        tempCapacityMix = Array{Technology,1}(undef,0)
        for generator in newCapacityMix
            if (generator.designProperties.constructionTimeStamp + generator.designProperties.lifeTime) > virtualYear
                push!(tempCapacityMix, deepcopy(generator))
            end
        end
        push!(capacityMixAnticipation,tempCapacityMix)
    end
    yearTechnologyMix = zeros(length(capacityMixAnticipation),length(technologyType))
    yearTechnologyCount = zeros(length(capacityMixAnticipation),length(technologyType))
    date = 1:length(capacityMixAnticipation)
    for year in date
        for generator in capacityMixAnticipation[year]
            for typeCount in 1:length(technologyType)
                if generator.type == technologyType[typeCount]
                    yearTechnologyMix[year,typeCount] += generator.designProperties.installedCapacity
                    yearTechnologyCount[year,typeCount] +=1
                end
            end
        end
    end

    titleName = string("System capacity mix projection from an investment year ")
    colorMix = ["#0485d1","#e17701","grey"]
    PyPlot.stackplot(date.-1,yearTechnologyMix' ,colors = colorMix )
    PyPlot.title(titleName, fontsize = 20)
    PyPlot.xlabel("time[year]", fontsize = 20)
    PyPlot.ylabel("capacity mix [MW]", fontsize = 20)
    PyPlot.xticks(fontsize = 18)
    PyPlot.yticks(fontsize = 18)
    newType = ["Base-load technology","Mid-load technology","Peak-load technology"]
    for i in 1:length(technologyType)
        PyPlot.plot([],[],color=colorMix[i], label=newType[i], lineWidth=5)
    end
    #PyPlot.grid(true)
    PyPlot.plot(date .- 1, 11500 *ones(length(date)), lineWidth=3 ,color = "y", label = "Load Peak = 11500 MW")
    PyPlot.legend(fontsize = 18)
end
