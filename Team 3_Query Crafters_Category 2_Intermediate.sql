--QN.1. For each OPO, calculate the total number of referrals per hospital_id (patient table) and identify the hospital with the highest referral count. 
--Use a window function to rank hospitals within each OPO.
WITH hospital_referrals AS (
    SELECT
        p.opo,
        p.hospital_id,
        COUNT(p.patient_id) AS total_referrals
    FROM patient p
    GROUP BY p.opo, p.hospital_id
),
ranked_hospitals AS (
    SELECT
        opo,
        hospital_id,
        total_referrals,
        ROW_NUMBER() OVER (PARTITION BY opo ORDER BY total_referrals DESC) AS rank_within_opo
    FROM hospital_referrals
)
SELECT *
FROM ranked_hospitals
WHERE rank_within_opo <= 3
ORDER BY opo, rank_within_opo;

---QN.2. For each cause_of_death_opo (death_info table), calculate the total number of patients, the number who were authorized and procured (auth_status table),
--and the organ procurement rate as a percentage.
WITH cause_stats AS (
    SELECT
        d.cause_of_death_opo,
        COUNT(p.patient_id) AS total_patients,
        SUM(CASE WHEN a.authorized = TRUE THEN 1 ELSE 0 END) AS total_authorized,
        SUM(CASE WHEN a.procured = TRUE THEN 1 ELSE 0 END) AS total_procured,
        ROUND(
            SUM(CASE WHEN a.procured = TRUE THEN 1 ELSE 0 END) * 100.0 
            / COUNT(p.patient_id), 2
        ) AS procurement_rate
    FROM patient p
    JOIN death_info d
        ON p.patient_id = d.patient_id
    JOIN auth_status a
        ON p.patient_id = a.patient_id
    GROUP BY d.cause_of_death_opo
)

SELECT
    cause_of_death_opo,
    total_patients,
    total_authorized,
    total_procured,
    procurement_rate,
    RANK() OVER (ORDER BY procurement_rate DESC) AS procurement_rank
FROM cause_stats
ORDER BY procurement_rank;

--QN.3. For each OPO and referral_year, calculate the total number of referrals (from the patient table) and compare it with the corresponding calc_deaths 
--(from calc_deaths_cleaned).Compute the difference between actual referrals and calculated deaths, and rank OPOs within each year based on the size of this gap using a window function.

WITH referral_stats AS (
    SELECT
        p.opo,
        p.referral_year,
        COUNT(p.patient_id) AS total_referrals
    FROM patient p
    GROUP BY p.opo, p.referral_year
),
gap_analysis AS (
    SELECT
        r.opo,
        r.referral_year,
        r.total_referrals,
        c.calc_deaths,
        (r.total_referrals - c.calc_deaths) AS referral_death_gap
    FROM referral_stats r
    JOIN calc_deaths_cleaned c
        ON r.opo = c.opo
        AND r.referral_year = c.year
)
SELECT
    opo,
    referral_year,
    total_referrals,
    calc_deaths,
    referral_death_gap,
    RANK() OVER (PARTITION BY referral_year ORDER BY referral_death_gap DESC) AS gap_rank_within_year
FROM gap_analysis
ORDER BY referral_year, gap_rank_within_year;

--QN.4. For each OPO (patient.opo), calculate the average time (in hours) from authorization to procurement using auth_status,
--time_authorized and auth_status.time_procured.

WITH authorization_procurement AS (
    SELECT
        p.opo,
        EXTRACT(EPOCH FROM (a.time_procured - a.time_authorized)) / 3600 AS hours_to_procure
    FROM patient p
    JOIN auth_status a
        ON p.patient_id = a.patient_id
    WHERE a.time_authorized IS NOT NULL
      AND a.time_procured IS NOT NULL
)
SELECT
    opo,
    ROUND(AVG(hours_to_procure), 2) AS avg_hours_authorization_to_procurement,
    RANK() OVER (ORDER BY AVG(hours_to_procure)) AS rank_fastest_opo
FROM authorization_procurement
GROUP BY opo
ORDER BY rank_fastest_opo;

