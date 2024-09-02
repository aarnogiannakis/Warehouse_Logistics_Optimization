using Random
using Distributions
using JuMP
using Gurobi
using Printf

function Compute_OiH_Solution(price_day1, price_day2)

    # Load data and auxiliary functions
    include("V2_02435_two_stage_problem_data.jl")
    include("V2_price_process.jl")
    num_warehouses, warehouses, miss_cost, trans_cost, storage_caps, trans_caps, init_stock, num_periods, time_slots, demand_traj = load_the_data()

    # Initialize the optimization model using Gurobi
    model = Model(Gurobi.Optimizer)

    # Define Parameters
    W = warehouses
    T = time_slots
    b = miss_cost
    e = trans_cost
    Cs = storage_caps
    Ct = trans_caps
    D = demand_traj
    z_initial = init_stock

    # Define Variables
    @variable(model, 0 <= order[w in W, t in T])  # Quantity ordered
    @variable(model, 0 <= storage[w in W, t in T])  # Storage at the end of each period
    @variable(model, 0 <= unmet_demand[w in W, t in T])  # Unmet demand
    @variable(model, 0 <= sent[w in W, q in W, t in T])  # Quantity sent
    @variable(model, 0 <= received[w in W, q in W, t in T])  # Quantity received

    # Objective: Minimize total costs (orders, transportation, and unmet demand)
    @objective(model, Min,
        sum(order[w, 1] * price_day1[w] + order[w, 2] * price_day2[w] for w in W) +
        sum(sent[w, q, t] * e[w, q] for w in W, q in W, t in T) +
        sum(unmet_demand[w, t] * b[w] for w in W, t in T)
    )

    # Constraints
    # Truck capacity constraint
    @constraint(model, TransportCapacity[w in W, q in W, t in T], sent[w, q, t] <= Ct[w, q])

    # Ensure the quantity sent equals the quantity received
    @constraint(model, QuantityTransfer[w in W, q in W, t in T], sent[w, q, t] == received[q, w, t])

    # Storage capacity constraint
    @constraint(model, StorageLimit[w in W, t in T], storage[w, t] <= Cs[w])

    # Demand fulfillment constraint
    @constraint(model, DemandFulfillment[w in W, t in T],
        order[w, t] + unmet_demand[w, t] + (t == 1 ? z_initial[w] : storage[w, t-1]) +
        sum(received[w, q, t] for q in W) == D[w, t] + storage[w, t] + sum(sent[w, q] for q in W)
    )

    # Sent quantity constraint (limited by storage)
    @constraint(model, SentQuantityLimit[w in W, t in T],
        sum(sent[w, q, t] for q in W) <= (t == 1 ? z_initial[w] : storage[w, t-1])
    )

    # Optimize the model
    optimize!(model)

    # Extract the objective value and return results
    total_cost = objective_value(model)

    return order, storage, unmet_demand, sent, received, total_cost 
end
