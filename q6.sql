-- Devoted Fans
 
-- You must not change the next 2 lines or the table definition.
SET SEARCH_PATH TO Library, public;
DROP TABLE IF EXISTS q6 cascade;

CREATE TABLE q6 (
    patronID Char(20) NOT NULL,
    devotedness INT NOT NULL
);

-- Do this for each of the views that define your intermediate steps.
-- (But give them better names!) The IF EXISTS avoids generating an error
-- the first time this file is imported.
-- If you do not define any views, you can delete the lines about views.
DROP VIEW IF EXISTS books_with_one_author CASCADE;
DROP VIEW IF EXISTS authors_with_two_plus_books CASCADE;
DROP VIEW IF EXISTS author_books CASCADE;
DROP VIEW IF EXISTS satisfactory_checkouts CASCADE;
DROP VIEW IF EXISTS specific_checkouts CASCADE;
DROP VIEW IF EXISTS satisfactory_reviews CASCADE;

DROP VIEW IF EXISTS no_devotedness CASCADE;
DROP VIEW IF EXISTS has_devotedness CASCADE;
DROP VIEW IF EXISTS final_result CASCADE;

-- Define views for your intermediate steps here:
CREATE VIEW books_with_one_author AS
    SELECT max(HoldingContributor.contributor) AS author, HoldingContributor.holding AS book
    FROM HoldingContributor
    GROUP BY HoldingContributor.holding
    HAVING count(HoldingContributor.contributor) = 1;

CREATE VIEW authors_with_two_plus_books AS
    SELECT author, count(book) AS numBooks
    FROM books_with_one_author
    GROUP BY author
    HAVING count(book) >= 2;

CREATE VIEW author_books AS
    SELECT authors_with_two_plus_books.author, HoldingContributor.holding
    FROM authors_with_two_plus_books JOIN HoldingContributor 
        ON HoldingContributor.contributor = authors_with_two_plus_books.author;


CREATE VIEW satisfactory_checkouts AS
    SELECT Checkout.patron, author_books.author, count(author_books.holding) AS checkoutCount
    FROM Checkout JOIN LibraryHolding ON Checkout.copy = LibraryHolding.barcode
        JOIN author_books ON LibraryHolding.holding = author_books.holding
    GROUP BY Checkout.patron, author_books.author
    HAVING count(author_books.holding) >= (SELECT numBooks FROM authors_with_two_plus_books 
                                            WHERE author_books.author = authors_with_two_plus_books.author) - 1;
    
CREATE VIEW specific_checkouts AS
    SELECT Checkout.patron, author_books.author, author_books.holding
    FROM Checkout JOIN LibraryHolding ON Checkout.copy = LibraryHolding.barcode
        JOIN author_books ON LibraryHolding.holding = author_books.holding
    WHERE Checkout.patron IN (SELECT patron FROM satisfactory_checkouts);
    -- SELECT Checkout.patron, authors_with_two_plus_books.author, count(authors_with_two_plus_books.author)
    -- FROM Checkout JOIN LibraryHolding ON Checkout.copy = LibraryHolding.barcode
    --     JOIN HoldingContributor ON HoldingContributor.holding = LibraryHolding.holding
    -- WHERE HoldingContributor.contributor IN (SELECT author FROM authors_with_two_plus_books)
    -- GROUP BY Checkout.patron, authors_with_two_plus_books.author;
    
CREATE VIEW satisfactory_reviews AS
    SELECT Review.patron, specific_checkouts.author, count(specific_checkouts.holding) AS numReviews, avg(Review.stars) AS avgReview
    FROM Review JOIN specific_checkouts ON (Review.patron = specific_checkouts.patron 
                                                AND Review.holding = specific_checkouts.holding)
    GROUP BY Review.patron, specific_checkouts.author
    HAVING count(specific_checkouts.holding) = (SELECT checkoutCount FROM satisfactory_checkouts 
                                                    WHERE satisfactory_checkouts.patron = Review.patron 
                                                    AND specific_checkouts.author = satisfactory_checkouts.author)
        AND avg(Review.stars) >= 4.0;

CREATE VIEW no_devotedness AS
    SELECT card_number AS patron, 0 AS devotedness
    FROM Patron;

CREATE VIEW has_devotedness AS
    SELECT satisfactory_checkouts.patron AS patron, count(satisfactory_checkouts.author) AS devotedness
    FROM satisfactory_checkouts
    JOIN satisfactory_reviews
    ON satisfactory_checkouts.patron = satisfactory_reviews.patron
    AND satisfactory_checkouts.author = satisfactory_reviews.author
    GROUP BY satisfactory_checkouts.patron;

CREATE VIEW final_result AS
    SELECT no_devotedness.patron AS patronID, coalesce(has_devotedness.devotedness, no_devotedness.devotedness) AS devotedness
    FROM no_devotedness
    FULL OUTER JOIN has_devotedness
    ON no_devotedness.patron = has_devotedness.patron;

-- Your query that answers the question goes below the "insert into" line:
INSERT INTO q6 (patronID, devotedness)
    SELECT * FROM final_result;
