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
DROP VIEW IF EXISTS intermediate_step CASCADE;

-- Define views for your intermediate steps here:
CREATE VIEW intermediate_step AS ... ;

-- Your query that answers the question goes below the "insert into" line:
INSERT INTO q3
