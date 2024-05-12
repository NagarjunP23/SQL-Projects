
------------------------Data Cleaning------------------------------

--- In this data cleaning project, I have used Self Join, CTE, String and Window Functions to clean and standardize the data.


--Remove Duplicate
--Standardize the data
--Handle Null/Blank values
--Remove any columns


select * from layoffs;
select count(company) from layoffs;


--CREATING NEW TABLE FROM EXISTING TABLE
SELECT * INTO LAYOFF_STAGING FROM LAYOFFS;
SELECT * FROM LAYOFF_STAGING;


-----IDENTIFYING DUPLICATES-----

-----WE CAN USE ROW_NUMBER-----

WITH DUPLICATE_CTE AS
(
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY COMPANY, LOCATION, INDUSTRY, TOTAL_LAID_OFF, DATE, STAGE, COUNTRY, FUNDS_RAISED_MILLIONS 
ORDER BY COMPANY
) AS RN
FROM LAYOFF_STAGING
)
SELECT * FROM DUPLICATE_CTE WHERE RN > 1; --IF RN >= 2 then we have duplicate.

-- From the Duplicate rows, explore to see whether it is an actual duplicate
SELECT * FROM LAYOFF_STAGING WHERE COMPANY='Casper'; 



-----DELETE THE DUPLICATE ROWS-----

WITH DUPLICATE_CTE AS
(
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY COMPANY, LOCATION, INDUSTRY, TOTAL_LAID_OFF, DATE, STAGE, COUNTRY, FUNDS_RAISED_MILLIONS 
ORDER BY COMPANY
) AS rN
FROM LAYOFF_STAGING
)
DELETE FROM DUPLICATE_CTE WHERE RN > 1;


-----STANDARDIZING DATA-----

SELECT COMPANY, TRIM(COMPANY) FROM LAYOFF_STAGING; 

-- Remove Leading/Trailing Spaces.
UPDATE LAYOFF_STAGING
SET COMPANY = TRIM(COMPANY);


SELECT DISTINCT INDUSTRY FROM LAYOFF_STAGING WHERE INDUSTRY LIKE 'Crypto%';

--Convert multiple names to one single value.
UPDATE LAYOFF_STAGING
SET INDUSTRY = 'Crypto'
WHERE INDUSTRY LIKE 'Crypto%';

UPDATE LAYOFF_STAGING
SET COUNTRY = TRIM(TRAILING '.' FROM COUNTRY)
WHERE COUNTRY LIKE 'United States%';

SELECT DATE, CONVERT(date, LAYOFF_STAGING.DATE) FROM LAYOFF_STAGING;


-----Handle Null/Blank values-----

SELECT DISTINCT INDUSTRY FROM LAYOFF_STAGING;

-- Update Text 'NULL' to NULL value.
UPDATE LAYOFF_STAGING SET TOTAL_LAID_OFF=NULL WHERE TOTAL_LAID_OFF='NULL';
UPDATE LAYOFF_STAGING SET PERCENTAGE_LAID_OFF=NULL WHERE TOTAL_LAID_OFF='NULL';


SELECT L1.INDUSTRY, L2.INDUSTRY 
FROM LAYOFF_STAGING L1 JOIN LAYOFF_STAGING L2
ON L1.COMPANY = L2.COMPANY
WHERE L1.industry = '' AND
L2.industry IS NULL;



-- Instead of deleting blank values, we can get the value from other row where we have data.
-- Here we can use self join to get the value of industry using the matching company name where industry value is not NULL.
WITH NULL_CTE AS(
SELECT L1.INDUSTRY AS IND1, L2.INDUSTRY AS IND2
FROM LAYOFF_STAGING L1 JOIN LAYOFF_STAGING L2
ON L1.COMPANY = L2.COMPANY
WHERE L1.industry IS NULL AND
L2.industry IS NOT NULL
)
UPDATE NULL_CTE SET IND1 = IND2
WHERE IND1 IS NULL AND IND2 IS NOT NULL;


-- Delete rows where we cannot get data using other rows.
DELETE FROM LAYOFF_STAGING
WHERE total_laid_off = 'NULL' AND percentage_laid_off = 'NULL';

SELECT * FROM LAYOFF_STAGING
WHERE total_laid_off = 'NULL' AND percentage_laid_off = 'NULL';


