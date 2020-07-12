include("AbstractTypes/AbstractType.jl")


mutable struct Load <: PassiveAgent
    priceCap::Real # EUR/MWh
    hourlyLoad::Real # load at a specific hour
    representativeLoad::Matrix{Float64} #load factor at each hour in a day

    TimeSeries::Function

    function Load(priceCap::Real,hourlyLoad::Real,representativeLoad::Matrix{Float64})
        self = new()
        self.priceCap = priceCap
        self.hourlyLoad = hourlyLoad
        self.representativeLoad = representativeLoad

        # This function changes load along with hour
        self.TimeSeries = function(day::Int64,hour::Int64)
            self.hourlyLoad = self.representativeLoad[day,hour]
        end
        return self
    end
end
