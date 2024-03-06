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
DROP VIEW IF EXISTS PatronActiveDate CASCADE;
DROP VIEW IF EXISTS PatronIdMonths CASCADE;
DROP VIEW IF EXISTS ActiveEveryMonth2022 CASCADE;
DROP VIEW IF EXISTS ActiveAtLeastFiveMonths2023 CASCADE;
DROP VIEW IF EXISTS NonActive2024 CASCADE;
DROP VIEW IF EXISTS Lure CASCADE;
DROP VIEW IF EXISTS LureEmail CASCADE;
DROP VIEW IF EXISTS PatronCheckoutCounts CASCADE;
DROP VIEW IF EXISTS LureEmailCheckout CASCADE;
DROP VIEW IF EXISTS PatronCheckoutCounts2022 CASCADE;
DROP VIEW IF EXISTS PatronCheckoutCounts2023 CASCADE;
DROP VIEW IF EXISTS PatronDecline CASCADE;
DROP VIEW IF EXISTS EveryMissing2023 CASCADE;
DROP VIEW IF EXISTS LureAddMissing CASCADE;

-- [0] Patrons and their active months
CREATE VIEW PatronActiveDate AS
    -- patron_id, active_date
    SELECT patron AS patron_id, DATE(checkout_time) AS active_date
    FROM Checkout;

-- [1] ACTIVE EVERY 2022 MONTH
CREATE VIEW ActiveEveryMonth2022 AS
    -- patron_id
    SELECT patron_id
    FROM ( -- patrons and 2022 active months
        SELECT patron_id, EXTRACT(MONTH FROM active_date) AS active_month
        FROM PatronActiveDate
        WHERE EXTRACT(YEAR FROM active_date) = 2022
    ) AS Activity2022
    GROUP BY patron_id
    HAVING COUNT(DISTINCT active_month) = 12;

-- [2] ACTIVE AT LEAST 5 MONTHS IN 2023 AND
-- [3] AT LEAST 1 NON-ACTIVE 2023 MONTH
CREATE VIEW ActiveAtLeastFiveMonths2023 AS
    -- patron_id
    SELECT patron_id
    FROM ( -- patrons and 2023 active months
        SELECT patron_id, EXTRACT(MONTH FROM active_date) AS active_month
        FROM PatronActiveDate
        WHERE EXTRACT(YEAR FROM active_date) = 2023
    ) AS Activity2023
    GROUP BY patron_id
    HAVING COUNT(DISTINCT active_month) >= 5 AND COUNT(DISTINCT active_month) < 12;

-- [4] NON-ACTIVE IN 2024
CREATE VIEW NonActive2024 AS
    -- patron_id
    SELECT patron_id
    FROM ( -- patrons NOT active in 2024
        SELECT card_number AS patron_id -- all patrons
        FROM Patron
        EXCEPT
        SELECT patron_id -- patrons with at least one 2024 activity
        FROM PatronActiveDate
        WHERE EXTRACT(YEAR FROM active_date) = 2024
    ) AS Activity2024;

-- Find the target patrons
CREATE VIEW Lure AS
    -- patron_id
    SELECT card_number AS patron_id FROM Patron
    INTERSECT
    SELECT patron_id FROM ActiveEveryMonth2022
    INTERSECT
    SELECT patron_id FROM ActiveAtLeastFiveMonths2023
    INTERSECT
    SELECT patron_id FROM NonActive2024;

-- Load target's email
CREATE VIEW LureEmail AS
    -- patron_id, email
    SELECT L.patron_id, COALESCE(P.email, 'none') AS email -- as required
    FROM Lure L
    LEFT JOIN Patron P ON L.patron_id = P.card_number;

-- Patrons and checkout counts
CREATE VIEW PatronCheckoutCounts AS
    SELECT patron AS patron_id, COALESCE(COUNT(DISTINCT holding), 0) AS checkout_count
    FROM Checkout C JOIN LibraryHolding LH
    ON C.copy = LH.barcode
    GROUP BY patron;

-- Load Checkouts
CREATE VIEW LureEmailCheckout AS
    -- patron_id, email, checkout_count
    SELECT LE.patron_id, LE.email, COALESCE(PCC.checkout_count, 0) AS checkout_count
    FROM LureEmail LE
    LEFT JOIN PatronCheckoutCounts PCC ON LE.patron_id = PCC.patron_id;

-- All patrons and checkout counts in 2022
CREATE VIEW PatronCheckoutCounts2022 AS
    SELECT patron AS patron_id, COALESCE(COUNT(checkout_time), 0) AS checkout_count
    FROM (
        SELECT * FROM Checkout WHERE EXTRACT(YEAR FROM checkout_time) = 2022
    ) AS R
    GROUP BY patron;

-- All patrons and checkout counts in 2023
CREATE VIEW PatronCheckoutCounts2023 AS
    SELECT patron AS patron_id, COALESCE(COUNT(checkout_time), 0) AS checkout_count
    FROM (
        SELECT * FROM Checkout WHERE EXTRACT(YEAR FROM checkout_time) = 2023
    ) AS R
    GROUP BY patron;

-- === Above are correct ===

-- Compute the decline attr
CREATE VIEW PatronDecline AS
    SELECT LEC.patron_id, LEC.email, LEC.checkout_count, 
    (CC2022.checkout_count - CC2023.checkout_count) AS decline
    FROM LureEmailCheckout LEC
    INNER JOIN PatronCheckoutCounts2022 CC2022 ON LEC.patron_id = CC2022.patron_id
    INNER JOIN PatronCheckoutCounts2023 CC2023 ON LEC.patron_id = CC2023.patron_id;

-- All patrons and their missing months in 2023
CREATE VIEW EveryMissing2023 AS
    SELECT patron_id, COUNT(DISTINCT EXTRACT(MONTH FROM active_date)) AS active_month_count
    -- patron_id, active_date
    FROM PatronActiveDate PAD
    WHERE EXTRACT(YEAR FROM active_date) = 2023
    GROUP BY patron_id
    HAVING COUNT(DISTINCT EXTRACT(MONTH FROM active_Date)) < 12;

-- Add the final info
CREATE VIEW LureAddMissing AS
    SELECT PD.*, (12 - EM.active_month_count) AS missed
    FROM PatronDecline PD
    INNER JOIN EveryMissing2023 EM ON PD.patron_id = EM.patron_id;

-- Your query that answers the question goes below the "insert into" line:
INSERT INTO q5
    SELECT * FROM LureAddMissing;