function RetrieveCapacityMix(systemHistory::SystemHistory)
    date = 1:length(systemHistory.systemCapacityMix)
    yearTechnologyMix = zeros(length(systemHistory.systemCapacityMix)+4,length(technologyType))
    # yearTechnologyCount = zeros(length(systemHistory.systemCapacityMix),length(technologyType))
    # yearTechnologyIncremental = zeros(length(systemHistory.systemCapacityMix),length(technologyType))
    # conventionalPlantsCapacity = Array{Float64,1}(undef,0)
    # renewablePlantsCapacity = Array{Float64,1}(undef,0)
    # conventionalPlantsNumbers = Array{Float64,1}(undef,0)
    # renewablePlantsNumbers = Array{Float64,1}(undef,0)
    for year in date
    # thisConventionalPlantsCapacity = 0
    # thisRenewablePlantsCapacity = 0
    # thisConventionalPlantsNumber = 0
    # thisRenewablePlantsNumber = 0
    # if year >= 2
    #     yearTechnologyIncremental[year,:] = yearTechnologyMix[year,:] - yearTechnologyMix[year-1,:]
    # end
        for generator in systemHistory.systemCapacityMix[year]
            for typeCount in 1:length(technologyType)
                if generator.type == technologyType[typeCount]
                    yearTechnologyMix[year,typeCount] += generator.designProperties.installedCapacity
                    # yearTechnologyCount[year,typeCount] +=1
                end
            end
            # if typeof(generator) == ConventionalPlants
            #     thisConventionalPlantsNumber += 1
            #     thisConventionalPlantsCapacity += generator.designProperties.maximumOutPut
            # end
            #
            # if typeof(generator) == RenewablePlants
            #     thisRenewablePlantsNumber += 1
            #     thisRenewablePlantsCapacity += generator.designProperties.maximumOutPut
            # end
        end
    # push!(conventionalPlantsCapacity,thisConventionalPlantsCapacity)
    # push!(renewablePlantsCapacity,thisRenewablePlantsCapacity)
    # push!(conventionalPlantsNumbers,thisConventionalPlantsNumber)
    # push!(renewablePlantsNumbers,thisRenewablePlantsNumber)
    end
    for finalYears in 1:4
        yearTechnologyMix[end-finalYears+1,:] = yearTechnologyMix[end-4,:]
    end

    return yearTechnologyMix
end
# println(conventionalPlantsNumbers)
# println(renewablePlantsNumbers)


# fig, axis = subplots()
# axis.stackplot(date,conventionalPlantsCapacity,renewablePlantsCapacity, colors = ["orange", "green"])
# axis.xlabel("time[year]", fontsize = 20)
# axis.ylabel("capacity mix [MW]", fontsize = 20)
# axis.xticks(fontsize = 18)
# axis.yticks(fontsize = 18)
#
# axis.plot([],[],color="orange", label="thermal", lineWidth=5)
# axis.plot([],[],color="green",label="renewable", lineWidth=5)
# axis.legend()
allCapacityMix = zeros(17,3)
for GEPcase in 1:4
    yearTechnologyMix = RetrieveCapacityMix(systemHistory_List[1,GEPcase])
    allCapacityMix[GEPcase,:] = sum(yearTechnologyMix[end-15:end-1,:],dims=1)/15
end
for EMLabcase in 1:4
    yearTechnologyMix = RetrieveCapacityMix(systemHistory_List[2,EMLabcase])
    allCapacityMix[4+EMLabcase,:] = sum(yearTechnologyMix[end-15:end-1,:],dims=1)/15
end
for EMCAScase in 1:9
    yearTechnologyMix = RetrieveCapacityMix(systemHistory_List[3,EMCAScase])
    allCapacityMix[8+EMCAScase,:] = sum(yearTechnologyMix[end-15:end-1,:],dims=1)/15
end



fig, axis = subplots()

yearTechnologyMix = RetrieveCapacityMix(systemHistory_List[3,9])

