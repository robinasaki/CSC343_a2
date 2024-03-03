-- Explorers Contest

-- You must not change the next 2 lines or the table definition.
SET SEARCH_PATH TO Library, public;
DROP TABLE IF EXISTS q4 cascade;

CREATE TABLE q4 (
    patronID CHAR(20) NOT NULL
);

-- Do this for each of the views that define your intermediate steps.
-- (But give them better names!) The IF EXISTS avoids generating an error
-- the first time this file is imported.
-- If you do not define any views, you can delete the lines about views.
DROP VIEW IF EXISTS RegistrationMeta0 CASCADE;
DROP VIEW IF EXISTS PatronWard1 CASCADE;
DROP VIEW IF EXISTS Explorers2 CASCADE;
DROP VIEW IF EXISTS Wards CASCADE;
DROP VIEW IF EXISTS EveryPossible CASCADE;
DROP VIEW IF EXISTS Missing CASCADE;
DROP VIEW IF EXISTS Explorer CASCADE;

-- Define views for your intermediate steps here:

-- Signup and their library, signup year, etc., refactored from q1.sql
CREATE VIEW RegistrationMeta0 AS
    -- == Eventsignup ==
    -- patron, event (event_id)
    SELECT RR1.patron AS patron_id, RR1.event AS event_id, RR3.library AS branch_code, RR4.event_year
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
    ) AS RR4 ON RR2.id = RR4.event;

-- Add ward info to above
CREATE VIEW PatronWard1 AS
    SELECT R.patron_id, R.event_year, R4.ward
    FROM RegistrationMeta0 R -- 200
    -- == Librarybranch ==
    -- code (branch_code), name, phone, ward
    LEFT JOIN Librarybranch R4 ON R.branch_code = R4.code;

-- Helper view, all wards
CREATE VIEW Wards AS
    SELECT id AS ward
    FROM Ward;

-- Find patron who has been in EVERY library within the same year

-- All possible combination 
CREATE VIEW EveryPossible AS
    SELECT R.patron_id, R.event_year, W.ward
    FROM PatronWard1 R
    CROSS JOIN Wards W;

-- Find missing values
CREATE VIEW Missing AS
    SELECT DISTINCT patron_id
    FROM (
        (
            -- patron_id, event_year, ward
            SELECT * FROM EveryPossible
        ) EXCEPT (
            -- patron_id, event_year, ward
            SELECT * FROM PatronWard1
        )
    ) AS R5;

-- Explorer
CREATE VIEW Explorer AS
    SELECT DISTINCT patron_id
    FROM (
        (SELECT patron_id FROM PatronWard1) EXCEPT (SELECT * FROM Missing)
    ) AS R6;

-- Your query that answers the question goes below the "insert into" line:
INSERT INTO q4
    SELECT *
    FROM Explorer
    ORDER BY patron_id
