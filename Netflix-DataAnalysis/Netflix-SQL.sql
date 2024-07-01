
---------------------------------------------NETFLIX ETL------------------------------------------------


--------------------------------------------DATA CLEANING-----------------------------------------------

-- Check the number of columns

SELECT * FROM NETFLIX__RAW
where show_id = 's5023';


--Since all the columns were varchar(max), we will change it after some exploration using python.
-- Drop the existing table and create it manually.

DROP TABLE [dbo].[netflix__raw]

CREATE TABLE [dbo].[netflix__raw](
	[show_id] [nvarchar](10) primary key,
	[type] [nvarchar](10) NULL,
	[title] [nvarchar](200) NULL,
	[director] [nvarchar](250) NULL,
	[cast] [nvarchar](1000) NULL,
	[country] [nvarchar](200) NULL,
	[date_added] [nvarchar](50) NULL,
	[release_year] [int] NULL,
	[rating] [nvarchar](10) NULL,
	[duration] [nvarchar](10) NULL,
	[listed_in] [nvarchar](100) NULL,
	[description] [nvarchar](500) NULL
)

--------------------------------------------------------------------------------------------------------

-- Removing Duplicates

SELECT SHOW_ID, COUNT(*)
FROM NETFLIX__RAW
GROUP BY SHOW_ID
HAVING COUNT(*) > 1;

-- Since SHOW_ID does not contain duplicates we can set it as PRIMARY KEY.

-- Checking duplicates in different columns

SELECT * FROM NETFLIX__RAW
WHERE TITLE IN (
	SELECT TITLE
	FROM NETFLIX__RAW
	GROUP BY TITLE
	HAVING COUNT(*) > 1
)
ORDER BY TITLE;

-- Here we got some duplicates, There can be shows with same Title but type of show can be different(Movie, TV Show...)

SELECT * FROM (
	SELECT TITLE, TYPE
	FROM NETFLIX__RAW
	GROUP BY TITLE, TYPE
	HAVING COUNT(*) > 1
) as t;


WITH CTE AS(
	SELECT *,
	ROW_NUMBER() OVER(PARTITION BY TITLE, TYPE ORDER BY SHOW_ID) AS RNK
	FROM NETFLIX__RAW
)
SELECT *
FROM CTE
WHERE RNK = 1;


-- A movie can be directed by multiple directors, listed in multiple genre...
-- Create new table for LISTED_IN, DIRECTOR, COUNTRY, CAST.

--DIRECTORS TABLE

SELECT SHOW_ID, TRIM(VALUE) AS DIRECTOR
INTO NETFLIX_DIRECTOR
FROM NETFLIX__RAW
CROSS APPLY STRING_SPLIT(DIRECTOR,',');

SELECT * FROM NETFLIX_DIRECTOR;

--LISTED_IN TABLE

SELECT SHOW_ID, TRIM(VALUE) AS LISTED_IN
INTO NETFLIX_LISTED_IN
FROM NETFLIX__RAW
CROSS APPLY STRING_SPLIT(LISTED_IN,',');

SELECT * FROM NETFLIX_LISTED_IN;


--CAST TABLE

SELECT SHOW_ID, TRIM(VALUE) AS CAST
INTO NETFLIX_CAST
FROM NETFLIX__RAW
CROSS APPLY STRING_SPLIT(CAST,',');

SELECT * FROM NETFLIX_CAST;

--COUNTRY TABLE

SELECT SHOW_ID, TRIM(VALUE) AS COUNTRY
INTO NETFLIX_COUNTRY
FROM NETFLIX__RAW
CROSS APPLY STRING_SPLIT(COUNTRY,',');

SELECT * FROM NETFLIX_COUNTRY;

-- Populating missing values in Country, Director columns

-- We cannot identify the country directly, 
-- so we are assuming that if a DIRECTOR has produced a show in a country we can use that to populate COUNTRY where it is NULL for the same director.