--QN.5. For each OPO, calculate the total number of referrals per referral_year from the patient table and compute the cumulative number of referrals over time. 
WITH yearly_referrals AS (
    SELECT
        opo,
        referral_year,
        COUNT(patient_id) AS total_referrals
    FROM patient
    GROUP BY opo, referral_year
)
SELECT
    opo,
    referral_year,
    total_referrals,
    SUM(total_referrals) OVER (
        PARTITION BY opo
        ORDER BY referral_year
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_referrals
FROM yearly_referrals
ORDER BY opo, referral_year;

--QN.6. For each circumstances_of_death (death_info table), calculate the total number of donors, the number of successfully transplanted cases (auth_status.transplanted), 
--and the transplant success rate as a percentage.
WITH donor_analysis AS (
    SELECT
        d.circumstances_of_death,
        COUNT(*) AS total_donors,
        SUM(CASE WHEN a.transplanted = TRUE THEN 1 ELSE 0 END) AS transplanted_count
    FROM patient p
    JOIN death_info d 
        ON p.patient_id = d.patient_id
    JOIN auth_status a 
        ON p.patient_id = a.patient_id
    GROUP BY d.circumstances_of_death
)
SELECT
    circumstances_of_death,
    total_donors,
    transplanted_count,
    ROUND(
        transplanted_count * 100.0 / NULLIF(total_donors, 0),
        2
    ) AS transplant_rate_percent,
    SUM(transplanted_count) OVER (ORDER BY ROUND(transplanted_count * 100.0 / NULLIF(total_donors, 0), 2) DESC) 
        AS cumulative_transplanted
FROM donor_analysis
ORDER BY transplant_rate_percent DESC;

--QN.7. Find the top 3 hospitals per year by transplant count

WITH hospital_year AS (
SELECT p.procured_year, p.hospital_id,
COUNT(DISTINCT p.patient_id) AS transplanted_patients
FROM patient p
  JOIN auth_status a ON a.patient_id = p.patient_id
  WHERE a.transplanted = true
  AND p.procured_year IS NOT NULL
  AND p.hospital_id IS NOT NULL
  GROUP BY p.procured_year, p.hospital_id
),
ranked AS (
SELECT
  *,
  DENSE_RANK() OVER (PARTITION BY procured_year ORDER BY transplanted_patients DESC) AS hospital_rank
FROM hospital_year
)
SELECT *
FROM ranked
WHERE hospital_rank <= 3
ORDER BY procured_year, hospital_rank, transplanted_patients DESC;

--QN.8. Show month-wise referral counts and month-over-month count change.

WITH month_wise AS (
SELECT
   date_trunc('month', a.time_referred) AS month,
   COUNT(DISTINCT a.patient_id) AS referral_count
FROM auth_status a
WHERE a.time_referred IS NOT NULL
GROUP BY 1
)

SELECT
  month,referral_count,
  LAG(referral_count) OVER (ORDER BY month) AS prev_month_referrals,
  (referral_count - LAG(referral_count) OVER (ORDER BY month)) AS month_over_month_count_change
FROM month_wise
ORDER BY month;


--QN.9. Find year-wise brain-death cases and a running total across years.

WITH totals AS (
  SELECT
    p.procured_year,
    COUNT(DISTINCT d.patient_id) AS brain_death_count
  FROM death_info d
  JOIN patient p ON p.patient_id = d.patient_id
  WHERE d.brain_death = true
    AND p.procured_year IS NOT NULL
  GROUP BY p.procured_year
)
SELECT
  procured_year,
  brain_death_count,
  SUM(brain_death_count) OVER (ORDER BY procured_year) AS running_total
FROM totals
ORDER BY procured_year;

CREATE INDEX IF NOT EXISTS brain_death_patient_info
ON death_info(patient_id)
WHERE brain_death = true;

CREATE INDEX IF NOT EXISTS patient_procured_year
ON patient(procured_year);


--QN.10. Determine the time taken from referral to procurement in hours and categorize patients into predefined time intervals.
		--Calculate the time taken from referral to procurement in hours for each patient 
		--and classify patients into defined time-to-procurement ranges 
		--(0–6 hours, 6–24 hours, 1–3 days, and 3+ days).

select * from auth_status;

SELECT
  a.patient_id,
  p.procured_year,
  ROUND(EXTRACT(EPOCH FROM (a.time_procured - a.time_referred)) / 3600.0, 2) AS referral_to_procurement_hours,
  CASE
    WHEN a.time_procured IS NULL OR a.time_referred IS NULL THEN 'Time Unknown'
    WHEN a.time_procured - a.time_referred <= INTERVAL '6 hours' THEN '0–6 hrs'
    WHEN a.time_procured - a.time_referred <= INTERVAL '24 hours' THEN '6–24 hrs'
    WHEN a.time_procured - a.time_referred <= INTERVAL '72 hours' THEN '1–3 days'
    ELSE '3+ days'
  END AS procurement_time_range
FROM auth_status a
JOIN patient p ON p.patient_id = a.patient_id
ORDER BY p.procured_year;

--QN.11. Find the average time (in hours) taken from referral to authorization for patients.

SELECT
  ROUND(
  AVG(EXTRACT(EPOCH FROM (a.time_authorized - a.time_referred)) / 3600.0),2)
  AS avg_hours_referral_to_auth
FROM auth_status a
WHERE a.time_referred IS NOT NULL
AND a.time_authorized IS NOT NULL;

--QN.12. For each referral year, rank hospitals based on the number of procured patients, with the highest count ranked first.

CREATE INDEX IF NOT EXISTS idx_auth_procured_patient
ON auth_status(patient_id)
WHERE procured = true;

CREATE INDEX IF NOT EXISTS idx_patient_referral_year_hospital
ON patient(referral_year, hospital_id);

WITH hospital AS (
  SELECT p.referral_year, p.hospital_id, COUNT(*) AS procured_count
  FROM patient p
  JOIN auth_status a ON a.patient_id = p.patient_id
  WHERE a.procured = true AND p.referral_year IS NOT NULL
  GROUP BY p.referral_year, p.hospital_id)
SELECT *,
       RANK() OVER (PARTITION BY referral_year ORDER BY procured_count DESC) AS hospital_rank
FROM hospital
ORDER BY referral_year, hospital_rank;

--QN.13. Referral Growth Every Year.

SELECT
    p.referral_year,
    COUNT(*) AS total_referrals,
    ROUND(
        100.0 * 
        (COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY p.referral_year)) / 
        NULLIF(LAG(COUNT(*)) OVER (ORDER BY p.referral_year), 0),   -- LAG Window Function
    2) AS growth_percentage
