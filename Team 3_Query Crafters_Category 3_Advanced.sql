--QN.1. How effectively are different OPOs converting potential organ donors into procured organs in a given year, 
-- which OPOs are underperforming or high-risk based on the conversion rate of actual procurements relative to calculated deaths?

---Create Stored Procedure-----
CREATE OR REPLACE PROCEDURE sp_opo_intelligence(
    IN p_year INT,
    INOUT result_cursor REFCURSOR
)
LANGUAGE plpgsql
AS $$
BEGIN
    OPEN result_cursor FOR
    SELECT 
        c.opo,
        c.year,
        c.calc_deaths,
        COUNT(p.patient_id) AS total_referrals,
        SUM(CASE WHEN a.authorized = 'Y' THEN 1 ELSE 0 END) AS total_authorized,
        SUM(CASE WHEN a.procured = 'Y' THEN 1 ELSE 0 END) AS total_procured,
        ROUND(
            SUM(CASE WHEN a.procured = 'Y' THEN 1 ELSE 0 END)::numeric
            / NULLIF(c.calc_deaths,0) * 100, 2
        ) AS conversion_rate_percent,
        CASE
            WHEN SUM(CASE WHEN a.procured = 'Y' THEN 1 ELSE 0 END)::numeric 
                 / NULLIF(c.calc_deaths,0) < 0.40 
            THEN 'HIGH RISK – Underperforming'
            WHEN SUM(CASE WHEN a.procured = 'Y' THEN 1 ELSE 0 END)::numeric 
                 / NULLIF(c.calc_deaths,0) < 0.60
            THEN 'MODERATE RISK'
            ELSE 'STABLE PERFORMANCE'
        END AS opo_status
    FROM calc_deaths_cleaned c
    LEFT JOIN patient p 
        ON p.opo = c.opo AND p.referral_year = c.year
    LEFT JOIN auth_status a 
        ON p.patient_id = a.patient_id
    WHERE c.year = p_year
    GROUP BY c.opo, c.year, c.calc_deaths
    ORDER BY conversion_rate_percent ASC;
END;
$$;

----calling procudure--------
BEGIN;
-- declare the cursor variable
CALL sp_opo_intelligence(2015, 'opo_cursor');

-- fetch all rows
FETCH ALL FROM opo_cursor;

-- close the cursor
CLOSE opo_cursor;
COMMIT;

--QN.2. "How can we quantitatively assess the suitability of potential organ donors based on age, BMI, and brain death status, and 
--which donors score highest for successful organ procurement?

--Step 1:Stored Procedure to calculate suitability-------
CREATE OR REPLACE PROCEDURE sp_donor_suitability(
    IN p_year INT,
    INOUT result_cursor REFCURSOR
)
LANGUAGE plpgsql
AS $$
BEGIN
    OPEN result_cursor FOR
    SELECT 
        p.patient_id,
        p.opo,
        p.age,
        ROUND(p.weight_kg / NULLIF(POWER(p.height_in * 0.0254, 2),0), 2) AS bmi,
        d.brain_death,
        (
          CASE WHEN p.age BETWEEN 18 AND 50 THEN 1 ELSE 0 END
        + CASE WHEN (p.weight_kg / NULLIF(POWER(p.height_in * 0.0254, 2),0)) BETWEEN 18.5 AND 30 THEN 1 ELSE 0 END
        + CASE WHEN d.brain_death = TRUE THEN 1 ELSE 0 END
        ) AS suitability_score,
        a.procured
    FROM patient p
    LEFT JOIN death_info d 
        ON p.patient_id = d.patient_id
    LEFT JOIN auth_status a
        ON p.patient_id = a.patient_id
    WHERE p.referral_year = p_year
    ORDER BY suitability_score DESC, a.procured DESC;
END;
$$;
------step 2 Execute and call the procedure------
BEGIN;
CALL sp_donor_suitability(2015, 'donor_cursor');

--Step 3: Fetch all rows from the cursor--

FETCH ALL FROM "donor_cursor";

--Step 4:  Close the cursor and Commit-----

CLOSE donor_cursor;

Commit;



---QN.3. How can we ensure that the organ donation workflow is followed correctly, 
--preventing invalid state transitions such as authorization without approach, procurement without authorization, or transplant without procurement?

