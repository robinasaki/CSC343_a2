-- Lure Them Back

-- You must not change the next 2 lines or the table definition.
SET SEARCH_PATH TO Library, public;
DROP TABLE IF EXISTS q5 cascade;

CREATE TABLE q5 (
    patronID CHAR(20) NOT NULL,
    email TEXT NOT NULL,
    usage INT NOT NULL,
    decline INT NOT NULL,
    missed INT NOT NULL
);

-- Do this for each of the views that define your intermediate steps.
-- (But give them better names!) The IF EXISTS avoids generating an error
-- the first time this file is imported.
-- If you do not define any views, you can delete the lines about views.
DROP VIEW IF EXISTS Patron_ids CASCADE;
DROP VIEW IF EXISTS PatronCheckoutDate0 CASCADE;
DROP VIEW IF EXISTS PatronIdMonths CASCADE;
DROP VIEW IF EXISTS Missing2022 CASCADE;
DROP VIEW IF EXISTS ActiveEveryMonth2022 CASCADE;
DROP VIEW IF EXISTS ActiveAtLeast5Months2023 CASCADE;
DROP VIEW IF EXISTS Missing2023 CASCADE;
DROP VIEW IF EXISTS NotActive2024 CASCADE;
DROP VIEW IF EXISTS TargetPatrons CASCADE;
DROP VIEW IF EXISTS TargetPatronsBasicInfo CASCADE;
DROP VIEW IF EXISTS TargetPatronsAddCheckouts CASCADE;
DROP VIEW IF EXISTS PatronDecline CASCADE;
DROP VIEW IF EXISTS AddPatronDecline CASCADE;
DROP VIEW IF EXISTS PatronMissed2023 CASCADE;
DROP VIEW IF EXISTS AllInfo CASCADE;

-- Define views for your intermediate steps here:

-- Helper view
CREATE VIEW Patron_ids AS
    SELECT card_number AS patron_id
    FROM Patron;

-- Patron and their checkout date
CREATE VIEW PatronCheckoutDate0 AS
    SELECT patron AS patron_id, DATE(checkout_time) AS checkout_date
    -- == Checkout ==
    -- id (checkout_id), patron (patron_id), copy (holding_id), checkout_time
    FROM Checkout R1;

-- Permutation of patron_ids and months
CREATE VIEW PatronIdMonths AS
    SELECT *
    FROM Patron_ids
    CROSS JOIN (
        SELECT 1 AS active_month
        UNION ALL SELECT 2
        UNION ALL SELECT 3
        UNION ALL SELECT 4
        UNION ALL SELECT 5
        UNION ALL SELECT 6
        UNION ALL SELECT 7
        UNION ALL SELECT 8
        UNION ALL SELECT 9
        UNION ALL SELECT 10
        UNION ALL SELECT 11
        UNION ALL SELECT 12
    ) AS Months;

-- At least one missing month in 2022
CREATE VIEW Missing2022 AS
    SELECT * 
    FROM (
        (
            SELECT * FROM PatronIdMonths -- all possible
        ) EXCEPT ALL (
            SELECT patron_id, EXTRACT(MONTH FROM checkout_date) -- 2022 actual
            FROM PatronCheckoutDate0
            WHERE EXTRACT(YEAR FROM checkout_date) = 2022
        )
    ) AS R2;

-- Patrons that are active every month in 2022
CREATE VIEW ActiveEveryMonth2022 AS -- [key0]
    SELECT patron_id
    FROM (
        (
            SELECT card_number AS patron_id -- all patrons
            FROM Patron
        ) EXCEPT ALL (
            SELECT patron_id FROM Missing2022 -- missing patrons
        )
    ) AS R3;

-- Active in at least 5 months in 2023
CREATE VIEW ActiveAtLeast5Months2023 AS -- [key1]
    SELECT DISTINCT patron_id
    FROM ( 
    SELECT patron_id, COUNT(DISTINCT EXTRACT(MONTH FROM checkout_date)) AS active_month_count
    FROM (
        SELECT * FROM PatronCheckoutDate0
        WHERE EXTRACT(YEAR FROM checkout_date) = 2023
    ) AS R
    GROUP BY patron_id
    ) AS R4
    WHERE active_month_count >= 5;

