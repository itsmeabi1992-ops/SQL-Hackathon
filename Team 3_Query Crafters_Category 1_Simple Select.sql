--QN.1.Using the patient table and the calc_deaths_cleaned table, for each opo and referral_year, 
--calculate the total number of referrals (count of patient_id) and display it alongside the calc_deaths from calc_deaths_cleaned (matched by opo and year).
--Then determine which opo had the largest difference between total referrals and calc_deaths for a given year.

SELECT
    p.opo,
    p.referral_year,
    COUNT(p.patient_id) AS total_referrals,
    c.calc_deaths,
    COUNT(p.patient_id) - c.calc_deaths AS difference
FROM
    patient p
JOIN
    calc_deaths_cleaned c
    ON p.opo = c.opo
    AND p.referral_year = c.year
GROUP BY
    p.opo,
    p.referral_year,
    c.calc_deaths
ORDER BY
    difference DESC;
	
--QN.2.Create age categories (<20, 20–39, 40–59, 60+). For each age category, count the number of patients declared brain-dead (brain_death) and the number of those whose organs were transplanted (transplanted).
-- Display the results in descending order by the number of brain-dead patients.

SELECT
    CASE 
        WHEN p.age < 20 THEN '<20'
        WHEN p.age BETWEEN 20 AND 39 THEN '20-39'
        WHEN p.age BETWEEN 40 AND 59 THEN '40-59'
        ELSE '60+'
    END AS age_group,
    COUNT(*) AS brain_dead_count,
    SUM(CASE 
            WHEN a.transplanted = 'true' THEN 1
            ELSE 0
        END) AS transplanted_count
FROM patient p
JOIN death_info d
    ON p.patient_id = d.patient_id
JOIN auth_status a
    ON p.patient_id = a.patient_id
WHERE d.brain_death = 'true'
GROUP BY age_group
ORDER BY brain_dead_count DESC;

--QN.3.For each ABO_BloodType, calculate the percentage of referrals that were authorized and procured.
-- Return the blood type, total referrals, total authorized, total procured, and the percentages.

