-- Overdue Items

-- You must not change the next 2 lines or the table definition.
SET SEARCH_PATH TO Library, public;
DROP TABLE IF EXISTS q2 cascade;

create table q2 (
    branch CHAR(5) NOT NULL,
    patron CHAR(20),
    title TEXT NOT NULL,
    overdue INT NOT NULL
);

-- Do this for each of the views that define your intermediate steps.
-- (But give them better names!) The IF EXISTS avoids generating an error
-- the first time this file is imported.
-- If you do not define any views, you can delete the lines about views.
DROP VIEW IF EXISTS non_returned_items CASCADE;
DROP VIEW IF EXISTS non_returned_items_from_Parkdale CASCADE;
DROP VIEW IF EXISTS non_returned_items_from_Parkdale_with_details CASCADE;
DROP VIEW IF EXISTS overdue_books_and_audiobooks CASCADE;
DROP VIEW IF EXISTS overdue_movies_music_mags_newspapers CASCADE;
DROP VIEW IF EXISTS all_overdue CASCADE;

CREATE VIEW non_returned_items AS
    SELECT id, patron, checkout_time, copy
    FROM Checkout c LEFT JOIN Return r ON c.id = r.checkout 
    WHERE r.checkout IS NULL;

CREATE VIEW non_returned_items_from_Parkdale AS
    SELECT n.id, l.library AS branch, n.patron, n.checkout_time, n.copy, l.holding
    FROM non_returned_items n JOIN LibraryHolding l ON n.copy = l.barcode JOIN LibraryBranch b ON l.library = b.code JOIN Ward w ON b.ward = w.id
    WHERE w.name = 'Parkdale-High Park';

CREATE VIEW non_returned_items_from_Parkdale_with_details AS
    SELECT n.id, n.branch, n.patron, n.checkout_time, n.copy, n.holding, h.title, h.htype
    FROM non_returned_items_from_Parkdale n JOIN Holding h ON h.id = n.holding;

CREATE VIEW overdue_books_and_audiobooks AS
    SELECT n.id, n.branch, n.patron, n.checkout_time, n.copy, n.holding, n.title, n.htype, (DATE_PART('day', CURRENT_DATE - n.checkout_time)::int - 21) AS overdue
    FROM non_returned_items_from_Parkdale_with_details n
    WHERE (n.htype = 'books'::holding_type OR n.htype = 'audiobooks'::holding_type) AND DATE_PART('day', CURRENT_DATE - n.checkout_time)::int > 21;

CREATE VIEW overdue_movies_music_mags_newspapers AS
    SELECT n.id, n.branch, n.patron, n.checkout_time, n.copy, n.holding, n.title, n.htype, (DATE_PART('day', CURRENT_DATE - n.checkout_time)::int - 7) AS overdue
    FROM non_returned_items_from_Parkdale_with_details n
    WHERE (n.htype = 'movies'::holding_type OR n.htype = 'music'::holding_type OR n.htype = 'magazines and newspapers'::holding_type) AND DATE_PART('day', CURRENT_DATE - n.checkout_time)::int > 7;

CREATE VIEW all_overdue AS
    SELECT DISTINCT branch, patron, title, overdue
    FROM ((SELECT * FROM overdue_books_and_audiobooks) UNION (SELECT * FROM overdue_movies_music_mags_newspapers)) AS u;

-- Your query that answers the question goes below the "insert into" line:
INSERT INTO q2 (branch, patron, title, overdue)
    SELECT * FROM all_overdue;
