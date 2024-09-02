using Random
using Distributions
using JuMP
using Gurobi
using Printf
using Clustering


function Make_Stochastic_here_and_now_decision(p1, N)

    include("V2_02435_two_stage_problem_data.jl")
    include("V2_price_process.jl")
    number_of_warehouses, W, cost_miss, cost_tr, warehouse_capacities, transport_capacities, initial_stock, number_of_simulation_periods, sim_T, demand_trajectory = load_the_data()

    #Create 1000 prices scenarios for each warehouse for the second day. 
    it = 1000
    iter = collect(1:it)
    p_scen = zeros(number_of_warehouses,it)
    for w in W
        for i in iter
            p_scen[w,i] = sample_next(p1[w])
        end
    end

    #Declare model with Gurobi solver
    st_model = Model(Gurobi.Optimizer)

    # Parameter Definition
    W = W
    T = sim_T
    b = cost_miss
    e = cost_tr
    Cs = warehouse_capacities
    Ct = transport_capacities
    D = demand_trajectory
    S = collect(1:N)
    prob_init = 1/it
    prob_fin = zeros(N)

    result = kmeans(p_scen, N; maxiter=500)

    a = assignments(result) # get the assignments of points to clusters
    c = counts(result) # get the cluster sizes
    p2 = result.centers # get the cluster centers

    # Probability for each scenario
    for n in S
        prob_fin[n] = prob_init*c[n]
    end

    z0 = initial_stock

    # Variable Definition
    @variable(st_model, 0 <= x1[w in W]) # quantity order in stage 1
    @variable(st_model, 0 <= x2[w in W, s in S]) # quantity order in stage 2
    @variable(st_model, 0 <= z1[w in W]) # warehouse storage in stage 1
    @variable(st_model, 0 <= z2[w in W, s in S]) # warehouse storage in stage 2
    @variable(st_model, 0 <= m1[w in W]) # missing quantity in stage 1
    @variable(st_model, 0 <= m2[w in W, s in S]) # missing quantity in stage 2
    @variable(st_model, 0 <= ys1[w in W, q in W]) # quantity send in stage 1
    @variable(st_model, 0 <= ys2[w in W, q in W, s in S]) # quantity send in stage 2
    @variable(st_model, 0 <= yr1[w in W, q in W]) # quantity received in stage 1
    @variable(st_model, 0 <= yr2[w in W, q in W, s in S]) # quantity received in stage 2

    #Declare minimization of costs objective function
    @objective(st_model, Min, sum( x1[w]*p1[w] for w in W) + sum( x2[w,s]*p2[w,s]*prob_fin[s] for w in W for s in S) + sum( ys1[w,q]*e[w,q] for w in W for q in W) + sum( ys2[w,q,s]*e[w,q]*prob_fin[s] for w in W for q in W for s in S) + sum( m1[w]*b[w] for w in W) + sum( m2[w,s]*b[w]*prob_fin[s] for w in W for s in S))

    # STAGE 1
    #Constraint on transport (truck) capacity
    @constraint(st_model, TrCap1[w in W, q in W], ys1[w,q] <= Ct[w,q])
    #Constraint on quantity sent equal to quantity received
    @constraint(st_model, QTrans1[w in W, q in W], ys1[w,q] == yr1[q,w])
    #Constraint on storage capacity
    @constraint(st_model, StCap1[w in W], z1[w] <= Cs[w])
    #Constraint on demand fulfillment
    @constraint(st_model, Demand1[w in W], x1[w] + m1[w] + z0[w] + sum( yr1[w,q] for q in W) == D[w,1] + z1[w] + sum( ys1[w,q] for q in W))
    #Constraint on (stored) amount sent between warehouses
    @constraint(st_model, YsCons1[w in W], sum( ys1[w,q] for q in W) <= z0[w])

    # STAGE2
    #Constraint on transport (truck) capacity
    @constraint(st_model, TrCap2[w in W, q in W, s in S], ys2[w,q,s] <= Ct[w,q])
    #Constraint on quantity sent equal to quantity received
    @constraint(st_model, QTrans2[w in W, q in W, s in S], ys2[w,q,s] == yr2[q,w,s])
    #Constraint on storage capacity
    @constraint(st_model, StCap2[w in W, s in S], z2[w,s] <= Cs[w])
    #Constraint on demand fulfillment
    @constraint(st_model, Demand2[w in W, s in S], x2[w,s] + m2[w,s] + z1[w] + sum( yr2[w,q,s] for q in W) == D[w,2] + z2[w,s] + sum( ys2[w,q,s] for q in W))
    #Constraint on (stored) amount sent between warehouses
    @constraint(st_model, YsCons2[w in W, s in S], sum( ys2[w,q,s] for q in W) <= z1[w])
    
    #Optimize model
    optimize!(st_model)

    objvalue = objective_value(st_model)

    return p2, x1, z1, m1, ys1, yr1, objvalue

end