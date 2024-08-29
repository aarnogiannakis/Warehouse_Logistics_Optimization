**Project Overview**

This project involves optimizing the daily operations of a coffee distribution system in a city with three distinct districts. Each district is served by its own dedicated warehouse, and the goal is to ensure that each district's coffee demand is met at the lowest possible cost. The program you will find in this repository simulates the day-to-day decision-making process for ordering and redistributing coffee between the warehouses.

**Problem Description**

The city is divided into three districts, each of which is served by a specific warehouse. The daily coffee demand in each district is known and consistent, but the price of coffee from suppliers varies for each warehouse and can change from day to day. Each warehouse has a limited storage capacity, and they start with a certain initial stock of coffee.

To meet the daily coffee demand in each district, the program must decide how much coffee each warehouse should order from external suppliers, considering the fluctuating prices. Additionally, warehouses can transfer coffee between each other, subject to certain transportation limits and costs.

Failing to meet a district's demand incurs a penalty, representing the cost of using an emergency supplier. Therefore, the program's objective is to minimize the total cost, including purchasing, transportation, and penalty costs.

**Key Features**

-- Daily Decision Making: The program decides daily how much coffee to order for each warehouse, taking into account the current prices and stock levels.
-- Inter-Warehouse Transfers: Warehouses can share coffee with each other to balance supply, subject to transportation constraints.
-- Cost Minimization: The goal is to meet the coffee demand at the lowest possible cost, considering purchase prices, transportation costs, and penalties for unmet demand.

**Inputs**
-- Current Day: The day of operation (integer).
-- Coffee Prices: The current price of coffee at each warehouse (a continuous value between 0 and 10).
-- Stored Quantities: The amount of coffee currently stored in each warehouse (a continuous value between 0 and the warehouse's storage capacity).

**Outputs**
-- Order Quantities: The amount of coffee each warehouse should order from external suppliers.
-- Transfer Quantities: The amount of coffee to be transferred between warehouses.
-- Storage Levels: Updated storage levels after orders and transfers.
-- Unmet Demand: If any demand is unmet, the amount and associated penalty costs.