-- Step 1a: Create trigger function
CREATE OR REPLACE FUNCTION trg_enforce_donation_workflow()
RETURNS TRIGGER AS $$
BEGIN
    -- Cannot authorize if not approached
    IF NEW.authorized = 'Y' AND NEW.approached <> 'Y' THEN
        RAISE EXCEPTION 'Authorization requires prior approach';
    END IF;

    -- Cannot procure if not authorized
    IF NEW.procured = 'Y' AND NEW.authorized <> 'Y' THEN
        RAISE EXCEPTION 'Procurement requires authorization';
    END IF;

    -- Cannot transplant if not procured
    IF NEW.transplanted = 'Y' AND NEW.procured <> 'Y' THEN
        RAISE EXCEPTION 'Transplant requires procurement';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 2: Create trigger on auth_status table
CREATE TRIGGER enforce_full_workflow
BEFORE UPDATE ON auth_status
FOR EACH ROW
EXECUTE FUNCTION trg_enforce_donation_workflow();

---step 3 Test valid and invalid updates----

-- Step 3a: Mark patient as approached
UPDATE auth_status
SET approached = 'Y'
WHERE patient_id = 'OPO4_P91001';

-- Step 3b: Authorize (valid because approached = 'Y')
UPDATE auth_status
SET authorized = 'Y'
WHERE patient_id = 'OPO4_P91001';

-- Step 3c: Procure (valid because authorized = 'Y')
UPDATE auth_status
SET procured = 'Y'
WHERE patient_id = 'OPO4_P91001';

-- Step 3d: Transplant (valid because procured = 'Y')
UPDATE auth_status
SET transplanted = 'Y'
WHERE patient_id = 'OPO4_P91001';


-- step 4 :Try to authorize without approach
UPDATE auth_status
SET authorized = 'Y'
WHERE patient_id = 'OPO4_P526923';  

----step 5 verifying table after updates----
SELECT * FROM auth_status
WHERE patient_id IN (
    'OPO4_P91001',
    'OPO4_P526923',
    'OPO5_P583731',
    'OPO3_P815387'
);

--QN.4.  Create a user-defined function that takes a patient_id as input and returns 
--TRUE if the patient had at least one organ transplanted, otherwise returns FALSE.

select * from patient;

CREATE OR REPLACE FUNCTION has_any_transplant(p_patient_id text)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN EXISTS (
    SELECT p_patient_id
    FROM organ_outcome oo
    WHERE oo.patient_id = p_patient_id
      AND (
        oo.outcome_heart = 'Transplanted'
        OR oo.outcome_liver = 'Transplanted'
        OR oo.outcome_kidney_left = 'Transplanted'
        OR oo.outcome_kidney_right = 'Transplanted'
        OR oo.outcome_lung_left = 'Transplanted'
        OR oo.outcome_lung_right = 'Transplanted'
        OR oo.outcome_intestine = 'Transplanted'
        OR oo.outcome_pancreas = 'Transplanted'
      )
  );
END;
$$;

SELECT has_any_transplant('OPO3_P815387');
SELECT has_any_transplant ('OPO5_P385698');

SELECT *
FROM organ_outcome
WHERE patient_id = 'OPO3_P815387';

SELECT *
FROM organ_outcome
WHERE patient_id = 'OPO5_P385698';

--QN.5. Create a user-defined function that takes a patient_id as input and returns TRUE if the patient
--was declared brain-dead AND had at least one organ transplanted, otherwise returns FALSE

CREATE OR REPLACE FUNCTION brain_death_with_transplant(p_patient_id text)
RETURNS BOOLEAN
LANGUAGE sql
AS $$
  SELECT
    EXISTS (
      SELECT p_patient_id
      FROM death_info d
      JOIN organ_outcome oo
        ON oo.patient_id = d.patient_id
      WHERE d.patient_id = p_patient_id
        AND d.brain_death = TRUE
        AND 'Transplanted' IN (
          oo.outcome_heart,
          oo.outcome_liver,
          oo.outcome_kidney_left,
          oo.outcome_kidney_right,
          oo.outcome_lung_left,
          oo.outcome_lung_right,
          oo.outcome_intestine,
          oo.outcome_pancreas
        )
    );
$$;

SELECT brain_death_with_transplant('OPO5_P385698');

SELECT brain_death_with_transplant('OPO3_P815387');

