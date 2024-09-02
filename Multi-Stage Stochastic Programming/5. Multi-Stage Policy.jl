using Random
using Distributions
using JuMP
using Gurobi
using Printf
using Clustering
using CSV
using DataFrames
using Distances
using BenchmarkTools
using MathOptInterface

### Discretization Function

function discretize_scen(x)
    y = round(x, RoundUp)
    return y
end

### Reduction method: K-MEDOIDS

function medoids_red(p_scen, N, it)
    prob_init = 1/it
    prob_fin = zeros(N)
    S = collect(1:N)

    D = zeros(Float64, it, it)
    for i = 1:it
        for j = 1:it
            # Calculate the distance between vector i and vector j
            D[i,j] = euclidean(p_scen[:, i], p_scen[:, j])
        end
    end

    result = kmedoids(D, N; maxiter=500)

    a = assignments(result) # get the assignments of points to clusters
    c = counts(result) # get the cluster sizes
    M = result.medoids # get the cluster centers

    # Assign probabilities to each medoids
    for n in S
        prob_fin[n] = prob_init*c[n]
    end

    # Assign the price of each medoid to final matrix
    p_cl = zeros(size(p_scen, 1), N)
    for i=1:N
        p_cl[:,i] = p_scen[:,M[i]]
    end
    
    return p_cl, prob_fin
end

###### Main Functions: Multistage & EEV

################ Multistage Decision Policy Function ################

