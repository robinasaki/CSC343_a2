-- Promotion

-- You must not change the next 2 lines, the domain definition, or the table definition.
SET SEARCH_PATH TO Library, public;
DROP TABLE IF EXISTS q3 cascade;

DROP DOMAIN IF EXISTS patronCategory;
create domain patronCategory as varchar(10)
    check (value in ('inactive', 'reader', 'doer', 'keener'));

create table q3 (
    patronID Char(20) NOT NULL,
    category patronCategory
);

-- Do this for each of the views that define your intermediate steps.
-- (But give them better names!) The IF EXISTS avoids generating an error
-- the first time this file is imported.
-- If you do not define any views, you can delete the lines about views.
DROP VIEW IF EXISTS patronEventSignups CASCADE;
DROP VIEW IF EXISTS totalSignups CASCADE;
DROP VIEW IF EXISTS patronBookCheckouts CASCADE;
DROP VIEW IF EXISTS totalCheckouts CASCADE;
DROP VIEW IF EXISTS librariesUsed CASCADE;
DROP VIEW IF EXISTS lowEventsUsage CASCADE;
DROP VIEW IF EXISTS highEventsUsage CASCADE;
DROP VIEW IF EXISTS lowCheckoutUsage CASCADE;
DROP VIEW IF EXISTS highCheckoutUsage CASCADE;
DROP VIEW IF EXISTS categories CASCADE;

DROP VIEW IF EXISTS allPatrons CASCADE;
DROP VIEW IF EXISTS completeCategories CASCADE;

CREATE VIEW patronEventSignups AS
    SELECT EventSignup.patron, LibraryRoom.library, count(EventSignup.event) AS numEvents
    FROM EventSignUp JOIN LibraryEvent ON EventSignUp.event = LibraryEvent.id
        JOIN LibraryRoom ON LibraryEvent.room = LibraryRoom.id
    GROUP BY EventSignUp.patron, LibraryRoom.library;

CREATE VIEW totalSignups AS
    SELECT patronEventSignups.patron, sum(patronEventSignups.numEvents) AS numEvents
    FROM patronEventSignups
    GROUP BY patron;

CREATE VIEW patronBookCheckouts AS 
    SELECT Checkout.patron, LibraryHolding.library, count(Checkout.id) AS numCheckouts
    FROM Checkout JOIN LibraryHolding ON Checkout.copy = LibraryHolding.barcode
    GROUP BY Checkout.patron, LibraryHolding.library;

CREATE VIEW totalCheckouts AS
    SELECT patronBookCheckouts.patron, sum(patronBookCheckouts.numCheckouts) AS numCheckouts
    FROM patronBookCheckouts
    GROUP BY patron;

CREATE VIEW librariesUsed AS
    SELECT DISTINCT a.patron, a.library
    FROM (
        SELECT patron, library FROM patronEventSignups
        UNION
        SELECT patron, library FROM patronBookCheckouts
    ) a;
    -- FROM patronEventSignups JOIN patronBookCheckouts ON (patronEventSignups.patron = patronBookCheckouts.patron 
    --     AND patronEventSignups.library = patronBookCheckouts.library);

CREATE VIEW lowEventsUsage AS
    SELECT a.patron, 'low' AS attendance 
    FROM totalSignups a
    WHERE NOT EXISTS (
        SELECT b.patron
        FROM totalSignups b
        WHERE EXISTS (
            -- Find the patrons who have attended an event at any of the original patron's used libraries
            SELECT * FROM
            ((SELECT c.library
                FROM librariesUsed c
                WHERE c.patron = a.patron) AS c1
            INNER JOIN -- or JOIN, same thing
            (SELECT c.library
                FROM librariesUsed c
                WHERE c.patron = b.patron) AS c2
            ON c1.library = c2.library)
        )
    )
    OR a.numEvents < 0.25 * (
        SELECT avg(b.numEvents)
        FROM totalSignups b
        WHERE EXISTS (
            -- Find the patrons who have attended an event at any of the original patron's used libraries
            SELECT * FROM (
            (SELECT c.library
                FROM librariesUsed c
                WHERE c.patron = a.patron) c1
            INNER JOIN -- or JOIN, same thing
            (SELECT c.library
                FROM librariesUsed c
                WHERE c.patron = b.patron) c2
            ON c1.library = c2.library
            )
        ));

