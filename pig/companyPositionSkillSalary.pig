------------------------------------------- OUTPUT STAGE START -----------------------------------------
-- Load LinkedIn data in JSON type. 
-- => (position, skill, company)
linkedin = LOAD '/Users/longyang/git/RealTimeBigData/data/linkedin/companyPositionSkill.json' 
	USING JsonLoader('position: chararray, skill: chararray, company: chararray');
-- Load LinkedIn data in JSON type. 
-- => (company, industry)
glassdoor = LOAD '/Users/longyang/git/RealTimeBigData/data/glassdoor/CompanyIndustry.json' 
	USING JsonLoader('company: chararray, industry: chararray');
-- Load Glassdoor data in JSON type. 
-- => (position, company, state, salary)
h1b = LOAD '/Users/longyang/git/RealTimeBigData/data/h1b/json/CompanyPositionSalary.json' 
	USING JsonLoader('position: chararray, company: chararray, state: chararray, salary: int');
------------------------------------------- OUTPUT STAGE END -------------------------------------------


------------------------------------------- ANALYSIS STAGE START ---------------------------------------
				---------------------------- DATA PRE-PROCESS START --------------------------
-- Join the glass and h1b
jointGH = JOIN glassdoor by company, h1b by company;
-- => (company, industry, position, state, salary)
cleanJointGH = FOREACH jointGH GENERATE 
	glassdoor::company as company, glassdoor::industry as industry,
	h1b::position as position, h1b::state as state, h1b::salary as salary;
-- Filter to left 'IT' companies. 
-- => (company, industry, position, state, salary)
itCompanies = FILTER cleanJointGH by industry MATCHES 'information technology';
-- Got the (company, position, state, salary) information only for IT companies.
-- => <(ompany, position, state, salary)
h1bIT = FOREACH itCompanies GENERATE company, position, state, salary;

-- Filter the h1b data with limitation of salary not more than 500,000
-- => (company, position, state, salary)
h1bIT = FILTER h1bIT BY salary < 500000;
-- Join linkedin and h1b data 
jointHL = JOIN h1bIT BY (position, company), linkedin BY (position, company);
-- Clear the joint data. 
-- => (company, position, salary, skill, state)
cleanJointHL = FOREACH jointHL GENERATE  
	linkedin::company AS company, linkedin::position AS position, 
	h1bIT::salary AS salary, linkedin::skill AS skill, h1bIT::state as state;
				---------------------------- DATA PRE-PROCESS END ----------------------------
-- We get the join data from H1B and LinkedIn => 'cleanJointHL' is the real big thing.
-- => (company, position, salary, skill, state)

				---------------------------- DATA PROCESS START ------------------------------
-- 1. Group the data by skill
groupedBySkill = GROUP cleanJointHL BY skill;
-- Clean up the grouped data
-- => (skill, {(tuple:(company, position, salary, skill))})
cleanGroupedBySkill = FOREACH groupedBySkill GENERATE group AS skill, 
	cleanJointHL AS (cleanJointHL: 
		{info: tuple(company: chararray, position: chararray, salary: int, skill: chararray, state: chararray)});
-- Filter the groups with less than 5 entities
cleanGroupedBySkill = FILTER  cleanGroupedBySkill BY COUNT(cleanJointHL) > 300;
-- Generate the only skill-salarys relation
-- => (skill, {tuple:(salary)})
skillSalarys = FOREACH cleanGroupedBySkill GENERATE skill, 
	cleanJointHL.salary as (salarys: {info: tuple(salary: int)});

-- 2. Group the data by state and skill
groupedByStateSkill = GROUP cleanJointHL BY (state, skill);
-- Clean up the grouped data
-- => (state, skill, salarys)
cleanGroupedByStateSkill = FOREACH groupedByStateSkill {
	salarys = FOREACH cleanJointHL GENERATE salary;
	GENERATE FLATTEN(group) as (state, skill), salarys as salarys;
};

-- 2.1 Group the previous data by state again.
groupedByState = GROUP cleanGroupedByStateSkill BY state;
cleanGroupedByState = FOREACH groupedByState {
	base = FILTER cleanGroupedByStateSkill BY COUNT(salarys) > 100;
	A = FOREACH base GENERATE skill, (int)AVG(salarys) as avgSalary;
	sortedA = ORDER A BY avgSalary DESC;
	sortedA = LIMIT sortedA 30;
	B = FOREACH base GENERATE skill, COUNT(salarys) as count;
	sortedB = ORDER B BY count DESC;
	sortedB = LIMIT sortedB 30;
	GENERATE group as state, sortedA as top5Salary, sortedB as top5Count;
};

