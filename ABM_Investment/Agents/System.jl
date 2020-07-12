
include("Technology.jl")


mutable struct SystemState <: ScenarioNode
    year::Int64
    capacityMix::Array{Technology,1}
    installedCapacity::Float64
    installedLimitByTechnologyType::Dict{Symbol,Real} #MW
    installedByTechnologyType::Dict{Symbol,Real} #MW
    emissionPrice::Real

    CalculateInstalledCapacity::Function
    TimeSeries::Function

    function SystemState(year,capacityMix)
        self = new()
        self.year = year
        self.capacityMix = capacityMix
        self.installedCapacity = 0

        self.TimeSeries = function(day::Int64, hour::Int64, systemLoad::Load, yearlyTechnologyMix::Array{Technology,1})
            systemLoad.TimeSeries(day,hour)
            for technology in yearlyTechnologyMix
                if typeof(technology) == RenewablePlants
                    technology.TimeSeries(day,hour)
                end
            end
        end

        self.CalculateInstalledCapacity = function()
            for technology in self.capacityMix
                self.installedCapacity += technology.designProperties.installedCapacity
            end
        end

        return self
    end
end


mutable struct SystemHistory <: Buffer
    systemCapacityMix::Array{Array{Technology,1},1}
    systemElectricityPrice::Array{Float64,1}
    systemDecisionSequence::Array{Array{Array{Float64,1},1},1}
    capacityMixProjection::Array{Array,1}
    InvestmentHistory::Array{Symbol,1}

    function SystemHistory()
        self = new()
        self.systemCapacityMix = Array{Array{Technology,1},1}(undef,0)
        self.systemElectricityPrice = Array{Float64,1}(undef,0)
        self.systemDecisionSequence = Array{Array{Array{Float64,1},1},1}(undef,0)
        self.capacityMixProjection = Array{Array,1}(undef,0)
        self.InvestmentHistory = Array{Symbol,1}(undef,0)

        return self
    end

end