INSERT INTO NETFLIX_COUNTRY
SELECT SHOW_ID, M.COUNTRY 
FROM NETFLIX__RAW NR
INNER JOIN (
	SELECT DIRECTOR, COUNTRY
	FROM NETFLIX_COUNTRY NC
	INNER JOIN NETFLIX_DIRECTOR ND
	ON NC.SHOW_ID = ND.SHOW_ID
	GROUP BY DIRECTOR, COUNTRY
	) M 
	ON NR.DIRECTOR = M.DIRECTOR
WHERE NR.COUNTRY IS NULL;

-- Data Type conversion for Date_added column
-- In some rows duration is present in Rating column, change it using CASE STATEMENT.
-- Duplicates Removed

-- Final Cleaned Table

WITH CTE AS(
	SELECT *,
	ROW_NUMBER() OVER(PARTITION BY TITLE, TYPE ORDER BY SHOW_ID) AS RNK
	FROM NETFLIX__RAW
)
SELECT SHOW_ID,TYPE,TITLE,CAST(DATE_ADDED AS date) AS DATE_ADDED,RELEASE_YEAR,
RATING, 
CASE WHEN DURATION IS NULL THEN RATING ELSE DURATION END AS DURATION, description
INTO NETFLIX_STAGE
FROM CTE
WHERE RNK = 1;


-------------------------------------------Data Analysis------------------------------------------------

/* 
1. For each Director, count the number of TV Shows and Movies produced by them in separate column 
 for directors who have produced both TV Shows and Movies
*/

-- First we will get the Directors who produced bith Movie and TV Show

SELECT ND.DIRECTOR, COUNT(DISTINCT NS.TYPE) AS DISTINCT_TYPE
FROM NETFLIX_STAGE NS
INNER JOIN NETFLIX_DIRECTOR ND
ON NS.SHOW_ID = ND.SHOW_ID
GROUP BY ND.DIRECTOR
HAVING COUNT(DISTINCT NS.TYPE) > 1
ORDER BY DISTINCT_TYPE;

-- Now we need to count the number of movies and TV shows for the directors from above query result

SELECT ND.DIRECTOR, 
	COUNT(DISTINCT CASE WHEN NS.TYPE = 'Movie' THEN NS.SHOW_ID END) AS NO_OF_MOVIES,
	COUNT(DISTINCT CASE WHEN NS.TYPE = 'TV Show' THEN NS.SHOW_ID END) AS NO_OF_TVShows
FROM NETFLIX_STAGE NS
INNER JOIN NETFLIX_DIRECTOR ND
ON NS.SHOW_ID = ND.SHOW_ID
GROUP BY ND.DIRECTOR
HAVING COUNT(DISTINCT NS.TYPE) > 1;



-- 2. Which country has highest number of comedy movies?

--First we will get the Show id's of countries where Genre is Comedies and Type is Movie

SELECT NL.SHOW_ID, NC.COUNTRY
FROM NETFLIX_LISTED_IN NL
INNER JOIN NETFLIX_COUNTRY NC ON NL.SHOW_ID = NC.SHOW_ID
INNER JOIN NETFLIX_STAGE NS ON NL.SHOW_ID= NS.SHOW_ID
WHERE NL.LISTED_IN = 'Comedies' AND NS.TYPE='Movie';

-- Now we need to count the number of MOVIES FOR EACH COUNTRY AND SELECT TOP 1

SELECT TOP 1 NC.COUNTRY, COUNT(DISTINCT NL.SHOW_ID) AS NO_OF_MOVIES
FROM NETFLIX_LISTED_IN NL
INNER JOIN NETFLIX_COUNTRY NC ON NL.SHOW_ID = NC.SHOW_ID
INNER JOIN NETFLIX_STAGE NS ON NL.SHOW_ID= NS.SHOW_ID
WHERE NL.LISTED_IN = 'Comedies' AND NS.TYPE='Movie'
GROUP BY NC.COUNTRY
ORDER BY NO_OF_MOVIES DESC;


