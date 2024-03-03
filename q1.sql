-- Branch Activity

-- You must not change the next 2 lines or the table definition.
SET SEARCH_PATH TO Library, public;
DROP TABLE IF EXISTS q1 cascade;

CREATE TABLE q1 (
    branch CHAR(5) NOT NULL,
    year INT NOT NULL,
    events INT NOT NULL,
    sessions FLOAT NOT NULL,
    registration INT NOT NULL,
    holdings INT NOT NULL,
    checkouts INT NOT NULL,
    duration FLOAT NOT NULL
);

-- Do this for each of the views that define your intermediate steps.
-- (But give them better names!) The IF EXISTS avoids generating an error
-- the first time this file is imported.
-- If you do not define any views, you can delete the lines about views.
DROP VIEW IF EXISTS BranchYear0 CASCADE;
DROP VIEW IF EXISTS LibraryEventCounts1 CASCADE;
DROP VIEW IF EXISTS AverageSession2 CASCADE;
DROP VIEW IF EXISTS Registration3 CASCADE;
DROP VIEW IF EXISTS Holding4 CASCADE;
DROP VIEW IF EXISTS Avg_duration6 CASCADE;

-- Define views for your intermediate steps here:
-- Permutation of branch_code and year from 2021 to 2023
CREATE VIEW BranchYear0 AS
    SELECT R1.code AS branch_code, R2.event_year
    -- == Librarybranch ==
    -- code (branch_code), name, address, phone, has_parking, ward
    FROM Librarybranch R1
    CROSS JOIN (
        SELECT 2019 AS event_year
        UNION ALL
        SELECT 2020
        UNION ALL
        SELECT 2021
        UNION ALL
        SELECT 2022
        UNION ALL
        SELECT 2023
    ) AS R2;

-- Add event count for each year for each branch
CREATE VIEW LibraryEventCounts1 AS
    SELECT R.*, COALESCE(R3.event_count, 0) AS event_count
    FROM BranchYear0 R
    LEFT JOIN (
        SELECT RR3.library AS branch_code, EXTRACT(YEAR FROM RR2.edate) AS event_year, COALESCE(COUNT(DISTINCT RR2.event), 0) AS event_count
        -- == Libraryevent ==
        -- id (event_id), room (room_id), name
        FROM Libraryevent RR1
        -- == Eventschedule ==
        -- event (event_id), edate, start_time, end_time
        INNER JOIN Eventschedule RR2 ON RR1.id = RR2.event
        -- == Libraryroom ==
        -- id (room_id), library (branch_code), name, rtype, max_capacity
        INNER JOIN Libraryroom RR3 ON RR1.room = RR3.id
        GROUP BY RR3.library, EXTRACT(YEAR FROM RR2.edate)
    ) AS R3 ON R.branch_code = R3.branch_code AND R.event_year = R3.event_year;

-- Add average session for each year for each branch
CREATE VIEW AverageSession2 AS
    SELECT R.*, COALESCE((R4.session_count::float / R.event_count), 0) AS avg_evt_session
    FROM LibraryEventCounts1 R 
    LEFT JOIN (
        SELECT RR3.library AS branch_code, EXTRACT(YEAR FROM RR2.edate) AS event_year, COALESCE(COUNT(RR2.start_time), 0) AS session_count
        -- == Libraryevent ==
        -- id (event_id), room (room_id), name
        FROM Libraryevent RR1
        -- == Eventschedule ==
        -- event (event_id), edate, start_time, end_time
        INNER JOIN Eventschedule RR2 ON RR1.id = RR2.event
        -- == Libraryroom ==
        -- id (room_id), library (branch_code), name, rtype, max_capacity
        INNER JOIN Libraryroom RR3 ON RR1.room = RR3.id
        GROUP BY RR3.library, EXTRACT(YEAR FROM RR2.edate)
    ) AS R4 ON R.branch_code = R4.branch_code AND R.event_year = R4.event_year;

