-- Checking the CovidDeaths data table
SELECT TOP 10 *
FROM PortfolioProject..CovidDeaths;

-- Changing the date column's format from datetime to date (since the time part is not useful)
ALTER TABLE CovidDeaths
ALTER COLUMN date date;

-- Changing the total_deaths and new_deaths columns' format from nvarchar, which is incorrect and may lead to misunderstanding, to int
ALTER TABLE CovidDeaths
ALTER COLUMN total_deaths int;

ALTER TABLE CovidDeaths
ALTER COLUMN new_deaths int;

-- NOTE: ALTER TABLE will change the original data permanently. Thus, it is not recommended to use with company database. Instead, we can use CAST function in SELECT statement.

-- Checking the date on which the first case occurred in Vietnam
SELECT location, MIN(date) first_case_date
FROM PortfolioProject..CovidDeaths
WHERE location = 'Vietnam ' AND new_cases != 0
GROUP BY location

-- According to the query above, the first case occurred in Vietnam was on 2020-01-23. Let's see when the death started and how the death rate has been since then
SELECT location, date, total_cases, new_cases, total_deaths, new_deaths, (total_deaths/total_cases)*100 deathrate
FROM PortfolioProject..CovidDeaths
WHERE  location = 'Vietnam' AND (total_deaths/total_cases)*100 IS NOT NULL
ORDER BY 2

-- We can compare the highest infection count per population between countries
SELECT location, MAX(total_cases/population)*100 inf_rate_per_pop
FROM PortfolioProject..CovidDeaths
GROUP BY location
ORDER BY 2 DESC

-- As well as the highest death count per population between countries
SELECT location, MAX(total_deaths/population)*100 death_rate_per_pop
FROM PortfolioProject..CovidDeaths
GROUP BY location
ORDER BY 2 DESC

-- Seeing that continent column contains null values. After checking, we know that the locations are aggregations of various related countries
SELECT DISTINCT location
FROM PortfolioProject..CovidDeaths
WHERE continent IS NULL
-- We can delete them from table with DELETE FROM statement (not recommended when using with company database). Or we can just add a condition which is 'continent IS NOT NULL' to WHERE clause to filter out the null continents.

-- Let's see which continent has the highest death count
SELECT continent, SUM(new_deaths) total_deaths
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY 2 DESC

-- Let's join CovidDeaths and CovidVaccinations tables together.
-- Since the two tables have many-to-many relationship (because they were split up from one table in order to pratice JOIN, so there is no primary key and foreign key), we will join them on both location and date columns
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
FROM PortfolioProject..CovidDeaths dea
INNER JOIN PortfolioProject..CovidVaccinations vac
ON dea.location = vac.location
	AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
ORDER BY 2, 3

-- We can create total_vaccinations column which is cumulative sum of new_vaccinations column with PARTITION BY
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
	SUM(CAST(vac.new_vaccinations AS bigint)) OVER (PARTITION BY dea.location ORDER BY dea.date) total_vaccinations
FROM PortfolioProject..CovidDeaths dea
INNER JOIN PortfolioProject..CovidVaccinations vac
ON dea.location = vac.location
	AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
ORDER BY 2, 3

-- In order to calculate vaccination rate per population, we can put the calculation directly into the above SELECT statement
-- However, instead of being able to take advantage of the newly created column named total_vaccinations, we have to rewrite the whole calculation
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
	SUM(CAST(vac.new_vaccinations AS bigint)) OVER (PARTITION BY dea.location ORDER BY dea.date) total_vaccinations,
	((SUM(CAST(vac.new_vaccinations AS bigint)) OVER (PARTITION BY dea.location ORDER BY dea.date))/dea.population)*100 vac_rate_per_pop
FROM PortfolioProject..CovidDeaths dea
INNER JOIN PortfolioProject..CovidVaccinations vac
ON dea.location = vac.location
	AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
ORDER BY 2, 3

-- This will be very time-consuming as well as hard to read if we need to make several calculations
-- We can solve the problem by creating either CTE or a temp table or a view
-- Solution 1: Creating CTE

WITH PopvsVac (continent, location, date, population, new_vacc, total_vacc) AS
(
	SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
		SUM(CAST(vac.new_vaccinations AS bigint)) OVER (PARTITION BY dea.location ORDER BY dea.date) total_vaccinations
	FROM PortfolioProject..CovidDeaths dea
	INNER JOIN PortfolioProject..CovidVaccinations vac
	ON dea.location = vac.location
		AND dea.date = vac.date
	WHERE dea.continent IS NOT NULL
)
SELECT *, (total_vacc/population)*100 vac_rate_per_pop
FROM PopvsVac
ORDER BY 2, 3

-- Solution 2: Creating a temp table
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
	SUM(CAST(vac.new_vaccinations AS bigint)) OVER (PARTITION BY dea.location ORDER BY dea.date) total_vaccinations
INTO #VacVsPop
FROM PortfolioProject..CovidDeaths dea
INNER JOIN PortfolioProject..CovidVaccinations vac
ON dea.location = vac.location
	AND dea.date = vac.date
WHERE dea.continent IS NOT NULL

SELECT *, (total_vaccinations/population)*100 vac_rate_per_pop
FROM #VacVsPop
ORDER BY 2, 3

DROP TABLE #VacVsPop -- Deleting temp table

-- Solution 3: Creating a view
CREATE VIEW VacVsPop AS
	SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
		SUM(CAST(vac.new_vaccinations AS bigint)) OVER (PARTITION BY dea.location ORDER BY dea.date) total_vaccinations
	FROM PortfolioProject..CovidDeaths dea
	INNER JOIN PortfolioProject..CovidVaccinations vac
	ON dea.location = vac.location
		AND dea.date = vac.date
	WHERE dea.continent IS NOT NULL

SELECT *, (total_vaccinations/population)*100 vac_rate_per_pop
FROM VacVsPop
ORDER BY 2, 3

DROP VIEW VacVsPop -- Deleting view