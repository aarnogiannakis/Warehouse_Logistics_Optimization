using Random
using Distributions
using JuMP
using Gurobi
using Printf
using Clustering
using CSV
using DataFrames

include("V2_02435_two_stage_problem_data.jl")
include("V2_price_process.jl")

number_of_warehouses, W, cost_miss, cost_tr, warehouse_capacities, transport_capacities, initial_stock, number_of_simulation_periods, sim_T, demand_trajectory = load_the_data()

# Experiment Generation (# 100)
number_of_experiments = 100
Expers = collect(1:number_of_experiments)

# Generate the prices for each experiment
initial_prices = zeros(number_of_experiments, number_of_warehouses)
price_trajectory = zeros(number_of_experiments, number_of_warehouses, number_of_simulation_periods)
for e in Expers
    for w in W
        initial_prices[e,w] = rand()*10
        price_trajectory[e,w,1] = initial_prices[e,w]
        for t in 2:number_of_simulation_periods
            price_trajectory[e,w,t] = sample_next(price_trajectory[e,w,t-1])
        end
    end
end

# Create dataframe to store the results
df_objvalue = DataFrame(ObjValOiH = Float64[], ObjValEVdet = Float64[], ObjValN5det = Float64[], ObjValN20det = Float64[], ObjValN50det = Float64[])

for e in Expers # loop for each experiment

    #1st Run to calculate the Expected-Value Benchmark
    include("EV_model.jl")

    ev_p2, ev_x1, ev_z1, ev_m1, ev_ys1, ev_yr1, ev_objvalue = Make_EV_here_and_now_decision(price_trajectory[e,:,1])

    # 2nd Run to calculate the Optimal-in-Hindsight Benchmark for each experiment
    include("OiH_model.jl")

    oih_x, oih_z, oih_m, oih_ys, oih_yr, oih_objvalue = Compute_OiH_Solution(price_trajectory[e,:,1],price_trajectory[e,:,2])
    
    # 3rd Run to calculate Two-stage stochastic decision with representative scenarios 
    include("SP_model.jl")

    N = 5 # representative scenarios
    st_n5_p2, st_n5_x1, st_n5_z1, st_n5_m1, st_n5_ys1, st_n5_yr1, st_n5_objvalue = Make_Stochastic_here_and_now_decision(price_trajectory[e,:,1], N)
    
    N = 20 # representative scenarios
    st_n20_p2, st_n20_x1, st_n20_z1, st_n20_m1, st_n20_ys1, st_n20_yr1, st_n20_objvalue = Make_Stochastic_here_and_now_decision(price_trajectory[e,:,1], N)

    N = 50 # representative scenarios
    st_n50_p2, st_n50_x1, st_n50_z1, st_n50_m1, st_n50_ys1, st_n50_yr1, st_n50_objvalue = Make_Stochastic_here_and_now_decision(price_trajectory[e,:,1], N)
    

    # For each experiment, given each program’s decisions for stage 1 and the revealed second-stage prices,
    # solve a deterministic (single-stage) program to make the optimal stage-two decisions.

    include("Deterministic_model.jl")

    # Create and store the obtained stock for each warehouse after t=1, will be the initial stock for t=2
    ev_z_1 = zeros(number_of_warehouses)
    st5_z_1 = zeros(number_of_warehouses)
    st20_z_1 = zeros(number_of_warehouses)
    st50_z_1 = zeros(number_of_warehouses)
    for w in W
        ev_z_1[w] = value(ev_z1[w])
        st5_z_1[w] = value(st_n5_z1[w])
        st20_z_1[w] = value(st_n20_z1[w])
        st50_z_1[w] = value(st_n50_z1[w])
    end

    #Optimal 2nd stage after 1st stage from Expected-Value Benchmark
    det_ev_x2, det_ev_z2, det_ev_m2, det_ev_ys2, det_ev_yr2, det_ev_objvalue = Make_Deterministic_1period(price_trajectory[e,:,1], price_trajectory[e,:,2], ev_x1, ev_z_1, ev_m1, ev_ys1)

    # Optimal-in-Hindsight not needed because the programme run like if you already knew the prices.
    
    # Optimal 2nd stage after 1st stage from Two-stage stochastic decision with representative scenarios 
    
    # With N = 5 representative scenarios
    det_st_n5_x2, det_st_n5_z2, det_st_n5_m2, det_st_n5_ys2, det_st_n5_yr2, det_st_n5_objvalue = Make_Deterministic_1period(price_trajectory[e,:,1], price_trajectory[e,:,2], st_n5_x1, st5_z_1, st_n5_m1, st_n5_ys1)
    
    # With N = 20 representative scenarios
    det_st_n20_x2, det_st_n20_z2, det_st_n20_m2, det_st_n20_ys2, det_st_n20_yr2, det_st_n20_objvalue = Make_Deterministic_1period(price_trajectory[e,:,1], price_trajectory[e,:,2], st_n20_x1, st20_z_1, st_n20_m1, st_n20_ys1)

    # With N = 50 representative scenarios
    det_st_n50_x2, det_st_n50_z2, det_st_n50_m2, det_st_n50_ys2, det_st_n50_yr2, det_st_n50_objvalue = Make_Deterministic_1period(price_trajectory[e,:,1], price_trajectory[e,:,2], st_n50_x1, st50_z_1, st_n50_m1, st_n50_ys1)

    #################################################################################
    
    # Export all results into a .csv with a DataFrame
    push!(df_objvalue, [value(oih_objvalue) value(det_ev_objvalue) value(det_st_n5_objvalue) value(det_st_n20_objvalue) value(det_st_n50_objvalue)])
    
end