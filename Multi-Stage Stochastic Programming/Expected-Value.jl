using Random
using Distributions
using JuMP
using Gurobi
using Printf

function Make_EV_here_and_now_decision(initial_prices)

    # Load data and auxiliary functions
    include("V2_02435_two_stage_problem_data.jl")
    include("V2_price_process.jl")
    num_warehouses, warehouses, penalty_miss, trans_cost, storage_caps, trans_caps, init_stock, num_periods, time_slots, demand_traj = load_the_data()

    # Generate 1000 price scenarios for the second day for each warehouse
    num_scenarios = 1000
    price_scenarios = zeros(num_warehouses, num_scenarios)
    for w in warehouses
        for i in 1:num_scenarios
            price_scenarios[w, i] = sample_next(initial_prices[w])
        end
    end

    # Initialize the optimization model using Gurobi
    model = Model(Gurobi.Optimizer)

    # Define Parameters
    W = warehouses
    T = time_slots
    b = penalty_miss
    e = trans_cost
    Cs = storage_caps
    Ct = trans_caps
    D = demand_traj
    avg_prices_day2 = zeros(num_warehouses)
    for w in W
        avg_prices_day2[w] = mean(price_scenarios[w, :])
    end
    z_initial = init_stock

    # Define Variables
    @variable(model, 0 <= order_day1[w in W])  # Amount ordered in stage 1
    @variable(model, 0 <= order_day2[w in W])  # Amount ordered in stage 2
    @variable(model, 0 <= storage_day1[w in W])  # Storage at the end of stage 1
    @variable(model, 0 <= storage_day2[w in W])  # Storage at the end of stage 2
    @variable(model, 0 <= unmet_demand_day1[w in W])  # Unmet demand in stage 1
    @variable(model, 0 <= unmet_demand_day2[w in W])  # Unmet demand in stage 2
    @variable(model, 0 <= sent_day1[w in W, q in W])  # Amount sent in stage 1
    @variable(model, 0 <= sent_day2[w in W, q in W])  # Amount sent in stage 2
    @variable(model, 0 <= received_day1[w in W, q in W])  # Amount received in stage 1
    @variable(model, 0 <= received_day2[w in W, q in W])  # Amount received in stage 2

    # Objective: Minimize total costs (orders, transportation, and unmet demand)
    @objective(model, Min, 
        sum(order_day1[w] * initial_prices[w] + order_day2[w] * avg_prices_day2[w] for w in W) +
        sum((sent_day1[w, q] + sent_day2[w, q]) * e[w, q] for w in W, q in W) +
        sum((unmet_demand_day1[w] + unmet_demand_day2[w]) * b[w] for w in W)
    )

    # STAGE 1 Constraints
    @constraint(model, TransportCapacity1[w in W, q in W], sent_day1[w, q] <= Ct[w, q])  # Truck capacity
    @constraint(model, QuantityTransfer1[w in W, q in W], sent_day1[w, q] == received_day1[q, w])  # Equal sent and received
    @constraint(model, StorageLimit1[w in W], storage_day1[w] <= Cs[w])  # Storage capacity
    @constraint(model, DemandFulfillment1[w in W], 
        order_day1[w] + unmet_demand_day1[w] + z_initial[w] + sum(received_day1[w, q] for q in W) ==
        D[w, 1] + storage_day1[w] + sum(sent_day1[w, q] for q in W)
    )  # Demand fulfillment
    @constraint(model, SentQuantityLimit1[w in W], sum(sent_day1[w, q] for q in W) <= z_initial[w])  # Sent amount limit

    # STAGE 2 Constraints
    @constraint(model, TransportCapacity2[w in W, q in W], sent_day2[w, q] <= Ct[w, q])  # Truck capacity
    @constraint(model, QuantityTransfer2[w in W, q in W], sent_day2[w, q] == received_day2[q, w])  # Equal sent and received
    @constraint(model, StorageLimit2[w in W], storage_day2[w] <= Cs[w])  # Storage capacity
    @constraint(model, DemandFulfillment2[w in W], 
        order_day2[w] + unmet_demand_day2[w] + storage_day1[w] + sum(received_day2[w, q] for q in W) ==
        D[w, 2] + storage_day2[w] + sum(sent_day2[w, q] for q in W)
    )  # Demand fulfillment
    @constraint(model, SentQuantityLimit2[w in W], sum(sent_day2[w, q] for q in W) <= storage_day1[w])  # Sent amount limit

    # Optimize the model
    optimize!(model)

    # Extract the objective value and return results
    total_cost = objective_value(model)

    return avg_prices_day2, order_day1, storage_day1, unmet_demand_day1, sent_day1, received_day1, total_cost
end