FROM patient p
GROUP BY p.referral_year
ORDER BY p.referral_year;

--QN.14.Longest time to procurement (dense rank).

SELECT *
FROM (
    SELECT
        patient_id,
        time_procured - time_referred AS delay,
        DENSE_RANK() OVER (ORDER BY time_procured - time_referred DESC) rnk
    FROM auth_status
    WHERE procured = true
) s
WHERE rnk <= 5;

--QN.15.Detect sudden spike in procurement (LEAD difference).

SELECT *,
       LEAD(procured_cnt) OVER (PARTITION BY opo ORDER BY referral_year) - procured_cnt AS next_year_jump
FROM (
    SELECT
        p.opo,
        p.referral_year,
        COUNT(*) AS procured_cnt
    FROM patient p
    JOIN auth_status a USING(patient_id)
    WHERE a.procured
    GROUP BY p.opo, p.referral_year
) s;

--QN.16. Min,Median,Max donor age per OPO (percentile_cont).

SELECT
    opo,
    'minimum age: ' || MIN(age)
    || ', median age: ' ||
       percentile_cont(0.5) WITHIN GROUP (ORDER BY age)
    || ', max age(if age>89 consider as 100): ' || MAX(age) AS age_summary
FROM patient
WHERE age IS NOT NULL
GROUP BY opo
ORDER BY opo;

--QN.17. Generate hospital performance score (composite metric).

SELECT
    p.hospital_id,
    COUNT(*) FILTER (WHERE a.authorized) AS authorized,
    COUNT(*) FILTER (WHERE a.procured) AS procured,
    ROUND(
        0.6 * COUNT(*) FILTER (WHERE a.procured)
      + 0.4 * COUNT(*) FILTER (WHERE a.authorized)
    ,2) AS performance_score
FROM patient p
JOIN auth_status a USING(patient_id)
GROUP BY p.hospital_id
ORDER BY performance_score DESC;

--QN.18. Average time between referral → procurement per hospital.
SELECT
    hospital_id,
    ROUND(AVG(EXTRACT(EPOCH FROM (time_procured - time_referred))/3600),2) AS avg_hours_to_procure
FROM patient p
JOIN auth_status a USING(patient_id)
WHERE a.procured
GROUP BY hospital_id;

--QN.19. Ranking opo's per year along with the avg age of the patient for brain death patient.
select opo,referral_year,total_brain_death_case,rank()over(partition by referral_year order by total_brain_death_case desc )as rank_opo ,avg_age from 
(select p.opo,p.referral_year,count(d.brain_death) as total_brain_death_case, round( avg(p.age),1) as avg_age
from death_info d join patient p on p.patient_id = d.patient_id
where d.brain_death = true group by p.opo,p.referral_year) order by referral_year, rank_opo;

--QN.20. How has the number of brain death cases changed year-over-year for each 
---Organ Procurement Organization (OPO), and which OPOs are seeing an increase, decrease, or no change in cases compared to the previous year? 

select opo,referral_year,total_brain_death_case ,pervious_year_cases, total_brain_death_case-pervious_year_cases as diff_year_cases,
case
when total_brain_death_case-pervious_year_cases >0 then 'increased'
when total_brain_death_case-pervious_year_cases<0 then 'decreased'
else 'no change ' end as trend 
from (select opo,referral_year, total_brain_death_case ,LAG(total_brain_death_case) over(partition by opo order by referral_year)as pervious_year_cases 
from 
(select p.opo,p.referral_year,count(d.brain_death) as total_brain_death_case
from
death_info d join patient p on p.patient_id = d.patient_id
where d.brain_death = true group by p.opo,p.referral_year ))order by referral_year;

