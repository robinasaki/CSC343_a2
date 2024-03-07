SET search_path TO Library, public;

DROP VIEW IF EXISTS AllLibraries CASCADE;
DROP VIEW IF EXISTS OpenAfterHours CASCADE;
DROP VIEW IF EXISTS NotOpenAfterHours CASCADE;
DROP VIEW IF EXISTS HasHoursOnThursday CASCADE;
DROP VIEW IF EXISTS NoHoursOnThursday CASCADE;

-- Code of every library branch
CREATE VIEW AllLibraries AS
    SELECT code AS library
    FROM LibraryBranch;

-- All libraries that are either open after 6pm on a weekday, or open on Sunday
CREATE VIEW OpenAfterHours AS
    SELECT DISTINCT library
    FROM LibraryHours
    WHERE LibraryHours.day = 'sun'::week_day
    OR ((LibraryHours.day = 'mon'::week_day
            OR LibraryHours.day = 'tue'::week_day
            OR LibraryHours.day = 'wed'::week_day
            OR LibraryHours.day = 'thu'::week_day
            OR LibraryHours.day = 'fri'::week_day)
    AND LibraryHours.end_time > '18:00:00'::time);

-- Libraries not either open after 6pm on a weekday, or open on Sunday
CREATE VIEW NotOpenAfterHours AS
    SELECT *
    FROM (
        SELECT * FROM AllLibraries
        EXCEPT
        SELECT * FROM OpenAfterHours
    ) a;

-- Libraries having at least some hours on Thursday
CREATE VIEW HasHoursOnThursday AS
    SELECT NotOpenAfterHours.library
    FROM NotOpenAfterHours
    WHERE EXISTS (
        SELECT * 
        FROM LibraryHours
        WHERE LibraryHours.library = NotOpenAfterHours.library
        AND LibraryHours.day = 'thu'::week_day
    );

-- Libraries with no hours on Thursday
CREATE VIEW NoHoursOnThursday AS
    SELECT *
    FROM (
        SELECT * FROM NotOpenAfterHours
        EXCEPT
        SELECT * FROM HasHoursOnThursday
    ) a;

INSERT INTO LibraryHours
    SELECT library, 'thu'::week_day, '18:00:00'::time, '21:00:00'::time
    FROM NoHoursOnThursday;

UPDATE LibraryHours
    SET end_time = '21:00:00'::time
    WHERE LibraryHours.library IN (SELECT library FROM HasHoursOnThursday) 
        AND LibraryHours.day = 'thu'::week_day;