-- Add registration count to above
CREATE VIEW Registration3 AS
    SELECT R.*, COALESCE(R5.registration_count, 0) AS registration_count
    FROM AverageSession2 R
    LEFT JOIN ( -- registration info for each year for each branch

        -- == Eventsignup ==
        -- patron, event (event_id)
        SELECT RR3.library AS branch_code, COALESCE(COUNT(RR1.patron), 0) AS registration_count, RR4.event_year AS event_year
        FROM Eventsignup RR1
        -- == Libraryevent ==
        -- id (event_id), room (room_id), name
        INNER JOIN Libraryevent RR2 ON RR1.event = RR2.id
        -- == Libraryroom ==
        -- id (room_id), library (branch_code), name, rtype, max_capacity
        INNER JOIN Libraryroom RR3 ON RR2.room = RR3.id -- 200 so far
        -- == Eventschedule == 
        -- event (event_id), edate, start_time, end_time
        INNER JOIN (
            SELECT event, EXTRACT(YEAR FROM edate) AS event_year
            FROM Eventschedule
            GROUP BY event, EXTRACT(YEAR FROM edate)
        ) AS RR4 ON RR2.id = RR4.event
        GROUP BY RR3.library, RR4.event_year
    ) AS R5 ON R.branch_code = R5.branch_code AND R.event_year = R5.event_year; -- TODO: fix the registration calcaultion

-- Add holding count to above
CREATE VIEW Holding4 AS
    SELECT R.*, COALESCE(R6.holding_count, 0) AS holding_count
    FROM Registration3 R
    LEFT JOIN (
        SELECT library AS branch_code, COALESCE(COUNT(holding), 0) AS holding_count
        -- == Libraryholding ==
        -- barcode, library (branch_code), holding
        FROM Libraryholding
        GROUP BY library
    ) AS R6 ON R.branch_code = R6.branch_code;

-- Add checkout count to above
CREATE VIEW Checkouts5 AS
    SELECT R.*, COALESCE(R7.checkout_count, 0) AS checkout_count 
    FROM Holding4 R
    LEFT JOIN (
        SELECT library AS branch_code, COALESCE(COUNT(copy), 0) AS checkout_count, EXTRACT(YEAR FROM checkout_time) AS checkout_time 
        -- == Checkout ==
        -- id (checkout_id), patron, copy (copy_id), checkout_time

        -- == Libraryholding ==
        -- barcode (copy_id), library (branch_code), holding
        FROM Checkout RR1
        JOIN Libraryholding RR2 ON RR1.copy = RR2.barcode
        GROUP BY library, EXTRACT(YEAR FROM checkout_time)
    ) AS R7 ON R.branch_code = R7.branch_code AND R.event_year = R7.checkout_time;

-- Add avg_duration
CREATE VIEW Avg_duration6 AS
    SELECT R.*, COALESCE(R8.avg_duration, 0.00) AS avg_duration
    FROM Checkouts5 R
    LEFT JOIN ( -- the avg_duration for each branch
        -- == Return ==
        -- checkout (checkout_id), return_time

        -- == Checkout ==
        -- id (checkout_id), patron, copy (copy_id), checkout_time
        SELECT RR3.library AS branch_code, COALESCE(AVG(DATE(RR1.return_time) - DATE(RR2.checkout_time)), 0.00) AS avg_duration, EXTRACT(YEAR FROM checkout_time) AS checkout_year
        FROM Return RR1 
        FULL JOIN Checkout RR2 ON RR1.checkout = RR2.id
        -- == Libraryholding ==
        -- barcode (copy_id), library (branch_code), holding
        INNER JOIN Libraryholding RR3 ON RR2.copy = RR3.barcode
        GROUP BY RR3.library, EXTRACT(YEAR FROM checkout_time)
    ) AS R8 ON R.branch_code = R8.branch_code AND R.event_year = checkout_year;


-- Your query that answers the question goes below the "insert into" line:
INSERT INTO q1
    SELECT *
    FROM Avg_duration6
    ORDER BY branch_code