-- 3.1. Group the previous data by company.
groupedbyCompany = GROUP cleanJointHL by company;
cleanGroupedByCompany = FOREACH groupedbyCompany {
	salarys = FOREACH cleanJointHL GENERATE salary;
	GENERATE group as company, (int)AVG(salarys) as avgSalary, COUNT(salarys) as count;
};
cleanGroupedByCompany = ORDER cleanGroupedByCompany BY avgSalary DESC;
cleanGroupedByCompany = LIMIT cleanGroupedByCompany 1000;

-- 3.2. Group the previous data by (company, position)
jointCompany = JOIN cleanGroupedByCompany by company, cleanJointHL by company;
cleanJointCompany = FOREACH jointCompany GENERATE 
	cleanGroupedByCompany::company as company, cleanJointHL::position as position,
	cleanJointHL::skill as skill, cleanJointHL::salary as salary;
groupedByCompanyPosition = GROUP cleanJointCompany by (company, position);
cleanGroupedByCompanyPosition = FOREACH groupedByCompanyPosition {
	salarys = FOREACH cleanJointCompany GENERATE salary;
	averageSalary = (int) AVG(salarys);
	GENERATE FLATTEN(group) as (company, position), averageSalary as avgSalary;
};
groupedByCompany1 = GROUP cleanGroupedByCompanyPosition by company;
cleanGroupedBYCompany1 = FOREACH groupedByCompany1 {
	A = FOREACH cleanGroupedByCompanyPosition GENERATE position, (int)avgSalary as avgSalary;
	rankedGrouped = ORDER A BY avgSalary DESC;
	rankedGroupedTop10 = LIMIT rankedGrouped 10;
	GENERATE group as company, rankedGroupedTop10 as topPositions;
};
cleanGroupedBYCompany1 = FILTER cleanGroupedBYCompany1 BY COUNT(topPositions) > 4;

-- 3.3. Group the previous data by (company, position, skill)
groupedByCompanyPositionSkill = GROUP cleanJointCompany by (company, position, skill);
cleanGroupedByCPS = FOREACH groupedByCompanyPositionSkill {
	salarys = FOREACH cleanJointCompany GENERATE salary;
	GENERATE FLATTEN(group) as (company, position, skill), (int)AVG(salarys) as avgSalary; 
};
groupedByCompanyPosition2 = GROUP cleanGroupedByCPS by (company, position);
cleanGroupedByCP = FOREACH groupedByCompanyPosition2 {
	A = FOREACH cleanGroupedByCPS GENERATE skill, avgSalary;
	GENERATE FLATTEN(group) as (company, position), A as skills;
};


				---------------------------- DATA PROCESS END --------------------------------
------------------------------------------- ANALYSIS STAGE END -----------------------------------------


------------------------------------------- OUTPUT STAGE -----------------------------------------------
-- 1. Generate skill and average salary pair in order based on average salary.
-- => (skill, averageSalary)
skillAverageSalary = FOREACH skillSalarys GENERATE skill, AVG(salarys.salary) as averageSalary;
-- Sort the skill based on average salary
sortedSkillAverageSalary = ORDER skillAverageSalary BY averageSalary DESC;

-- 2. Generate the skills and skill counts in order based on salary count.
-- Compute the counts for each skills
-- => (skill, count)
skillCounts = FOREACH cleanGroupedBySkill GENERATE skill, COUNT(cleanJointHL) AS count;
-- Sort the skills with counts in descending order.
sortedSkillCounts = ORDER skillCounts BY count DESC;

-- 3. Store the data
-- STORE cleanGroupedBySkill INTO '/Users/longyang/git/RealTimeBigData/data/test5/grouped' USING JsonStorage();
-- STORE skillSalarys INTO '/Users/longyang/git/RealTimeBigData/data/test5/skillSalarys' USING JsonStorage();
-- STORE sortedSkillCounts INTO '/Users/longyang/git/RealTimeBigData/data/test5/sortedSkillCounts' USING JsonStorage();
-- STORE sortedSkillAverageSalary INTO '/Users/longyang/git/RealTimeBigData/data/test5/sortedSkillAverageSalary' USING JsonStorage();
-- STORE cleanGroupedByStateSkill INTO '/Users/longyang/git/RealTimeBigData/data/test5/groupedByStateSkill' USING JsonStorage();
-- STORE cleanGroupedByState INTO '/Users/longyang/git/RealTimeBigData/data/test5/groupedByState' USING JsonStorage();
STORE cleanJointHL INTO '/Users/longyang/git/RealTimeBigData/data/test6/cleanJointHL' USING JsonStorage();
STORE cleanGroupedByCompany INTO '/Users/longyang/git/RealTimeBigData/data/test6/groupedbyCompany' USING JsonStorage();
STORE cleanGroupedBYCompany1 INTO '/Users/longyang/git/RealTimeBigData/data/test6/groupedbyCompany1' USING JsonStorage();
STORE cleanGroupedByCP INTO '/Users/longyang/git/RealTimeBigData/data/test6/cleanGroupedByCP' USING JsonStorage();
------------------------------------------- OUTPUT STAGE END -------------------------------------------