--QN.6. Create a user-defined function that takes a patient_id and returns TRUE if the time between 
--authorization and procurement is ≤ 24 hours, otherwise returns FALSE.

CREATE OR REPLACE FUNCTION is_procured_within_24_hours(p_patient_id text)
RETURNS BOOLEAN
LANGUAGE sql
AS $$
  SELECT EXISTS (
      SELECT p_patient_id
      FROM auth_status a
      WHERE a.patient_id = p_patient_id
        AND a.time_authorized IS NOT NULL
        AND a.time_procured IS NOT NULL
        AND (a.time_procured - a.time_authorized) <= INTERVAL '24 hours'
    );
$$;

SELECT is_procured_within_24_hours('OPO5_P385698');
SELECT is_procured_within_24_hours('OPO3_P815387');

--QN.7. Stored procedure: Generate summary report per OPO.

CREATE OR REPLACE FUNCTION get_opo_report()
RETURNS TABLE(
    opo text,
    total_patients int,
    total_authorized int,
    total_procured int,
    procured_pct numeric
)
AS $$
SELECT
    p.opo,
    COUNT(*),
    COUNT(*) FILTER (WHERE a.authorized),
    COUNT(*) FILTER (WHERE a.procured),
    ROUND(
        100.0 *
        COUNT(*) FILTER (WHERE a.procured)
        / NULLIF(COUNT(*) FILTER (WHERE a.authorized),0),
    2)
FROM patient p
JOIN auth_status a USING(patient_id)
GROUP BY p.opo
ORDER BY p.opo;
$$ LANGUAGE sql;

SELECT * FROM get_opo_report();

--QN.8. Authorization vs procurement counts per OPO.
-- Requires tablefunc extension.

CREATE EXTENSION IF NOT EXISTS tablefunc;

SELECT *
FROM crosstab(
    $$
    SELECT 
        opo, 
        authorized::text, 
        COUNT(*)
    FROM patient p
    JOIN auth_status a USING(patient_id)
    GROUP BY opo, authorized
    ORDER BY opo, authorized
    $$,
    $$
    SELECT DISTINCT authorized::text
    FROM auth_status
    ORDER BY 1
    $$
) AS ct(
    opo TEXT,              
    not_authorized INT,
    authorized INT
);

--QN.9. Trigger: Warn if patient record is getting deleted without deleting its child records.

CREATE OR REPLACE FUNCTION exception_child_exists_before_delete()
RETURNS TRIGGER AS $$
DECLARE
    child_count INT;
BEGIN
    -- Count if patient_id exists in any child table
    SELECT
        (SELECT COUNT(*) FROM auth_status WHERE patient_id = OLD.patient_id) +
        (SELECT COUNT(*) FROM death_info WHERE patient_id = OLD.patient_id) +
        (SELECT COUNT(*) FROM blood_tissue WHERE patient_id = OLD.patient_id) +
        (SELECT COUNT(*) FROM organ_outcome WHERE patient_id = OLD.patient_id)
    INTO child_count;

    IF child_count > 0 THEN
        RAISE Exception 'Patient % has % related records in child tables.You must delete them before deleting record from
		patient table',OLD.patient_id, child_count;
    END IF;

    RETURN OLD; -- allow deletion, just warn
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER exception_warn_child_exists
BEFORE DELETE ON patient
FOR EACH ROW
EXECUTE FUNCTION exception_child_exists_before_delete();


DELETE FROM patient WHERE patient_id = 'OPO5_P385698';

--QN.10. What is the total number of brain death cases for a specific Organ Procurement Organization (OPO) in a given year?

CREATE OR REPLACE FUNCTION get_opo_year_detail(
    input_opo  TEXT,
    input_year INT
)
RETURNS TABLE (
    opo TEXT,
    referral_year INT,
    total_brain_death_case BIGINT
)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.opo,
        p.referral_year,
        COUNT(d.brain_death) AS total_brain_death_case
    FROM death_info d
    JOIN patient p
        ON p.patient_id = d.patient_id
    WHERE d.brain_death = TRUE
      AND p.opo = input_opo
      AND p.referral_year = input_year
    GROUP BY
        p.opo,
        p.referral_year;
END;
$$ LANGUAGE plpgsql;


select  * from  get_opo_year_detail ('OPO1',2016);



--QN.11. Write a trigger function when the patient age is entered above 89 then it should trigger and update it as 100.
select * from patient; where age ;

