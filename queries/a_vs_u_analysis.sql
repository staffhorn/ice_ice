-- Transfers analysis.
-- Get error rate for doublicated alien numbers (AN).
SELECT count(*) AS unique, sum(count) AS total, sum(count) - count(*) AS doublicates, round((sum(count) - count(*)) / sum(count), 3) AS error_rate FROM (SELECT alien_number, count(*) FROM persons GROUP BY alien_number) AS x;
-- Count the number of transfers for each individual AN.
SELECT alien_number, COUNT(*) AS nmbr_transfers FROM transfers GROUP BY alien_number ORDER BY nmbr_transfers DESC;
-- Get the number of internal/external transfers. Tables of individual transfers. Percentage of transfers compare to total. Quality of transfering data regarding to and from.
SELECT alien_number, COUNT(*) AS nmbr_transfers FROM transfers WHERE action_from = action_to GROUP BY alien_number ORDER BY nmbr_transfers DESC;
SELECT alien_number, COUNT(*) AS nmbr_transfers FROM transfers WHERE action_from != action_to GROUP BY alien_number ORDER BY nmbr_transfers DESC;
SELECT 100 * ROUND(CAST(COUNT(*) AS NUMERIC)/(SELECT COUNT(*) FROM transfers), 3) AS percent_internal_transfers FROM transfers WHERE action_from = action_to;
SELECT 100 * ROUND(CAST(COUNT(*) AS NUMERIC)/(SELECT COUNT(*) FROM transfers), 3) AS percent_external_transfers FROM transfers WHERE action_from != action_to;
SELECT 100 * ROUND(CAST(COUNT(action_from) AS NUMERIC)/COUNT(*), 3) AS transfer_from, 100 * ROUND(CAST(COUNT(action_to) AS NUMERIC)/COUNT(*), 3) AS transfer_to, 100 * ROUND(CAST((SELECT COUNT(*) FROM transfers WHERE action_from IS NOT NULL AND action_to IS NOT NULL) AS NUMERIC)/COUNT(*), 3) AS both_transfers FROM transfers;
-- Count accompanied/unaccompanied
SELECT 100 * ROUND(CAST((SELECT COUNT(*) FROM transfers WHERE accompanied_status = 'Accompanied') AS NUMERIC)/COUNT(*), 3) AS percent_accompanied, 100 * ROUND(CAST((SELECT COUNT(*) FROM transfers WHERE accompanied_status = 'Unaccompanied') AS NUMERIC)/COUNT(*), 3) AS percent_unaccompanied FROM transfers; 

-- Find AN for which accompanied status was changed over time.
-- We report all AN with changed accompanied status from both avalaible tables: daily sensus and transfers.
WITH x1 AS (SELECT alien_number, date, accompanied_status, CASE accompanied_status WHEN 'Accompanied' THEN 1 ELSE 0 END AS a_u FROM status_daily), --Convert accompanied status to 0/1   
	 y1 AS (SELECT alien_number, SUM(a_u), COUNT(*) FROM  x1 GROUP BY alien_number), -- all zeros means never was accompanied, sum of ones = count means always accompanied
	 z1 AS (SELECT alien_number, CASE WHEN sum = 0 THEN 'Never accompanied' WHEN sum = count THEN 'Always accompanied' ELSE 'Changed Status' END AS a_u_status FROM y1), -- Break on three groups by accompanied status stability 
	 a1 AS (SELECT alien_number FROM z1 WHERE a_u_status = 'Changed Status'), -- We are interested in changed status
	 b1 AS (SELECT DISTINCT ON(a1.alien_number) a1.alien_number, status_daily.date, status_daily.accompanied_status FROM a1 LEFT OUTER JOIN status_daily ON a1.alien_number = status_daily.alien_number ORDER BY a1.alien_number, status_daily.date DESC), -- Get a list of ANs which accompanied status was changed between transfers. Show accompanied status for the last transfer.
	 x2 AS (SELECT alien_number, action_date, accompanied_status, CASE accompanied_status WHEN 'Accompanied' THEN 1 ELSE 0 END AS a_u FROM transfers), 
	 y2 AS (SELECT alien_number, SUM(a_u), COUNT(*) FROM  x2 GROUP BY alien_number),
	 z2 AS (SELECT alien_number, CASE WHEN sum = 0 THEN 'Never accompanied' WHEN sum = count THEN 'Always accompanied' ELSE 'Changed Status' END AS a_u_status FROM y2),
	 a2 AS (SELECT alien_number FROM z2 WHERE a_u_status = 'Changed Status'),
	 b2 AS (SELECT DISTINCT ON(a2.alien_number) a2.alien_number, transfers.action_date, transfers.accompanied_status FROM a2 LEFT OUTER JOIN transfers ON a2.alien_number = transfers.alien_number ORDER BY a2.alien_number, transfers.action_date DESC)