SELECT
    b.abo_blood_type AS abo_bloodtype,
    COUNT(*) AS total_referrals,
    SUM(CASE WHEN a.authorized = TRUE THEN 1 ELSE 0 END) AS total_authorized,
    SUM(CASE WHEN a.procured = TRUE THEN 1 ELSE 0 END) AS total_procured,
    ROUND(SUM(CASE WHEN a.authorized = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS percent_authorized,
    ROUND(SUM(CASE WHEN a.procured = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS percent_procured
FROM patient p
JOIN blood_tissue b
    ON p.patient_id = b.patient_id
JOIN auth_status a
    ON p.patient_id = a.patient_id
GROUP BY b.abo_blood_type
ORDER BY total_referrals;

--QN.4.Calculate the average time (in hours) from time_referred → time_approached → time_procured for each OPO. 
--Which OPO has the fastest average approach-to-procurement time?

SELECT
    p.opo,
    ROUND(AVG(EXTRACT(EPOCH FROM (a.time_approached - a.time_referred)) / 3600), 2) 
        AS avg_hours_referral_to_approach,
    ROUND(AVG(EXTRACT(EPOCH FROM (a.time_procured - a.time_approached)) / 3600), 2) 
        AS avg_hours_approach_to_procurement
FROM patient p
JOIN auth_status a
    ON p.patient_id = a.patient_id
WHERE a.time_referred IS NOT NULL
  AND a.time_approached IS NOT NULL
  AND a.time_procured IS NOT NULL
GROUP BY p.opo
ORDER BY avg_hours_approach_to_procurement ASC;

--QN.5. Categorize patients into age groups (Minor, Adult, Senior).

select age from patient where age is null;

SELECT
  patient_id,
  age,
  CASE
    WHEN age IS NULL THEN 'Unknown'
    WHEN age < 18 THEN 'Minor'
    WHEN age BETWEEN 18 AND 64 THEN 'Adult'
    ELSE 'Senior'
  END AS age_group
FROM patient;


--QN.6. Count the number of brain death cases year-wise.

SELECT p.procured_year,
COUNT(DISTINCT d.patient_id) AS brain_death_count
FROM death_info d
JOIN patient p
ON d.patient_id = p.patient_id
WHERE d.brain_death = true
AND p.procured_year IS NOT NULL
GROUP BY p.procured_year
ORDER BY p.procured_year;


--QN.7.  Find the race which has the highest transplant rate?

SELECT p.race,
ROUND(SUM(CASE WHEN a.transplanted = true THEN 1 ELSE 0 END) * 100.0/ COUNT(*),2) 
AS transplant_rate_percentage
FROM patient p
JOIN auth_status a
ON p.patient_id = a.patient_id
WHERE p.race IS NOT NULL
GROUP BY p.race
ORDER BY transplant_rate_percentage DESC
LIMIT 1;


--QN.8.  Find Year-wise number of brain-dead donors who had at least one organ transplanted.

SELECT p.procured_year,
COUNT(DISTINCT di.patient_id) AS brain_death_transplanted_cases
FROM death_info di
JOIN patient p
ON p.patient_id = di.patient_id
JOIN organ_outcome oo
ON oo.patient_id = di.patient_id
WHERE di.brain_death = true
AND p.procured_year IS NOT NULL
AND (
    oo.outcome_heart = 'Transplanted' OR
    oo.outcome_liver = 'Transplanted' OR
    oo.outcome_kidney_left = 'Transplanted' OR
    oo.outcome_kidney_right = 'Transplanted' OR
    oo.outcome_lung_left = 'Transplanted' OR
    oo.outcome_lung_right = 'Transplanted' OR
    oo.outcome_pancreas = 'Transplanted' OR
    oo.outcome_intestine = 'Transplanted'
  )
GROUP BY p.procured_year
ORDER BY p.procured_year;

--QN.9. Count transplanted organs per year.

SELECT 
    p.referral_year,
    SUM(CASE WHEN o.outcome_heart = 'Transplanted' THEN 1 ELSE 0 END) 
        AS transplanted_hearts_count,
	SUM(CASE WHEN o.outcome_liver = 'Transplanted' THEN 1 ELSE 0 END) 
        AS transplanted_livers_count,
    SUM(CASE WHEN o.outcome_kidney_left = 'Transplanted' THEN 1 ELSE 0 END) +
    SUM(CASE WHEN o.outcome_kidney_right = 'Transplanted' THEN 1 ELSE 0 END) 
        AS transplanted_kidneys_count,
    SUM(CASE WHEN o.outcome_lung_left = 'Transplanted' THEN 1 ELSE 0 END) +
    SUM(CASE WHEN o.outcome_lung_right = 'Transplanted' THEN 1 ELSE 0 END) 
        AS transplanted_lungs_count,
    SUM(CASE WHEN o.outcome_intestine = 'Transplanted' THEN 1 ELSE 0 END) 
        AS transplanted_intestine_count,
    SUM(CASE WHEN o.outcome_pancreas = 'Transplanted' THEN 1 ELSE 0 END) 
        AS transplanted_pancreas_count
FROM patient p
JOIN organ_outcome o 
    ON p.patient_id = o.patient_id
JOIN auth_status a
    ON p.patient_id = a.patient_id
WHERE a.transplanted = 'Yes'
GROUP BY p.referral_year
ORDER BY p.referral_year;

--QN.10. Top 5 causes of death per year.

SELECT 
    d.cause_of_death_opo,
    COUNT(*) AS total
FROM death_info d
JOIN patient p 
    ON d.patient_id = p.patient_id
GROUP BY d.cause_of_death_opo
ORDER BY total DESC
LIMIT 5;

--QN.11. Procurement rate (%) per OPO.

SELECT 
    p.opo,
    ROUND(
        100.0 * SUM(CASE WHEN a.procured = 'Yes' THEN 1 ELSE 0 END) 
        / COUNT(*), 
        2
    ) AS procurement_rate
FROM patient p
JOIN auth_status a
    ON p.patient_id = a.patient_id
GROUP BY p.opo
ORDER BY procurement_rate DESC;

--QN.12. Heart Transplantation Success rate.

SELECT
    p.opo,
    ROUND(
        100.0 *
        SUM(CASE WHEN o.outcome_heart = 'Transplanted' THEN 1 ELSE 0 END) /
        NULLIF(SUM(CASE WHEN a.procured = 'Yes' THEN 1 ELSE 0 END), 0),
    2) AS heart_utilization_pct
FROM patient p
JOIN auth_status a
    ON p.patient_id = a.patient_id
JOIN organ_outcome o
    ON p.patient_id = o.patient_id
GROUP BY p.opo
ORDER BY p.opo;

--QN.13. How many patients with brain death?

select * from public.death_info where brain_death = true;

select count (patient_id ) as total_brain_death_cases from public.death_info where brain_death = true;

--QN.14. Write a query to list all brain death cases along with their organ outcomes and referral year.

select d.patient_id, d.brain_death ,p.referral_year,o.outcome_heart, o.outcome_liver,
o.outcome_kidney_left,o.outcome_kidney_right,
o.outcome_lung_left,	o.outcome_intestine,outcome_pancreas,p.referral_year 
from death_info d join organ_outcome o on o.patient_id = d.patient_id
join patient p on p.patient_id = o.patient_id where d.brain_death = true;

--QN.15. Find the total number if brain death cases per opo per year and average age
select  p.opo,p.referral_year,count(d.patient_id) as total_brain_death_cases,round( avg(p.age),1) as avg_age
    from death_info d
    join patient p 
        on p.patient_id = d.patient_id
    where d.brain_death = TRUE
    GROUP BY p.opo, p.referral_year order by total_brain_death_cases desc;

--QN.16. Counting how many organs were transplanted and categorize the donor category into multi - organ donor , single organ-donor and No utilization.	
 SELECT 
    patient_id,
    opo,
    referral_year,
    organs_transplanted,
    
    CASE 
        WHEN organs_transplanted > 3 THEN 'Multi-Organ Donor'
        WHEN organs_transplanted = 1 THEN 'Single Organ Donor'
        ELSE 'No Utilization'
    END AS donor_category

FROM (
    SELECT 
        d.patient_id,
        p.opo,
        p.referral_year,
                       (
            (CASE WHEN o.outcome_heart = 'Transplanted' THEN 1 ELSE 0 END) +
            (CASE WHEN o.outcome_liver = 'Transplanted' THEN 1 ELSE 0 END) +
            (CASE WHEN o.outcome_kidney_left = 'Transplanted' THEN 1 ELSE 0 END) +
            (CASE WHEN o.outcome_kidney_right = 'Transplanted' THEN 1 ELSE 0 END) +
            (CASE WHEN o.outcome_lung_left = 'Transplanted' THEN 1 ELSE 0 END) +
            (CASE WHEN o.outcome_lung_right = 'Transplanted' THEN 1 ELSE 0 END) +
            (CASE WHEN o.outcome_intestine = 'Transplanted' THEN 1 ELSE 0 END) +
            (CASE WHEN o.outcome_pancreas = 'Transplanted' THEN 1 ELSE 0 END)
        ) AS organs_transplanted

    FROM death_info d
    JOIN organ_outcome o
        ON o.patient_id = d.patient_id
    JOIN patient p
        ON p.patient_id = d.patient_id
    WHERE d.brain_death = TRUE
) sub
ORDER BY opo, referral_year;

--17. How many referrals exist in the ORCHID dataset?

SELECT
    COUNT(p.patient_id) AS total_referrals,
    SUM(CASE WHEN a.authorized = 'true' THEN 1 ELSE 0 END) AS authorized_referrals,
    SUM(CASE WHEN a.authorized = 'false' THEN 1 ELSE 0 END) AS not_authorized_referrals
FROM patient p
LEFT JOIN auth_status a
    ON p.patient_id = a.patient_id;

---18. List all unique organ types referred

SELECT
    p.opo,
    COUNT(*) AS total_patients,
    SUM(CASE WHEN o.outcome_heart = 'Transplanted' THEN 1 ELSE 0 END) AS heart_tx
FROM organ_outcome o
JOIN patient p
    ON o.patient_id = p.patient_id
GROUP BY p.opo
ORDER BY heart_tx DESC;

--19. Count total patients

SELECT
    UPPER(opo) AS opo_name,
    COUNT(*) AS total_patients,
    ROUND(AVG(age), 1) AS avg_age,
    SUM(CASE WHEN gender = 'Male' THEN 1 ELSE 0 END) AS male_count,
    SUM(CASE WHEN gender = 'Female' THEN 1 ELSE 0 END) AS female_count
FROM patient
WHERE age >= 18
GROUP BY UPPER(opo)
ORDER BY total_patients DESC;

--20.List all blood types recorded in blood_tissue

SELECT
    abo_blood_type,
    COUNT(*) AS total_patients,
    SUM(CASE WHEN abo_rh = '+' THEN 1 ELSE 0 END) AS positive_rh,
    SUM(CASE WHEN abo_rh = '-' THEN 1 ELSE 0 END) AS negative_rh
FROM blood_tissue
WHERE abo_blood_type IS NOT NULL
GROUP BY abo_blood_type
ORDER BY total_patients DESC;