create or replace function set_patient_age()
returns trigger
language plpgsql
as $$
begin 
if new.age >89 then new.age :=100;
end if;
return new;
end;
$$;

create trigger trg_patient_status
before insert or update on patient 
for each row
execute function set_patient_age();

update patient set age=90 where patient_id = 'OPO5_P385698';

select age , patient_id from patient where patient_id = 'OPO5_P385698';


--QN.12. Which brain-dead patients of a specific ABO blood type belong to a particular Organ Procurement Organization (OPO),
--and what are their details including death timestamp?

CREATE OR REPLACE FUNCTION get_blood_patient_detail (
    input_abo_blood_type TEXT,
    input_opo TEXT
)
RETURNS TABLE (
    abo_blood_type TEXT,
    opo TEXT,
    patient_id TEXT,
    brain_death BOOLEAN,
    time_brain_death TIMESTAMP
)
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.abo_blood_type,
        p.opo,
        b.patient_id,
        d.brain_death,
        d.time_brain_death
    FROM death_info d
    JOIN blood_tissue b ON b.patient_id = d.patient_id
    JOIN patient p ON p.patient_id = b.patient_id
    WHERE d.brain_death = TRUE
      AND b.abo_blood_type = input_abo_blood_type
      AND p.opo = input_opo;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM get_blood_patient_detail('B', 'OPO4');

--QN.13. Rank patients by number of referrals

CREATE OR REPLACE FUNCTION get_referral_rankings()
RETURNS TABLE (
    patient_id TEXT,
    referral_count BIGINT,
    referral_rank BIGINT
)
AS $$
    WITH counts AS (
        SELECT
            patient_id,
            COUNT(*) AS referral_count
        FROM referrals_cleaned
        GROUP BY patient_id
    )
    SELECT
        patient_id,
        referral_count,
        DENSE_RANK() OVER (ORDER BY referral_count DESC)
    FROM counts;
$$ LANGUAGE sql;

SELECT * FROM get_referral_rankings();


--QN.14.Calculate the percentage uncertainty in death estimates

CREATE OR REPLACE FUNCTION get_death_uncertainty()
RETURNS TABLE (
    opo TEXT,
    year INT,
    calc_deaths INT,
    calc_deaths_lb INT,
    calc_deaths_ub INT,
    pct_uncertainty NUMERIC
)
AS $$
    SELECT
        opo,
        year,
        calc_deaths,
        calc_deaths_lb,
        calc_deaths_ub,
        ROUND(
            (calc_deaths_ub - calc_deaths_lb) / calc_deaths::numeric,
            3
        ) AS pct_uncertainty
    FROM calc_deaths_cleaned
    ORDER BY pct_uncertainty DESC;
$$ LANGUAGE sql;

SELECT * FROM get_death_uncertainty();

--QN.15. Identify OPOs with the highest proportion of multi‑organ donors

CREATE OR REPLACE FUNCTION get_multi_organ_rate()
RETURNS TABLE (
    opo TEXT,
    multi_organ_donors BIGINT,
    total_donors BIGINT,
    multi_organ_rate NUMERIC
)
AS $$
    WITH organ_count AS (
        SELECT
            p.opo,
            (
                (o.outcome_heart = 'accepted')::int +
                (o.outcome_liver = 'accepted')::int +
                (o.outcome_kidney_left = 'accepted')::int +
                (o.outcome_kidney_right = 'accepted')::int +
                (o.outcome_lung_left = 'accepted')::int +
                (o.outcome_lung_right = 'accepted')::int +
                (o.outcome_intestine = 'accepted')::int +
                (o.outcome_pancreas = 'accepted')::int
            ) AS accepted_organs
        FROM organ_outcome o
        JOIN patient p ON o.patient_id = p.patient_id
    )
    SELECT
        opo,
        COUNT(*) FILTER (WHERE accepted_organs >= 4),
        COUNT(*),
        ROUND(
            COUNT(*) FILTER (WHERE accepted_organs >= 4)::numeric / COUNT(*),
            3
        )
    FROM organ_count
    GROUP BY opo
    ORDER BY 4 DESC;
$$ LANGUAGE sql;

SELECT * FROM get_multi_organ_rate();

--Insight--Ranks OPOs by their proportion of multi‑organ donors.