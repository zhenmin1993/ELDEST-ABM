include("AbstractTypes/AbstractType.jl")


mutable struct SimulationSettings <: Parameters
    day2hour::Int64 # One day has 24 hours
    year2day::Int64 # representative days in one year
    maxUnitNumbers::Int64 #Maximum units of each technology that can be once invested
    downpaymentRatio::Float64 # Initial payment
    representativeData::Dict{Symbol,Matrix} # The weight of each representative day
    investmentSequence::Symbol # sequential or parallel
    investmentModelSelection::Symbol #EMLab,EMCAS,GEP
end

mutable struct SystemSettings <: Parameters
    GenCoNumbers::Int64 # Total number of generation companies
    totalHorizon::Int64 # Simulation length
    milestoneYear::Int64
    interestRate::Float64 # risk-free interest rate in the bank
    simulationSettings::SimulationSettings
end
