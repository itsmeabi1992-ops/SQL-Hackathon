-----------1.Inspecting the "Raw" Data---------------
SELECT * FROM referrals ;

SELECT column_name,data_type,is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'referrals';

-----------2.create a clean copy-------------------------
create table referrals_cleaned as select * from referrals;

------------3.Remove Identical Row Duplicates--------------------
SELECT *
FROM (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY
               OPO, PatientID, HospitalID, Age, Gender, Race,
               Tissue_Referral, Eye_Referral,
               Cause_of_Death_OPO, Cause_of_Death_UNOS,
               Mechanism_of_Death, Circumstances_of_Death,
               ABO_BloodType, ABO_Rh,
               HeightIn, WeightKg,
               brain_death, approached, authorized, procured, transplanted,
               time_brain_death, time_asystole, time_referred,
               time_approached, time_authorized, time_procured,
               Referral_Year, Referral_DayofWeek, Procured_Year,
               outcome_heart, outcome_liver,
               outcome_kidney_left, outcome_kidney_right,
               outcome_lung_left, outcome_lung_right,
               outcome_intestine, outcome_pancreas
           ORDER BY ctid
           ) AS rn
    FROM referrals_cleaned
) t
WHERE rn > 1;

---------------------4.Converting Text Nulls to Real Nulls-----------------------------------
UPDATE referrals_cleaned
SET
    opo = NULLIF(opo, '[null]'),
    patientid = NULLIF(patientid, '[null]'),
    gender = NULLIF(gender, '[null]'),
    race = NULLIF(race, '[null]'),
    hospitalid = NULLIF(hospitalid, '[null]'),
    cause_of_death_opo = NULLIF(cause_of_death_opo, '[null]'),
    cause_of_death_unos = NULLIF(cause_of_death_unos, '[null]'),
    mechanism_of_death = NULLIF(mechanism_of_death, '[null]'),
    circumstances_of_death = NULLIF(circumstances_of_death, '[null]'),
    abo_bloodtype = NULLIF(abo_bloodtype, '[null]'),
    abo_rh = NULLIF(abo_rh, '[null]'),
    time_asystole = NULLIF(time_asystole, '[null]'),
    time_brain_death = NULLIF(time_brain_death, '[null]'),
    time_referred = NULLIF(time_referred, '[null]'),
    time_approached = NULLIF(time_approached, '[null]'),
    time_authorized = NULLIF(time_authorized, '[null]'),
    time_procured = NULLIF(time_procured, '[null]'),
    referral_dayofweek = NULLIF(referral_dayofweek, '[null]'),
    outcome_heart = NULLIF(outcome_heart, '[null]'),
    outcome_liver = NULLIF(outcome_liver, '[null]'),
    outcome_kidney_left = NULLIF(outcome_kidney_left, '[null]'),
    outcome_kidney_right = NULLIF(outcome_kidney_right, '[null]'),
    outcome_lung_left = NULLIF(outcome_lung_left, '[null]'),
    outcome_lung_right = NULLIF(outcome_lung_right, '[null]'),
    outcome_intestine = NULLIF(outcome_intestine, '[null]'),
    outcome_pancreas = NULLIF(outcome_pancreas, '[null]');
----------------------------------5.Fix All Data Types --------------------------------------------------------------------

--------------------DATE TIME DATA TYPE----------------------------------------

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'referrals_cleaned';

ALTER TABLE referrals_cleaned
ALTER COLUMN time_brain_death TYPE TIMESTAMP
USING time_brain_death::TIMESTAMP;

ALTER TABLE referrals_cleaned
ALTER COLUMN time_asystole TYPE TIMESTAMP
USING time_asystole::TIMESTAMP;

ALTER TABLE referrals_cleaned
ALTER COLUMN time_approached TYPE TIMESTAMP
USING time_approached::TIMESTAMP;

ALTER TABLE referrals_cleaned
ALTER COLUMN time_authorized TYPE TIMESTAMP
USING time_authorized::TIMESTAMP;

ALTER TABLE referrals_cleaned
ALTER COLUMN time_procured TYPE TIMESTAMP
USING time_procured::TIMESTAMP;

ALTER TABLE referrals_cleaned
ALTER COLUMN time_referred TYPE TIMESTAMP
USING time_referred::TIMESTAMP;