#PyPlot.figure(figure_num)
colorMix = ["#0485d1","#e17701","grey"]
axis.stackplot(collect(1:size(yearTechnologyMix)[1]),yearTechnologyMix' ,colors = colorMix )
#axis.title("System capacity mix", fontsize = 20)
axis.set_xlabel("Time[year]", fontsize = 20)
axis.set_xticks(collect(0:5:size(yearTechnologyMix)[1]))
axis.set_ylabel("Capacity mix [MW]", fontsize = 20)
axis.tick_params(axis="both",  labelsize=18)
for i in 1:length(technologyType)
    axis.plot([],[],color=colorMix[i], label=String(technologyType[i]), lineWidth=8)
end
axis.plot(collect(1:size(yearTechnologyMix)[1]),13670.25 * ones(size(yearTechnologyMix)[1]), label="Maximum load", color = "black",lineWidth=3)
axis.grid(true)
axis.set_xlim([1,size(yearTechnologyMix)[1]])
axis.legend(loc="upper center", bbox_to_anchor=(0.5, 1.12),
          ncol=4, fancybox=true, shadow=false, fontsize = 14)

fig, axis = subplots()
existingUnits = [33 22 11 0;
                33 22 11 0;
                33 22 11 0]
existingCapacities = 100 .* existingUnits
totalCapacityProjection = systemHistory_List[1,4].capacityMixProjection[1]
newInvestments = totalCapacityProjection.-existingCapacities
existingCapacities_repeated = repeat(existingCapacities, inner = (1,5))
newInvestments_repeated = repeat(newInvestments, inner = (1,5))
sourceType = ["Base(existing)","Base(expected)", "Mid(existing)","Mid(expected)", "Peak(existing)", "Peak(expected)", "Supply gap = 100 MW"]
colorMix = ["#0485d1","cyan","#e17701","yellow","grey","darkgray","midnightblue"]
separateCapacityMatrix = zeros(length(sourceType),20)
for j in 1:3
    separateCapacityMatrix[2*j-1,:] = existingCapacities_repeated[j,:]
    separateCapacityMatrix[2*j,:] = newInvestments_repeated[j,:]
end
axis.stackplot(collect(1:size(separateCapacityMatrix)[2]),separateCapacityMatrix,colors = colorMix)
axis.plot(collect(1:20),13670.25 * ones(20), label="Maximum load", color = "orange",lineWidth=3)
axis.set_xlim([1,20])
axis.set_xticks([5,10,15,20])
axis.set_xticklabels([])
axis.tick_params(axis="both",  labelsize=18)
axis.set_ylabel("Capacity mix [MW]",fontsize = 20)
axis.set_xlabel("Time [Year]",fontsize = 20)





# figure_num += 1
# PyPlot.figure(figure_num)
# for genCoCount in 1:systemSettings.GenCoNumbers
#     PyPlot.subplot(systemSettings.GenCoNumbers,1,genCoCount)
#     titleName = string("Investment History of GenCo ",genCoCount)
#     PyPlot.title(titleName)
#     PlotStackBar(allGenCos[genCoCount],systemHistory,technologyType)
#     if genCoCount == 1
#         PyPlot.legend()
#     end
#     if genCoCount == 3
#         PyPlot.ylabel("capacity mix [MW]", fontsize = 20)
#     end
#     PyPlot.xticks(fontsize = 4)
#     PyPlot.yticks(fontsize = 18)
#     if genCoCount == 5
#         PyPlot.xticks(fontsize = 18)
#     end
# end
# PyPlot.xlabel("time[year]", fontsize = 20)

# figure_num += 1
# PyPlot.figure(figure_num)
# PyPlot.plot(systemHistory.systemElectricityPrice)
# PyPlot.title("Electricity price evolution", fontsize = 20)
# PyPlot.xlabel("time[year]", fontsize = 20)
# PyPlot.ylabel("electricity price [EUR/MWh]", fontsize = 20)
# PyPlot.xticks(fontsize = 18)
# PyPlot.yticks(fontsize = 18)
# PyPlot.grid(true)


#figure_num += 1
#PyPlot.figure(figure_num)
#PlotLoadDurationCurve(systemSettings)
#plt.show()







# for genCo in allGenCos
#     global figure_num += 1
#     PyPlot.figure(figure_num)
#     PlotCapacityMix(genCo,technologyType)
# end

# figure_num += 1
# PyPlot.figure(figure_num)
# PlotObservedPrice(systemHistory,  systemLoad, technologyType, 40 ,20)




# println(systemHistory.yearlyInvestmentInformation[1])
# CSV.write("InvestmentHistory.csv", systemHistory.yearlyInvestmentInformation[1])
#figure_num += 1
#PyPlot.figure(figure_num)
#PlotPriceEvolutionInvest(allGenCos, 30)

#figure_num += 1
#PyPlot.figure(figure_num)
#PlotNPVStream(allGenCos, 5)
# figure_num += 1
# caseList = collect(1:9)
# fig, axes = PyPlot.subplots(3, 3, sharex=true)
# #axes.get_xaxis().set_visible(false)
# for caseNum in caseList
#     colorMix = ["#0485d1","#e17701","grey"]
#     row_count = Int(ceil(caseNum/3))
#     if caseNum % 3 == 0
#         column_Count = 3
#     else
#         column_Count = caseNum % 3
#     end
#     axes[row_count,column_Count].stackplot(0:1,sensitivity_EMCAS[caseNum]' ,colors = colorMix )
#     axes[row_count,column_Count].plot(0:1, 13670 *ones(2), lineWidth=3 ,color = "y")
#     axes[row_count,column_Count].get_xaxis().set_visible(false)
#     axes[row_count,column_Count].grid(true)
#
#
#     if column_Count == 2 || column_Count == 3
#         axes[row_count,column_Count].set_yticklabels([])
#     end
#     axes[row_count,column_Count].set_xticklabels(["Case1"])
#
#
#     #axes[column_Count,row_count].bar([1],sensitivity_EMCAS[caseNum][1,1],width = 0.5)
#     #axes[column_Count,row_count].bar([1],sensitivity_EMCAS[caseNum][1,2],width = 0.5,bottom=sensitivity_EMCAS[caseNum][1,1])
#     #axes[column_Count,row_count].bar([1],sensitivity_EMCAS[caseNum][1,3],width = 0.5,bottom=(sensitivity_EMCAS[caseNum][1,2]+sensitivity_EMCAS[caseNum][1,1]))
#     #axes[column_Count,row_count].set_xticks(0:1, ["G1"])
#     #PyPlot.title("System capacity mix", fontsize = 20)
#     #xName = string("Case ",caseNum)
#     #PyPlot.xlabel(xName, fontsize = 20)
#     #PyPlot.ylabel("capacity mix [MW]", fontsize = 20)
#     #PyPlot.xticks(fontsize = 18)
#     axes[row_count,column_Count].tick_params(labelsize = 16)
#     if row_count == 1
#         axes[row_count,column_Count].set_ylim(ymin = 0, ymax = 32000)
#     end
#     if row_count == 2
#         axes[row_count,column_Count].set_ylim(ymin = 0, ymax = 32000)
#     end
#     if row_count == 3
#         axes[row_count,column_Count].set_ylim(ymin = 0, ymax = 32000)
#     end
# end
# #fig.text(0.5, 0.04, "Cases number", ha="center",fontsize = 20)
# fig.text(0.04, 0.5, "Capacity mix [MW]", va="center", rotation="vertical",fontsize = 24)
