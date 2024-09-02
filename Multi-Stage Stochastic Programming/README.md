# Part A of the repository

**1. Expected-Value (EV) Program**

This function focuses on making day-one decisions by considering both today’s known prices and expected prices for tomorrow. The decision-making process involves:

• Horizon of Two Days: The function considers a two-day horizon, making decisions for today based on the expected value of tomorrow’s prices.

• Input: The function receives the coffee prices for day one.

• Output: It returns the day-one decisions while reasoning about the expected outcomes on day two.

The data for this problem, including warehouse capacities, costs, and initial coffee levels, are sourced from the file V2_02435_two_stage_problem_data.jl. The stochastic process for predicting coffee prices is modeled using the sample_next function in V2_price_process.jl. This function allows the estimation of expected second-stage prices by averaging over 1,000 samples from the price process.



**2. Optimal-in-Hindsight Function**

This function is designed to evaluate the optimal decisions that could have been made if future prices were known in advance. It receives the coffee prices for both days and determines:

• Stage-One and Stage-Two Decisions: The optimal quantities to order, transfer, or store on both days.

• System’s Cost: The total cost incurred over the two days, considering the perfect foresight of prices.




**3. Two-Stage Stochastic Programming**
This function aims to make a robust, stochastic decision for day one by considering multiple scenarios for day two:

• Scenario Generation: It generates 1,000 equally probable scenarios for day two prices using sample_next and then reduces them to a specified number 𝑁 (5, 20, or 50) of representative scenarios with appropriate probabilities.

• Stochastic Decision: Based on these scenarios, the function makes a here-and-now decision for day one that minimizes the expected total cost over both days.




**Evaluation and Comparison**

To evaluate the effectiveness of the implemented functions, we perform the following steps:

1. Generate 100 Experiments: For each experiment, randomly generate initial prices uniformly from [0, 10].
2. Decision Making: For each experiment, apply each program (Expected-Value, Optimal-in-Hindsight, and the three versions of the Stochastic Program) to make a here-and-now decision for day one.
3. Second-Stage Prices: Generate the second-stage prices using the sample_next function.
4. Cost Calculation: For each program, determine the total cost over the two stages by solving a deterministic program for the second stage based on the revealed prices.
5. Simulation of Optimal-in-Hindsight: Simulate the Optimal-in-Hindsight solution for the same 100 experiments as if future prices were known.


The results of this evaluation help identify which approach yields the best cost minimization under uncertainty.
