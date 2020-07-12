using Revise

using RepresentativeDaysFinders
using JuMP
#using GLPK
using Gurobi
import DataFrames
##################################################################################
# Specify location of config-file
##################################################################################
config_file = normpath(joinpath(@__DIR__, "scenarios", "investment_model_BE.yaml"))


##
using Cbc

dft = findRepresentativeDays(config_file, with_optimizer(Cbc.Optimizer; seconds = 20))
# findRepresentativeDays(config_file, with_optimizer(GLPK.Optimizer; presolve=true, msg_lev=GLPK.MSG_ALL, tm_lim=180*1000))
# Juno.@enter findRepresentativeDays(config_file, with_optimizer(GLPK.Optimizer; presolve=true, msg_lev=GLPK.MSG_ALL, tm_lim=180*1000))

#RepresentativeDaysFinders.create_plots(dft)

df_dv = DataFrames.DataFrame(
            periods     = sort([k for k in dft.periods]),
            weights     = [dft.w[k] for k in sort([k for k in keys(dft.w)])],
            used_days   = [dft.u[k] for k in sort([k for k in keys(dft.u)])])
#CSV.write(joinpath(result_dir, "decision_variables.csv"), df_dv, delim=';')

df_dv_s = deepcopy(df_dv[df_dv[:weights] .> 0, :])

function ParseRepresentativeDaysResults(df_dv_s::DataFrames.DataFrame)
    selected_representativeDays = zeros(size(df_dv_s,1),2)
    for row in 1:size(df_dv_s,1)
        day = parse(Int,df_dv_s[row,:][:periods][2:4])
        weight = df_dv_s[row,:][:weights]
        println([day weight])
        selected_representativeDays[row,:] = [day weight]
        println([day,weight])
    end
    return selected_representativeDays
end
selected_representativeDays = ParseRepresentativeDaysResults(df_dv_s)