-----------------------STEP 6 Handle patientid Duplicates AND  Set the Primary Key----------------------------
select  * from referrals_cleaned where patientid = null;

alter table referrals_cleaned add primary key ("patientid");

---------------------------STEP 7 Impute Missing Values-------------------------------------------------------

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'referrals_cleaned';

Select * from referrals_cleaned where age is NULL;----------no null values-----------

Select * from referrals_cleaned where referral_year is NULL; ----no null Values ------------

Select procured_year from referrals_cleaned where procured_year is NULL;---------- replacing the null is not realistic for this dataset----------------

select procured_year from referrals_cleaned where procured_year =0;
---------------------------- DATE TIME-------------------------------------------------------------------------
Select time_asystole from referrals_cleaned where time_asystole is NULL;
Select * from referrals_cleaned where brain_death = 'true';

SELECT brain_death,circumstances_of_death,time_brain_death
FROM referrals
WHERE brain_death IN (TRUE, FALSE);

SELECT brain_death, circumstances_of_death, time_brain_death
FROM referrals
WHERE brain_death = TRUE
AND time_brain_death IS NULL;
------------------------------------------TEXT--------------------------------------------------------------------------------------------
select distinct opo,patient_id,gender,race,cause_of_death_opo,cause_of_death_unos,mechanism_of_death,
circumstances_of_death,abo_bloodtype,abo_rh,referral_day_of_week,outcome_heart,outcome_liver,outcome_kidney_left,outcome_kidney_right
outcome_lung_left,outcome_lung_right,outcome_intestine,outcome_pancreas from referrals_cleaned;

update referrals_cleaned set hospital_id= 'Unknown' Where  hospital_id= 'UNKNOWN';----------no null------------
update referrals_cleaned set cause_of_death_opo= 'Unknown' Where  cause_of_death_opo='UNKNOWN';
update referrals_cleaned set cause_of_death_unos = 'Unknown' Where cause_of_death_unos='UNKNOWN';
update referrals_cleaned set mechanism_of_death = 'Unknown' Where mechanism_of_death='UNKNOWN';
update referrals_cleaned set circumstances_of_death= 'Unknown' Where circumstances_of_death='UNKNOWN';
update referrals_cleaned set abo_bloodtype= 'Unknown' Where abo_bloodtype='UNKNOWN';
update referrals_cleaned set abo_rh= 'Unknown' Where abo_rh='UNKNOWN';
update referrals_cleaned set referral_day_of_week= 'Unknown' Where referral_day_of_week='UNKNOWN';------------no null----------------
update referrals_cleaned set outcome_heart= 'Unknown' Where outcome_heart='UNKNOWN';
update referrals_cleaned set outcome_liver= 'Unknown' Where outcome_liver='UNKNOWN';
update referrals_cleaned set outcome_kidney_left= 'Unknown' Where outcome_kidney_left='UNKNOWN';
update referrals_cleaned set outcome_kidney_right= 'Unknown' Where outcome_kidney_right='UNKNOWN';
update referrals_cleaned set outcome_lung_left= 'Unknown' Where outcome_lung_left='UNKNOWN';
update referrals_cleaned set outcome_lung_right= 'Unknown' Where outcome_lung_right='UNKNOWN';
update referrals_cleaned set outcome_intestine= 'Unknown' Where outcome_intestine='UNKNOWN';
update referrals_cleaned set outcome_pancreas= 'Unknown' Where outcome_pancreas='UNKNOWN';


SELECT  outcome_intestine,outcome_pancreas from referrals_cleaned where outcome_intestine is null or outcome_pancreas is null;

cause_of_death_opo = 'UNKNOWN',cause_of_death_unos= 'UNKNOWN',mechanism_of_death= 'UNKNOWN',
circumstances_of_death= 'UNKNOWN',abo_bloodtype ='UNKNOWN',abo_rh= 'UNKNOWN',referral_dayofweek= 'UNKNOWN',outcome_heart= 'UNKNOWN',outcome_liver= 'UNKNOWN',outcome_kidney_left= 'UNKNOWN',outcome_kidney_right= 'UNKNOWN',
outcome_lung_left= 'UNKNOWN',outcome_lung_right= 'UNKNOWN',outcome_intestine= 'UNKNOWN',outcome_pancreas = 'UNKNOWN' where ;