SELECT b1.alien_number, b1.date, b1.accompanied_status, persons.id, persons.first_name, persons.last_name, persons.dob, persons.gender, persons.cob, persons.source FROM b1 LEFT OUTER JOIN persons ON b1.alien_number = persons.alien_number
UNION
SELECT b2.alien_number, b2.action_date, b2.accompanied_status, persons.id, persons.first_name, persons.last_name, persons.dob, persons.gender, persons.cob, persons.source FROM b2 LEFT OUTER JOIN persons ON b2.alien_number = persons.alien_number
ORDER BY alien_number;

SELECT * FROM status_daily LIMIT 10;
-- Analysis accompanied vs unaccompanied
WITH a AS (SELECT DISTINCT ON(alien_number) alien_number, date, agency, accompanied_status AS as_last, age_on_date FROM status_daily ORDER BY alien_number, status_daily DESC), -- accompanied status on last day
	 b AS (SELECT DISTINCT ON(alien_number) alien_number, date, agency, accompanied_status AS as_first, age_on_date FROM status_daily ORDER BY alien_number, status_daily), -- accompanied status on first day
	 c AS (SELECT a.alien_number, b.agency AS agency_first, a.agency AS agency_last, b.age_on_date AS age_first, a.age_on_date AS age_last, b.date AS date_first, a.date AS date_last, b.as_first, a.as_last FROM a LEFT OUTER JOIN b ON a.alien_number = b.alien_number),
	 d AS (SELECT as_first AS accompanied_status, agency_first AS agency, count(*) AS count_on_first, CONCAT(as_first, agency_first) AS keys FROM c GROUP BY as_first, agency_first ORDER BY agency_first),	 
	 e AS (SELECT as_last AS accompanied_status, agency_last AS agency, count(*) AS count_on_last, CONCAT(as_last, agency_last) AS keys FROM c GROUP BY as_last, agency_last ORDER BY agency_last),
     f AS (SELECT d.accompanied_status, d.agency, d.count_on_first, e.count_on_last FROM d FULL JOIN e ON d.keys = e.keys ORDER BY d.agency)
--SELECT * FROM f; -- count by U/A on first/last date for all agencies
--SELECT COUNT(*) AS changed_agency, (SELECT COUNT(*) FROM c) AS same_agency FROM c WHERE agency_first != agency_last; -- Count the number of AN which were changed agency
--SELECT agency_last AS agency, as_last AS accompanied_status, ROUND(AVG(age_last - age_first), 2) AS average_days FROM c WHERE agency_first != agency_last GROUP BY agency_last, as_last ORDER BY agency_last;

SELECT agency_last AS agency, as_last AS accompanied_status, COUNT(CASE WHEN age_last - age_first <= 30 THEN 1 ELSE NULL END) AS less_30,
	COUNT(CASE WHEN (age_last - age_first <= 60 AND age_last - age_first > 30) THEN 1 ELSE NULL END) AS between_30_60,
	COUNT(CASE WHEN (age_last - age_first <= 90 AND age_last - age_first > 60) THEN 1 ELSE NULL END) AS between_30_60,
	COUNT(CASE WHEN (age_last - age_first  > 90) THEN 1 ELSE NULL END) AS greater_90
FROM c GROUP BY agency_last, as_last ORDER BY agency_last;
