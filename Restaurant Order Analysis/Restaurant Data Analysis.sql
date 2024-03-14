--View the menu items table
select * from menu_items;

--Find the number of items on the menu
select count(*) from menu_items;

--What are the least and most expensive items in the menu
select max(price),min(price) from menu_items;

--How many Italian Dishes are on the menu
select count(*) from menu_items
where category='Italian';

--What are the least and most expensive Italian dishes
select max(price),min(price) from menu_items
where category='Italian';

--How many dishes are in each category
select category,count(*) from menu_items
group by category;

--what is the average dish price in each category
select category,AVG(price) from menu_items
group by category;

------------------------------------------------------

--view the order details table
select * from order_details;

--what is the date range of the table
select MIN(order_date),MAX(order_date) from order_details;

--How many orders were made within this date range
select count(distinct order_id) from order_details;

--How many items were ordered within this date range
select COUNT(item_id) from order_details;

--which orders had the most number of items
select count(item_id) Item_Count,order_id from order_details
group by order_id order by Item_Count desc;

--How many orders had more than 12 items
select count(*) from
(select order_id,count(item_id) Item_Count from order_details
group by order_id 
Having count(item_id)>12) num_orders;

------------------------------------------------------------

--Combine the order_details table and menu_items table into single table
select * 
from order_details od LEFT JOIN menu_items mi on  od.item_id=mi.menu_item_id;

--what were the least and most ordered items? What categories were they in?
select item_name,category, COUNT(order_details_id) as num_purchases
from order_details od LEFT JOIN menu_items mi on  od.item_id=mi.menu_item_id
group by item_name,category;

--What were the top 5 orders that spent the most money
select top 5 order_id, sum(price)
from order_details od LEFT JOIN menu_items mi on  od.item_id=mi.menu_item_id
group by order_id order by sum(price) desc;

--view the details of the highest spent order.
select category, count(item_id)
from order_details od LEFT JOIN menu_items mi on  od.item_id=mi.menu_item_id
where order_id=440
group by category;

--view the details of the top 5 highest spent orders. What insights can you gather?
select order_id,category, count(item_id)
from order_details od LEFT JOIN menu_items mi on  od.item_id=mi.menu_item_id
where order_id in (440,2075,1957,330,2675)
group by order_id,category
order by order_id;

-----------------------------------------

--Expensive Italian food was ordered more 

-----------------------------------------