----------------------------------------step 8 Standardize Categorical Data --------------------------------------------------------------
UPDATE referrals_cleaned
SET gender = 'Male'
WHERE gender = 'M';
UPDATE referrals_cleaned
SET gender = 'Female'
WHERE gender = 'F';

---------------------------STEP 9  Final clean up-------------------------------------------------------------------------------------
--------1.ROUNDING OFF-----------
UPDATE referrals_cleaned
SET heightin = ROUND(heightin,2),
    weightkg = ROUND(weightkg,2);

select heightin ,
    weightkg from referrals_cleaned;

--------------2.snake_case---------------

alter table referrals_cleaned
rename column "patientid" to patient_id;

alter table referrals_cleaned
rename column "hospitalid" to hospital_id;

alter table referrals_cleaned
rename column "heightin" to height_in;

alter table referrals_cleaned
rename column "weightkg" to weight_kg;

alter table referrals_cleaned
rename column "referral_dayofweek" to referral_day_of_week;

alter table referrals_cleaned
rename column "abo_bloodtype" to abo_blood_type;


select  patient_id,hospital_id, height_in, weight_kg,referral_day_of_week from referrals_cleaned ;

------------------------------------------------------------------------------------------------------------------
------------------------------------------------Calc_deaths------------------------------------------------
-----------1.Inspecting the "Raw" Data---------------
SELECT * FROM calc_deaths;

SELECT column_name,data_type,is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'calc_deaths';

-----------2.crate a clean copy-------------------------
create table calc_deaths_cleaned as select * from calc_deaths;

------------3.Remove Identical Row Duplicates--------------------
select * from calc_deaths_cleaned where ctid not in (select min(ctid) from calc_deaths_cleaned group by opo,
 year,calc_deaths,calc_deaths_lb,calc_deaths_ub);

---------------------4.Converting Text Nulls to Real Nulls-----------------------------------

 Select * from calc_deaths_cleaned where 
    opo is NULL OR
    year is NULL OR
    calc_deaths is NULL OR
    calc_deaths_lb is NULL OR
    calc_deaths_ub is NULL;
----------------------------------5.Fix All Data Types --------------------------------------------------------------------

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'calc_deaths_cleaned';

-----------------------STEP 6 Set the Primary Key----------------------------
ALTER TABLE calc_deaths_cleaned
ADD CONSTRAINT pk_calc_death_cleaned
PRIMARY KEY (opo, year);
---------------------------STEP 7  Final clean up-------------------------------------------------------------------------------------
--------1.ROUNDING OFF-----------
select * from calc_deaths_cleaned;

UPDATE calc_deaths_cleaned
SET  calc_deaths = ROUND(calc_deaths,2),
    calc_deaths_lb = ROUND(calc_deaths_lb,2),
	calc_deaths_ub = ROUND(calc_deaths_ub,2);

---------------------------InitCap---------------------------------------------------------
SELECT *
FROM referrals_cleaned
WHERE race <> INITCAP(race);

SELECT distinct cause_of_death_opo 
FROM referrals_cleaned
WHERE cause_of_death_opo <> INITCAP(cause_of_death_opo) --required

UPDATE referrals_cleaned
SET cause_of_death_opo = INITCAP(cause_of_death_opo)
WHERE cause_of_death_opo <> INITCAP(cause_of_death_opo);

SELECT distinct cause_of_death_opo 
FROM referrals_cleaned
WHERE cause_of_death_opo = INITCAP(cause_of_death_opo) 

SELECT distinct cause_of_death_unos 
FROM referrals_cleaned
WHERE cause_of_death_unos <> INITCAP(cause_of_death_unos) --required

UPDATE referrals_cleaned
SET cause_of_death_unos = INITCAP(cause_of_death_unos)
WHERE cause_of_death_unos <> INITCAP(cause_of_death_unos);

SELECT distinct cause_of_death_unos 
FROM referrals_cleaned
WHERE cause_of_death_unos = INITCAP(cause_of_death_unos)

SELECT distinct mechanism_of_death 
FROM referrals_cleaned
WHERE mechanism_of_death <> INITCAP(mechanism_of_death) --required None of the above twice

