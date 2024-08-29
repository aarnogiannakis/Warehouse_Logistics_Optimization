**Project Overview**

This project involves the development of an optimization framework for a coffee distribution system in a city with three distinct districts. The project is inspired by the course 02435 Decision-Making Under Uncertainty taught by Georgios Tsaousoglou at DTU (Technical University of Denmark). The goal is to ensure that each district's coffee demand is met at the lowest possible cost, taking into account uncertainties in coffee prices and the ability to redistribute coffee between warehouses.

**Problem Description**

The city is divided into three districts, each served by a dedicated warehouse. Each day, these warehouses must decide how much coffee to order from external suppliers and how much to exchange with neighboring warehouses to meet the stable daily demand. Coffee prices fluctuate daily, and while today’s prices are known, future prices are uncertain. Additionally, each warehouse has a limited storage capacity, and there are costs associated with ordering, transportation, and unmet demand.

To meet the daily coffee demand in each district, the program must decide how much coffee each warehouse should order from external suppliers, considering the fluctuating prices. Additionally, warehouses can transfer coffee between each other, subject to certain transportation limits and costs.

Failing to meet a district's demand incurs a penalty, representing the cost of using an emergency supplier. Therefore, the program's objective is to minimize the total cost, including purchasing, transportation, and penalty costs.

**Key Features**

•  Daily Decision Making: The program decides daily how much coffee to order for each warehouse, taking into account the current prices and stock levels.

•  Inter-Warehouse Transfers: Warehouses can share coffee with each other to balance supply, subject to transportation constraints.

•  Cost Minimization: The goal is to meet the coffee demand at the lowest possible cost, considering purchase prices, transportation costs, and penalties for unmet demand.

**Inputs**

•  Current Day: The day of operation (integer).

•  Coffee Prices: The current price of coffee at each warehouse (a continuous value between 0 and 10).

•  Stored Quantities: The amount of coffee currently stored in each warehouse (a continuous value between 0 and the warehouse's storage capacity).

**Outputs**

•  Order Quantities: The amount of coffee each warehouse should order from external suppliers.

•  Transfer Quantities: The amount of coffee to be transferred between warehouses.

•  Storage Levels: Updated storage levels after orders and transfers.

• Unmet Demand: If any demand is unmet, the amount and associated penalty costs.