CREATE VIEW highEventsUsage AS
    SELECT a.patron, 'high' AS attendance 
    FROM totalSignups a
    WHERE a.patron NOT IN (
        SELECT lowEventsUsage.patron 
        FROM lowEventsUsage
    ) AND a.numEvents > 0.75 * (
        SELECT avg(b.numEvents)
        FROM totalSignups b
        WHERE EXISTS (
            -- Find the patrons who have attended an event at any of the original patron's used libraries
            SELECT * FROM (
            (SELECT c.library
                FROM librariesUsed c
                WHERE c.patron = a.patron) c1
            INNER JOIN -- or JOIN, same thing
            (SELECT c.library
                FROM librariesUsed c
                WHERE c.patron = b.patron) c2
            ON c1.library = c2.library
            )
        )
    );

CREATE VIEW lowCheckoutUsage AS
    SELECT a.patron, 'low' AS checkouts 
    FROM totalCheckouts a
    WHERE NOT EXISTS (
        SELECT b.patron
        FROM totalCheckouts b
        WHERE EXISTS (
            -- Find the patrons who have attended an event at any of the original patron's used libraries
            SELECT * FROM
            ((SELECT c.library
                FROM librariesUsed c
                WHERE c.patron = a.patron) c1
            INNER JOIN -- or JOIN, same thing
            (SELECT c.library
                FROM librariesUsed c
                WHERE c.patron = b.patron) c2
            ON c1.library = c2.library
            )
        )
    ) 
    OR a.numCheckouts < 0.25 * (
        SELECT avg(b.numCheckouts)
        FROM totalCheckouts b
        WHERE EXISTS (
            -- Find the patrons who have attended an event at any of the original patron's used libraries
            SELECT * FROM (
            (SELECT c.library
                FROM librariesUsed c
                WHERE c.patron = a.patron) c1
            INNER JOIN -- or JOIN, same thing
            (SELECT c.library
                FROM librariesUsed c
                WHERE c.patron = b.patron) c2
            ON c1.library = c2.library
            )
        )
    );

CREATE VIEW highCheckoutUsage AS
    SELECT a.patron, 'high' AS checkouts 
    FROM totalCheckouts a
    WHERE a.patron NOT IN (
        SELECT lowCheckoutUsage.patron 
        FROM lowCheckoutUsage
    ) AND a.numCheckouts > 0.75 * (
        SELECT avg(b.numCheckouts)
        FROM totalCheckouts b
        WHERE EXISTS (
            -- Find the patrons who have attended an event at any of the original patron's used libraries
            SELECT * FROM (
                (
                    SELECT c.library
                    FROM librariesUsed c
                    WHERE c.patron = a.patron
                ) c1
                INNER JOIN ( -- or JOIN, same thing
                    SELECT c.library
                    FROM librariesUsed c
                    WHERE c.patron = b.patron
                ) c2
                ON c1.library = c2.library
            ) 
        )
    );

CREATE VIEW categories AS
    SELECT 
        a.patron,
        CASE
            WHEN a.attendance = 'low' AND b.checkouts = 'low' THEN 'inactive'::patronCategory
            WHEN a.attendance = 'low' AND b.checkouts = 'high' THEN 'reader'::patronCategory
            WHEN a.attendance = 'high' AND b.checkouts = 'low' THEN 'doer'::patronCategory
            WHEN a.attendance = 'high' AND b.checkouts = 'high' THEN 'keener'::patronCategory
            ELSE NULL
        END AS category
    FROM ((
            SELECT * FROM lowEventsUsage
            UNION
            SELECT * FROM highEventsUsage
        ) a 
        JOIN (
            SELECT * FROM lowCheckoutUsage
            UNION
            SELECT * FROM highCheckoutUsage
        ) b
        ON a.patron = b.patron
        -- ((SELECT * FROM lowEventsUsage) UNION (SELECT * FROM highEventsUsage)) a
        -- JOIN
        -- ((SELECT * FROM lowCheckoutUsage) UNION (SELECT * FROM highCheckoutUsage)) b
        -- ON a.patron = b.patron
    );

CREATE VIEW allPatrons AS
    SELECT patron
    FROM (
        (SELECT patron FROM totalSignups)
        UNION
        (SELECT patron FROM totalCheckouts)
    ) a;

CREATE VIEW completeCategories AS
    SELECT allPatrons.patron, categories.category
    FROM categories 
    FULL OUTER JOIN allPatrons
    ON categories.patron = allPatrons.patron;

-- Your query that answers the question goes below the "insert into" line:
INSERT INTO q3 (patronid, category)
    SELECT * FROM completeCategories;