UPDATE referrals_cleaned
SET mechanism_of_death = INITCAP(mechanism_of_death)
WHERE mechanism_of_death <> INITCAP(mechanism_of_death);

SELECT distinct mechanism_of_death 
FROM referrals_cleaned
WHERE mechanism_of_death = INITCAP(mechanism_of_death)

SELECT distinct circumstances_of_death 
FROM referrals_cleaned
WHERE circumstances_of_death <> INITCAP(circumstances_of_death) --required

UPDATE referrals_cleaned
SET circumstances_of_death = INITCAP(circumstances_of_death)
WHERE circumstances_of_death <> INITCAP(circumstances_of_death);

SELECT distinct circumstances_of_death 
FROM referrals_cleaned
WHERE circumstances_of_death = INITCAP(circumstances_of_death)

SELECT distinct abo_bloodtype 
FROM referrals_cleaned
WHERE abo_bloodtype <> INITCAP(abo_bloodtype)

UPDATE referrals_cleaned
SET abo_bloodtype = INITCAP(abo_bloodtype)
WHERE abo_bloodtype <> INITCAP(abo_bloodtype);

SELECT distinct abo_bloodtype 
FROM referrals_cleaned
WHERE abo_bloodtype = INITCAP(abo_bloodtype)

SELECT distinct abo_rh 
FROM referrals_cleaned
WHERE abo_rh <> INITCAP(abo_rh)

UPDATE referrals_cleaned
SET abo_rh = INITCAP(abo_rh)
WHERE abo_rh <> INITCAP(abo_rh);

SELECT distinct abo_rh 
FROM referrals_cleaned
WHERE abo_rh = INITCAP(abo_rh)

SELECT distinct outcome_heart 
FROM referrals_cleaned
WHERE outcome_heart <> INITCAP(outcome_heart) --required

UPDATE referrals_cleaned
SET outcome_heart = INITCAP(outcome_heart)
WHERE outcome_heart <> INITCAP(outcome_heart);

SELECT distinct outcome_heart 
FROM referrals_cleaned
WHERE outcome_heart = INITCAP(outcome_heart)


SELECT distinct outcome_liver 
FROM referrals_cleaned
WHERE outcome_liver <> INITCAP(outcome_liver) --required

UPDATE referrals_cleaned
SET outcome_liver = INITCAP(outcome_liver)
WHERE outcome_liver <> INITCAP(outcome_liver);

SELECT distinct outcome_liver 
FROM referrals_cleaned
WHERE outcome_liver = INITCAP(outcome_liver)

SELECT distinct outcome_kidney_left 
FROM referrals_cleaned
WHERE outcome_kidney_left <> INITCAP(outcome_kidney_left) --required

UPDATE referrals_cleaned
SET outcome_kidney_left = INITCAP(outcome_kidney_left)
WHERE outcome_kidney_left <> INITCAP(outcome_kidney_left);

SELECT distinct outcome_kidney_left 
FROM referrals_cleaned
WHERE outcome_kidney_left = INITCAP(outcome_kidney_left)

SELECT distinct outcome_kidney_right 
FROM referrals_cleaned
WHERE outcome_kidney_right <> INITCAP(outcome_kidney_right) --required

UPDATE referrals_cleaned
SET outcome_kidney_right = INITCAP(outcome_kidney_right)
WHERE outcome_kidney_right <> INITCAP(outcome_kidney_right);

SELECT distinct outcome_kidney_right 
FROM referrals_cleaned
WHERE outcome_kidney_right = INITCAP(outcome_kidney_right)

SELECT distinct outcome_lung_left 
FROM referrals_cleaned
WHERE outcome_lung_left <> INITCAP(outcome_lung_left) --required

UPDATE referrals_cleaned
SET outcome_lung_left = INITCAP(outcome_lung_left)
WHERE outcome_lung_left <> INITCAP(outcome_lung_left);

SELECT distinct outcome_lung_left 
FROM referrals_cleaned
WHERE outcome_lung_left = INITCAP(outcome_lung_left) --required

SELECT distinct outcome_lung_right
FROM referrals_cleaned
WHERE outcome_lung_right <> INITCAP(outcome_lung_right) --required

UPDATE referrals_cleaned
SET outcome_lung_right = INITCAP(outcome_lung_right)
WHERE outcome_lung_right <> INITCAP(outcome_lung_right);

