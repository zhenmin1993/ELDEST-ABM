include("AbstractTypes/AbstractType.jl")

mutable struct CapacityExpansionNode <: ScenarioNode
    year::Int64
    incrementalQuantity::Float64
end

mutable struct CapacityDivisionNode <: ScenarioNode
    year::Int64
    probability::Float64
    capacityMix::Array{PhysicalNode,1}
end

mutable struct CapacityExpansionEdge <: ScenarioEdge
    #from::ScenarioNode
    #to::ScenarioNode
    probability::Float64
    gapCoverPercentage::Float64
end

mutable struct CapacityDivisionEdge <: ScenarioEdge
    #from::ScenarioNode
    #to::ScenarioNode
    probability::Float64
    typeShare::Dict{Symbol, Float64}
end

global gapCoverProbability = [(0.7,0.3),(0.7,0.3),(0.7,0.3),(0.7,0.3),(0.7,0.3)]
#global gapCoverPercentage = [(0.9,0.9),(0.9,0.9),(0.9,0.9),(0.9,0.9),(0.9,0.9)]

#capacityDivision expectation as seen by each GenCo
global divisionProbability = [(0.3,0.3,0.4),(0.3,0.3,0.4),(0.3,0.3,0.4),(0.3,0.3,0.4),(0.3,0.3,0.4)]

function NewCase(newExpansion::Float64,newDivision::Tuple{Float64,Float64,Float64})
    gapCoverPercentage = Array{Tuple,1}(undef,0)
    divisionTypeShare = Array{Tuple,1}(undef,0)
    for genCoCount in 1:5
        thisGapCover = (newExpansion,newExpansion)
        thisDivisionType = (Dict([(:Base, newDivision[1]),(:Mid, newDivision[2]),(:Peak, newDivision[3])]),
                            Dict([(:Base, newDivision[1]),(:Mid, newDivision[2]),(:Peak, newDivision[3])]),
                            Dict([(:Base, newDivision[1]),(:Mid, newDivision[2]),(:Peak, newDivision[3])]))
        push!(gapCoverPercentage,thisGapCover)
        push!(divisionTypeShare,thisDivisionType)
    end
    return gapCoverPercentage,divisionTypeShare
end