--QN.21. What is the proportion of brain death cases contributed by each Organ Procurement Organization
--(OPO) within a given year, and how does each OPO compare to the yearly total? 

 with yearly_cases as (
         select
        p.opo,
        p.referral_year,
        count(*) as total_brain_death_case
		    from death_info d
    join patient p on p.patient_id = d.patient_id
    where d.brain_death = true  group by p.opo, p.referral_year
)

select 
    opo,
    referral_year,
    total_brain_death_case,

    sum(total_brain_death_case) over (
        partition by referral_year
    ) as yearly_total,

    ROUND(
        total_brain_death_case * 100.0 /
        sum(total_brain_death_case) over(partition by referral_year),
        2) as percent_of_year
from yearly_cases
order by  referral_year, opo;

--QN.22. What is the projected change in brain death cases for each Organ Procurement Organization (OPO) 
---by comparing the current year’s total with the next year’s total?

select opo,referral_year,total_brain_death_case ,next_year_cases, next_year_cases - total_brain_death_case as diff_year_cases
from (select opo,referral_year, total_brain_death_case ,Lead(total_brain_death_case) over(partition by opo order by referral_year)as next_year_cases 
from 
(select p.opo,p.referral_year,count(d.brain_death) as total_brain_death_case
from
death_info d join patient p on p.patient_id = d.patient_id
where d.brain_death = true group by p.opo,p.referral_year ))order by referral_year,opo;

--QN.23. Show the difference as after how many days it took to procured the organ after death

select d.brain_death,d.time_brain_death ,a.patient_id,a.time_procured,time_procured-time_brain_death as days_procured
from 
death_info d join auth_status a on a.
patient_id = d.patient_id where brain_death = true ;

---QN.24. Show the difference as after how many days it took to procured the organ after death

select d.brain_death,d.time_brain_death ,a.patient_id,a.time_procured,time_procured-time_brain_death as days_procured
from 
death_info d join auth_status a on a.
patient_id = d.patient_id where brain_death = true ;

--QN.25. How many referrals does each organ type receive?

SELECT outcome_heart, outcome_liver,outcome_kidney_left,outcome_kidney_right,
outcome_lung_left,outcome_lung_right,outcome_intestine,outcome_pancreas, COUNT(*) AS referral_count
FROM referrals
GROUP BY outcome_heart, outcome_liver,outcome_kidney_left,outcome_kidney_right,
outcome_lung_left,outcome_lung_right,outcome_intestine,outcome_pancreas
ORDER BY referral_count DESC;

--QN.26. Compare raw vs cleaned referral counts

WITH src AS (
    SELECT 'raw' AS type, COUNT(*) AS cnt FROM referrals
    UNION ALL
    SELECT 'cleaned', COUNT(*) FROM referrals_cleaned
)
SELECT
    MAX(cnt) FILTER (WHERE type = 'raw')     AS raw_referrals,
    MAX(cnt) FILTER (WHERE type = 'cleaned') AS cleaned_referrals
FROM src;

--QN.27. Identify patients who appear in both patient and calc_deaths

SELECT
    patient_id,
    opo,
    hospital_id,
    death_records
FROM (
    SELECT
        p.patient_id,
        p.opo,
        p.hospital_id,
        COUNT(d.patient_id) OVER (PARTITION BY p.patient_id) AS death_records
    FROM patient p
    LEFT JOIN death_info d USING (patient_id)
) s
WHERE death_records > 0;

--QN.28. Count referrals per patient

SELECT *
FROM (
    SELECT DISTINCT patient_id FROM referrals_cleaned
) p
CROSS JOIN LATERAL (
    SELECT COUNT(*) AS referral_count
    FROM referrals_cleaned r
    WHERE r.patient_id = p.patient_id
) c
ORDER BY referral_count DESC;

--Qn.29. Identify patients with no referrals

WITH referral_stats AS (
    SELECT
        p.patient_id,
        COUNT(r.patient_id) AS referral_count
    FROM patient p
    LEFT JOIN referrals_cleaned r
        ON p.patient_id = r.patient_id
    GROUP BY p.patient_id
)
SELECT patient_id
FROM referral_stats
WHERE referral_count = 0;

--QN.30. Count deaths by mechanism of death

SELECT
    mechanism_of_death,
    COUNT(*) AS total,
    RANK() OVER (ORDER BY COUNT(*) DESC)        
	AS rank_position
FROM death_info
GROUP BY mechanism_of_death
ORDER BY total DESC;







