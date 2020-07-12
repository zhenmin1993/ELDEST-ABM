GenCoNumbers = 5
genCoHorizon = 20
totalHorizon = 50
day2hour = 24
year2day = 6
milestoneYear = 5
interestRate = 0.05
segmentNumbers = 1
downpaymentRatio = 0.0

priceCap = 3000


###Technology parameters
technologyType = [:Base,:Mid,:Peak]
emission_ton_perMWh = [0,0,0]
lifeTime = [20,20,20]
domesticLearningRates = [0,0,0]
nonDomesticLearningRates = [0,0,0]


availability = [1,1,1]
constructionTimeStamp = [0,0,0]
constructionTime = [0,0,0]


deconstructionTime = [1,1,1]
efficiency = [0.4,0.48,0.6] #Conversion fuel -> electricity 0.0-1.0
fuelPrice = [3,15,25]


unitCapacity = [100,100,100] #MW
minCapacity = [0,0,0]

#EconomicProperty
technologyVOM = [5,4,4] #EUR/MWh
technologyFOM_perMWa = [80,40,17] * 1000 #EUR/MWa
constructionCost_perMW = [3000,1200,800] * 1000 #EUR/MW
deconstructionCost_perMW = constructionCost_perMW .* [0.1,0.1,0.1] #EUR/MW

#Technological cost of each unit
unitVOMCost = technologyVOM
unitFOMCost = technologyFOM_perMWa .* unitCapacity
unitConstructionCost = constructionCost_perMW .* unitCapacity
unitDeconstructionCost = deconstructionCost_perMW .* unitCapacity


emissionPrice = 0.0