function make_multistage_here_and_now_decision(T, tau, z_curr, p_curr)

    elapsed_time = @elapsed begin # Begin time count

        include("V2_02435_multistage_problem_data.jl")
        number_of_warehouses, W, cost_miss, cost_tr, warehouse_capacities, transport_capacities, initial_stock, number_of_simulation_periods, sim_T, demand_trajectory = load_the_data()

        # POLICY INPUTS
        policy_time = 3 # minimum value is 2
        policy_samples = 5000
        number_of_scenarios = 50

        # Only create scenarios when having stochastic stages, thus in last tau only deterministic
        if (T-tau)>0
            # SCENARIO GENERATION
            iter = collect(1:policy_samples)
            p_scen = zeros(number_of_warehouses*(policy_time-1),policy_samples)
            for i in iter
                for w in W
                    a = (w-1) * (policy_time-1) + 1
                    p_scen[a,i] = discretize_scen(sample_next(p_curr[w])) # For first stage after current t
                    if policy_time > 2 # If there are more stages
                        stages = collect(2:(policy_time-1))
                        for s in stages
                            b = (w-1) * (policy_time-1) + s
                            p_scen[b,i] = discretize_scen(sample_next(p_scen[b-1,i])) # Obtain final p_scen matrix with discretized values
                        end
                    end
                end
            end

            # SCENARIO REDUCTION
            # Reduction with K-Medoids with N clusters
            N = number_of_scenarios
            p_st, prob_fin = medoids_red(p_scen, N, policy_samples)

            # Reshape p_st to correct format
            p = zeros(number_of_warehouses,(policy_time),N)
            for w in W
                for j in collect(2:policy_time)
                    for i in collect(1:N)
                        p[w,j,i] = discretize_scen(p_st[((w-1) * (policy_time-1) + j-1),i]) # p_st should be discretized but just in case
                        p[w,1,i] = p_curr[w]
                    end
                end
            end
            
            # Creation of sets of shared scenario nodes: ONLY when more than 1 remaining timeslot or when policy time is higher than 2
            ## This is because if this is not the case, then all scenarios share the first stage and are independent in the second stage
            if (T-tau) > 1 || policy_time > 2
                Sp = Array{Union{Nothing, Vector, Any, Int}}(nothing, min(T-tau+1,policy_time),N)
                for i in range(1,N,N) # Iterate for all scenarios
                    for t in range(1,min(T-tau+1,policy_time),min(T-tau+1,policy_time)) # Iterate for all remanining times
                        c = Int64[]
                        push!(c,i)
                        for j in range(1,N,N) # Iterate again through all scenarios
                            if i != j
                                shared_path = false
                                counter = 0
                                for k in range(1,Int64(t),Int64(t)) # And through all stages from 1 to t
                                    for w in W # Check for all warehouses
                                        shared_path = false
                                        if p[w,Int64(k),Int64(i)] == p[w,Int64(k),Int64(j)] # If the price is equal
                                            shared_path = true
                                            counter += 1
                                        end
                                    end
                                end
                                if shared_path && counter == (number_of_warehouses*t) # Check if the boolean is true (for all stages and warehouses)
                                    push!(c,j)
                                end
                            end
                        end
                        Sp[Int64(t),Int64(i)] = c # Add the set "c" to the respective slot in matrix
                    end
                end
            else # Create an unique array where all scenarios share the 1st stage
                Sp = Array{Union{Nothing, Vector, Any, Int}}(nothing, min(T-tau+1,policy_time),N)
                for i in range(1,N,N)
                    for t in range(1,min(T-tau+1,policy_time),min(T-tau+1,policy_time))
                        Sp[Int64(t),Int64(i)] = collect(1:N)
                    end
                end
            end

            # CHECK TIMESLOT: redo T with the remaining timeslots, variable when tau increases
            if (T-tau)<policy_time
                RT = T-tau
                T = collect(1:(T-tau))
            else
                RT = policy_time
                T = collect(1:policy_time)
            end
        else # When in last stage (tau=T) then the model needs to be deterministic, thus no scenarios nor Sp
            T = collect(1:1)
            S = collect(1:1)
            N = 1
            prob_fin = ones(N)
            p = zeros(number_of_warehouses,(policy_time),N)
            for w in W
                for j in collect(2:policy_time)
                    for i in collect(1:N)
                        p[w,1,i] = p_curr[w]
                    end
                end
            end
            Sp = Array{Union{Nothing, Vector, Any, Int}}(nothing,1,N)
            for i in range(1,N,N)
                Sp[1,Int64(i)] = collect(1:N)
            end
        end
        

        # MODEL 
        # Parameter Definition
        b = cost_miss
        e = cost_tr
        Cs = warehouse_capacities
        Ct = transport_capacities
        D = demand_trajectory
        S = collect(1:N)
        z0 = z_curr

        # Declare model with Gurobi solver
        ms_model = Model(Gurobi.Optimizer)
        set_optimizer_attribute(ms_model, "OutputFlag", 0)

        # Variable Definition
        @variable(ms_model, 0 <= x[w in W, t in T, s in S]) # quantity order
        @variable(ms_model, 0 <= z[w in W, t in T, s in S]) # warehouse storage
        @variable(ms_model, 0 <= m[w in W, t in T, s in S]) # missing quantity
        @variable(ms_model, 0 <= ys[w in W, q in W, t in T, s in S]) # quantity send
        @variable(ms_model, 0 <= yr[w in W, q in W, t in T, s in S]) # quantity received

        # Declare minimization of costs objective function
        @objective(ms_model, Min, sum( prob_fin[s] * x[w,t,s]*p[w,t,s] for w in W for t in T for s in S )
                                + sum( prob_fin[s] * ys[w,q,t,s]*e[w,q] for w in W for q in W for t in T for s in S)
                                + sum( prob_fin[s] * m[w,t,s]*b[w] for w in W for t in T for s in S))

        # Constraint on transport (truck) capacity
        @constraint(ms_model, TrCap[w in W, q in W, t in T, s in S], ys[w,q,t,s] <= Ct[w,q])
        # Constraint on quantity sent equal to quantity received
        @constraint(ms_model, QTrans[w in W, q in W, t in T, s in S], ys[w,q,t,s] == yr[q,w,t,s])
        # Constraint on storage capacity
        @constraint(ms_model, StCap[w in W, t in T, s in S], z[w,t,s] <= Cs[w])
        # Constraint on demand fulfillment
        @constraint(ms_model, Demand[w in W, t in T, s in S], x[w,t,s] + m[w,t,s] + (t==1 ? z0[w] : z[w,t-1,s]) + sum( yr[w,q,t,s] for q in W) == D[w,t] + z[w,t,s] + sum( ys[w,q,t,s] for q in W))
        # Constraint on (stored) amount sent between warehouses
        @constraint(ms_model, YsCons[w in W, t in T, s in S], sum( ys[w,q,t,s] for q in W) <= (t==1 ? z0[w] : z[w,t-1,s]))
        # Constraints for Explicit Non-Anticipativity
        @constraint(ms_model, ExNonAntX[w in W, t in T, s in S, sp in Sp[t,s]], x[w,t,s] == x[w,t,sp])
        @constraint(ms_model, ExNonAntZ[w in W, t in T, s in S, sp in Sp[t,s]], z[w,t,s] == z[w,t,sp])
        @constraint(ms_model, ExNonAntM[w in W, t in T, s in S, sp in Sp[t,s]], m[w,t,s] == m[w,t,sp])
        @constraint(ms_model, ExNonAntYS[w in W, q in W, t in T, s in S, sp in Sp[t,s]], ys[w,q,t,s] == ys[w,q,t,sp])
        @constraint(ms_model, ExNonAntYR[w in W, q in W, t in T, s in S, sp in Sp[t,s]], yr[w,q,t,s] == yr[w,q,t,sp])

        # Optimize model
        optimize!(ms_model)

        ### Obtain desired outputs
        order = zeros(number_of_warehouses)
        send = zeros(number_of_warehouses,number_of_warehouses)
        receive = zeros(number_of_warehouses,number_of_warehouses)
        stock = zeros(number_of_warehouses)
        miss = zeros(number_of_warehouses)

        for w in W
            order[w] = value(x[w,1,1])
            stock[w] = value(z[w,1,1])
            miss[w] = value(m[w,1,1])
            for q in W
                send[w,q] = value(ys[w,q,1,1])
                receive[w,q] = value(yr[w,q,1,1])
            end
        end
    end

    num_variables = length(all_variables(ms_model))

    # Print characteristics of iteration, to check whether it fulfills the requirements of running time and variables
    println("ELAPSED TIME: $elapsed_time seconds")
    println("NUMBER OF VARIABLES CREATED: $num_variables")

    return order, send, receive, stock, miss

end
