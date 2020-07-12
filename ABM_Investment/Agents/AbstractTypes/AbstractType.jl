abstract type Node end
abstract type PhysicalNode <: Node end
abstract type Technology <: PhysicalNode end
abstract type SocialNode <: Node end
abstract type Agent <: SocialNode end
abstract type ActiveAgent <: Agent end
abstract type PassiveAgent <: Agent end
abstract type Container <: SocialNode end #Used to store portfolio
abstract type ScenarioNode <: SocialNode end



abstract type Edge end
abstract type PhysicalEdge <: Edge end

abstract type SocialEdge <: Edge end
abstract type Contract <: SocialEdge end
abstract type Ownership <: SocialEdge end
abstract type ScenarioEdge <: SocialEdge end

abstract type Parameters end
abstract type Property <: Parameters end



abstract type Buffer end


abstract type Factors end
abstract type FutureProjection <: Factors end
