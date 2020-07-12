include("AbstractTypes/AbstractType.jl")
mutable struct PowerFlow <: PhysicalEdge
    from::Node #generator
    to::Node #MO
    quantity::Float64 # transmitted power (MWh)
    marketPrice::Float64 # EUR/MWh
end