-- 3. For each year(as per date_added to Netflix), 
-- which director has maximum number of movies released, if there is tie pick the first one based on Alphabetical order

-- First we get the total number of movies for the director in each year
SELECT ND.DIRECTOR, YEAR(DATE_ADDED) AS DATE_YEAR, COUNT(NS.SHOW_ID) AS NO_OF_MOVIES
FROM NETFLIX_DIRECTOR ND
INNER JOIN NETFLIX_STAGE NS ON ND.SHOW_ID= NS.show_id
WHERE NS.TYPE='Movie'
GROUP BY ND.DIRECTOR, YEAR(DATE_ADDED)
ORDER BY NO_OF_MOVIES DESC;


-- We need to get the Director with max number of movies each year, 1st alphabetically

WITH CTE AS (
	SELECT ND.DIRECTOR, YEAR(DATE_ADDED) AS DATE_YEAR, COUNT(NS.SHOW_ID) AS NO_OF_MOVIES
	FROM NETFLIX_DIRECTOR ND
	INNER JOIN NETFLIX_STAGE NS ON ND.SHOW_ID= NS.show_id
	WHERE NS.TYPE='Movie'
	GROUP BY ND.DIRECTOR, YEAR(DATE_ADDED)
),
CTE2 AS (
	SELECT *,
	ROW_NUMBER() OVER(PARTITION BY DATE_YEAR ORDER BY NO_OF_MOVIES DESC,DIRECTOR) RN
	FROM CTE
)
SELECT * FROM CTE2 WHERE RN=1
ORDER BY DATE_YEAR DESC;


-- 4. What is the average duration of movies in each genre?

SELECT * 
FROM NETFLIX_STAGE
WHERE TYPE='Movie'; 

-- In the Duration column we have string values 'min' so we need to replace it and remove spaces AND CAST AS INT.

SELECT *, CAST(TRIM(REPLACE(DURATION,' min', '')) AS INT) AS DURATION
FROM NETFLIX_STAGE NS
WHERE TYPE='Movie'; 

-- Now we will use this to get the Avg duration by Genre

SELECT NL.LISTED_IN, AVG(CAST(TRIM(REPLACE(DURATION,' min', '')) AS INT)) AS AVG_DURATION
FROM NETFLIX_STAGE NS
INNER JOIN NETFLIX_LISTED_IN NL ON NS.show_id=NL.show_id
WHERE TYPE='Movie'
GROUP BY NL.LISTED_IN; 


-- 5. Find the list of directors who created both horror and comedy movies
-- Display director names along with the number of horror and comedy movies

-- First we get the Movies where Genre is ('Comedies','Horror Movies')
SELECT * FROM NETFLIX_STAGE NS
INNER JOIN NETFLIX_LISTED_IN NL ON NS.show_id=NL.show_id
WHERE TYPE='Movie' AND NL.LISTED_IN IN ('Comedies','Horror Movies');


-- We need the directors and count of each genre movies they created

SELECT ND.DIRECTOR,
COUNT(CASE WHEN NL.LISTED_IN= 'Comedies' THEN NS.SHOW_ID END) AS NO_OF_COMEDY_MOVIES,
COUNT(CASE WHEN NL.LISTED_IN= 'Horror Movies' THEN NS.SHOW_ID END) AS NO_OF_HORROR_MOVIES
FROM NETFLIX_STAGE NS
INNER JOIN NETFLIX_LISTED_IN NL ON NS.show_id=NL.show_id
INNER JOIN NETFLIX_DIRECTOR ND ON NS.show_id=ND.show_id
WHERE TYPE='Movie' AND NL.LISTED_IN IN ('Comedies','Horror Movies')
GROUP BY ND.DIRECTOR
HAVING COUNT(DISTINCT NL.LISTED_IN) = 2;


--------------------------------------------------------------------------------------------------------------------