-- At least 1 non-active month in 2023
-- Active every month in 2022
CREATE VIEW Missing2023 AS
    SELECT DISTINCT patron_id
    FROM (
        (
            SELECT * FROM PatronIdMonths
        ) EXCEPT ALL (
            SELECT patron_id, EXTRACT(MONTH FROM checkout_date)
            FROM PatronCheckoutDate0
            WHERE EXTRACT(YEAR FROM checkout_date) = 2023
        )
    ) AS R5;
    
-- Completely not active in 2024
CREATE VIEW NotActive2024 AS -- [key3]
    SELECT DISTINCT patron_id
    FROM (
        (SELECT card_number AS patron_id FROM Patron) EXCEPT ALL (
            SELECT patron_id 
            FROM ( SELECT * FROM PatronCheckoutDate0 WHERE EXTRACT(YEAR FROM checkout_date) = 2024) AS R6
            GROUP BY patron_id )
    ) AS R7;

-- Now we union the above
CREATE VIEW TargetPatrons AS
    (SELECT * FROM ActiveEveryMonth2022)
    INTERSECT
    (SELECT * FROM ActiveAtLeast5Months2023)
    INTERSECT
    (SELECT * FROM Missing2023)
    INTERSECT
    (SELECT * FROM NotActive2024);

-- Now we load the attributes
CREATE VIEW TargetPatronsBasicInfo AS
    SELECT R.*, email
    FROM TargetPatrons R
    -- == Patron ==
    -- card_number (patron_id), first_name, last_name, email, phone
    INNER JOIN Patron R8 ON R.patron_id = R8.card_number;

-- Add usage
CREATE VIEW TargetPatronsAddCheckouts AS
    SELECT R.*, usage
    FROM TargetPatronsBasicInfo R
    INNER JOIN (
        SELECT patron, COUNT(DISTINCT copy) AS usage
        FROM Checkout
        -- == Checkout ==
        -- id (checkout_id), patron (patron_id), copy (holding_id), checkout_time
        GROUP BY patron
    ) AS R9 ON R.patron_id = R9.patron;

-- Add decline
CREATE VIEW PatronDecline AS
    SELECT R11.patron AS patron_id, (R11.checkout_count_2022 - R12.checkout_count_2023) AS decline
    FROM ( -- selected patron individual checkout count in 2022
        SELECT patron, checkout_count_2022
        FROM TargetPatrons R
        INNER JOIN (
            SELECT patron, COUNT(checkout_time) AS checkout_count_2022
            FROM (SELECT * FROM Checkout WHERE EXTRACT(YEAR FROM checkout_time) = 2022) AS RR1
            GROUP BY patron
        ) AS R10_2022 ON R.patron_id = R10_2022.patron
    ) AS R11 INNER JOIN ( -- selected patron individual checkout count in 2023
        SELECT patron, checkout_count_2023
        FROM TargetPatrons R
        INNER JOIN (
            SELECT patron, COUNT(checkout_time) AS checkout_count_2023
            FROM (SELECT * FROM Checkout WHERE EXTRACT(YEAR FROM checkout_time) = 2023) AS RR2
            GROUP BY patron
        ) AS R10_2023 ON R.patron_id = R10_2023.patron
    ) AS R12 ON R11.patron = R12.patron;

CREATE VIEW AddPatronDecline AS
    SELECT R13.*, R14.decline
    FROM TargetPatronsAddCheckouts R13
    INNER JOIN PatronDecline R14 ON R13.patron_id = R14.patron_id;

-- Generate the missing info
CREATE VIEW PatronMissed2023 AS
    -- == Checkout ==
    -- id (checkout_id), patron, copy, checkout_time

    -- == Return ==
    -- checkout (checkout_id), return_time
    SELECT T3.patron_id, (T3.checkout_count - T3.return_count) AS missed
    FROM (
        SELECT T1.id AS patron_id, T1.checkout_count, T2.return_count
        FROM (SELECT id, COUNT(checkout_time) AS checkout_count
        FROM Checkout
        GROUP BY id) AS T1 INNER JOIN
        (SELECT checkout AS id, COUNT(return_time) AS return_count
        FROM Return
        GROUP BY checkout) AS T2
        ON T1.id::CHAR = T2.id::CHAR
    ) AS T3;

-- Append the missing info
CREATE VIEW AllInfo AS
    SELECT R.*, T4.missed
    FROM AddPatronDecline R
    JOIN PatronMissed2023 T4 ON R.patron_id::CHAR = T4.patron_id::CHAR;

-- Your query that answers the question goes below the "insert into" line:
INSERT INTO q5
    SELECT *
    FROM AllInfo
    ORDER BY AllInfo.patron_id;