SELECT distinct outcome_lung_right
FROM referrals_cleaned
WHERE outcome_lung_right = INITCAP(outcome_lung_right)

SELECT distinct outcome_intestine 
FROM referrals_cleaned
WHERE outcome_intestine <> INITCAP(outcome_intestine) -- required

UPDATE referrals_cleaned
SET outcome_intestine = INITCAP(outcome_intestine)
WHERE outcome_intestine <> INITCAP(outcome_intestine);

SELECT distinct outcome_intestine 
FROM referrals_cleaned
WHERE outcome_intestine = INITCAP(outcome_intestine)

SELECT distinct outcome_pancreas
FROM referrals_cleaned
WHERE outcome_pancreas <> INITCAP(outcome_pancreas) --required

UPDATE referrals_cleaned
SET outcome_pancreas = INITCAP(outcome_pancreas)
WHERE outcome_pancreas <> INITCAP(outcome_pancreas);

SELECT distinct outcome_pancreas
FROM referrals_cleaned
WHERE outcome_pancreas = INITCAP(outcome_pancreas) 
-------------------------------------Creating Tables ----------------------------------------------------------------
create table patient as select patient_id,opo,hospital_id,referral_year,referral_day_of_week,
procured_year,age,gender,race,height_in,weight_kg from referrals_cleaned;

select * from patient;

create table blood_tissue as select patient_id,abo_blood_type,abo_rh,tissue_referral,eye_referral
from referrals_cleaned;

select * from blood_tissue;

create table death_info as select patient_id, 
cause_of_death_opo,
cause_of_death_unos,
mechanism_of_death,
circumstances_of_death,
brain_death,
time_brain_death,
time_asystole from referrals_cleaned;

select * from death_info;

create table auth_status as select patient_id,approached,authorized,
procured,transplanted,time_referred,
time_approached,time_authorized,time_procured from referrals_cleaned;

select * from auth_status;

create table organ_outcome as select patient_id,outcome_heart,outcome_liver,
outcome_kidney_left,outcome_kidney_right,outcome_lung_left,outcome_lung_right,
outcome_intestine,outcome_pancreas from referrals_cleaned;

select * from organ_outcome;

select * from patient;

alter table patient add primary key ("patient_id");

select * from blood_tissue;

ALTER TABLE blood_tissue
ADD CONSTRAINT fk_blood_tissue_patient_id
FOREIGN KEY (patient_id)
REFERENCES patient (patient_id);

select * from death_info;

ALTER TABLE death_info
ADD CONSTRAINT fk_death_info_patient_id
FOREIGN KEY (patient_id)
REFERENCES patient (patient_id);

select * from auth_status;

ALTER TABLE auth_status
ADD CONSTRAINT fk_auth_status_patient_id
FOREIGN KEY (patient_id)
REFERENCES patient (patient_id);

select * from organ_outcome;

ALTER TABLE organ_outcome
ADD CONSTRAINT fk_organ_outcome_patient_id
FOREIGN KEY (patient_id)
REFERENCES patient (patient_id);

-----------------------------------------Indexing----------------------------------------------------------
CREATE INDEX ON auth_status(patient_id);
CREATE INDEX ON organ_outcome(patient_id);
CREATE INDEX ON death_info(patient_id);
CREATE INDEX ON blood_tissue(patient_id);
CREATE INDEX ON patient(referral_year);
CREATE INDEX ON patient(procured_year);
CREATE INDEX ON calc_deaths_cleaned(opo);
CREATE INDEX ON calc_deaths_cleaned(year);

-----------------------------------------Entity RelationShip--------------------------------------------------
create table patient_calc_deaths_2015_2020 as 
select patient_id,opo,referral_year from patient where referral_year between 2015 and 2020


ALTER TABLE calc_deaths_cleaned
ADD PRIMARY KEY (opo,year);

ALTER table patient_calc_deaths_2015_2020
ADD CONSTRAINT fk_patient_calc_opo
FOREIGN KEY (opo,referral_year)
REFERENCES calc_deaths_cleaned (opo,year);

ALTER table patient_calc_deaths_2015_2020
ADD CONSTRAINT fk_patient_id
FOREIGN KEY (patient_id)
REFERENCES patient(patient_id);














    






