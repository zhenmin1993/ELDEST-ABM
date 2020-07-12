include("Init.jl")
include("ProjectInvestment.jl")

##########################################################################################################
#Investment decision making algorithm"
#GEP = "cost-minimizing future investments" price projection method
#EMLab = "myopic agents" price projection method
#EMCAS = "exogenous scenarios for future investments" price projection method
investmentModelSelectionList = [:GEP,:EMLab,:EMCAS]
#Selecting the look-ahead horizon
genCoHorizonList = [5,10,15,20]

#Store the simulation history
evaluationHistory_List = Array{Any,2}(undef,length(investmentModelSelectionList),9)
systemHistory_List = Array{Any,2}(undef,length(investmentModelSelectionList),9)
allGenCos_List = Array{Any,2}(undef,length(investmentModelSelectionList),9)

#Looping through the cases tested in the study
for modelCount in 1:length(investmentModelSelectionList)
    systemSettings.simulationSettings.investmentModelSelection = investmentModelSelectionList[modelCount]
    #For "exogenous scenarios for future investments" method,
        #we test different scenario tree settings
    if modelCount == 3
        #First layer of the scenario tree
        newExpansionList = [0.95,0.9,0.85]
        #Second layer of the scenario tree
        newDivisionList = [(0.2,0.5,0.3),(0.3,0.2,0.5),(0.5,0.3,0.2)]
        caseCount = 0
        #Looping through different scenario tree settings
        #Outer loop: first layer
        for newExpansion in newExpansionList
            #Inner layer: second layer
            for newDivision in newDivisionList
                caseCount += 1
                #Create a new case and serve as input to the "Init.jl" function where GenCos are initialized
                #The function "NewCase" can be found in the file "ScenarioTree.jl"
                gapCoverPercentage,divisionTypeShare = NewCase(newExpansion,newDivision)
                #Initialize the system
                #MO = Market Operator
                #allGenCos = all Generation Companies
                #systemLoad = load data
                #allPowerFlows = all power flows (connection between market operator and generators)
                #technologyPool = all candidate technologies
                MO,allGenCos,systemLoad,allPowerFlows,technologyPool,systemState,systemHistory = InitSystem(systemSettings,genCoHorizon;gapCoverPercentage = gapCoverPercentage,divisionTypeShare = divisionTypeShare)
                #Run the simulation
                SimulateInvestment(systemSettings,MO,allGenCos,systemLoad,allPowerFlows,technologyPool,systemState,systemHistory)
                #Record the history
                systemHistory_List[modelCount,caseCount] = systemHistory
                allGenCos_List[modelCount,caseCount] = allGenCos
            end
        end
    else
        #For "cost-minimizing future investments" and "myopic agents" price projection method, we test the sensitivity of look-ahead horizon
        for genCoHorizonCount in 1:length(genCoHorizonList)
            #Similar operation as above
            MO,allGenCos,systemLoad,allPowerFlows,technologyPool,systemState,systemHistory = InitSystem(systemSettings,genCoHorizonList[genCoHorizonCount])
            SimulateInvestment(systemSettings,MO,allGenCos,systemLoad,allPowerFlows,technologyPool,systemState,systemHistory)
            systemHistory_List[modelCount,genCoHorizonCount] = systemHistory
            allGenCos_List[modelCount,genCoHorizonCount] = allGenCos
        end
    end
end
