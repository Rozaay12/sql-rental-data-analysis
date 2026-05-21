/* ============================================================
   SQL Rental Data Analysis
   Author: Michael Jon-Baptiste
   Database: PostgreSQL (Pagila / DVD Rental)
   Description: Analyzing rental trends, family film performance,
                and store activity using CTEs, window functions,
                and aggregations.
   ============================================================ */


/* ============================================================
   Query 1 - Family Film Rental Counts
   Insight: Which family-friendly films are rented most frequently?
   Categories: Animation, Children, Classics, Comedy, Family, Music
   ============================================================ */

SELECT
    f.title             AS film_title
   ,c.name              AS category_name
   ,COUNT(r.rental_id)  AS times_rented
FROM film f
JOIN film_category fc
    ON f.film_id = fc.film_id
JOIN category c
    ON fc.category_id = c.category_id
JOIN inventory i
    ON f.film_id = i.film_id
JOIN rental r
    ON i.inventory_id = r.inventory_id
WHERE c.name IN (
    'Animation', 'Children', 'Classics',
    'Comedy', 'Family', 'Music'
)
GROUP BY
    f.title
   ,c.name
ORDER BY
    times_rented DESC
   ,film_title;


/* ============================================================
   Query 2 - Family Film Rental Duration Quartiles
   Insight: How do family-friendly films compare in rental duration,
   and which quartile does each film fall into?
   ============================================================ */

WITH rental_durations AS (
    SELECT
        f.film_id
       ,f.title
       ,c.name                                                  AS category_name
       ,DATE_PART('day', r.return_date - r.rental_date)        AS rental_days
    FROM film f
    JOIN film_category fc
        ON f.film_id = fc.film_id
    JOIN category c
        ON fc.category_id = c.category_id
    JOIN inventory i
        ON f.film_id = i.film_id
    JOIN rental r
        ON i.inventory_id = r.inventory_id
    WHERE r.return_date IS NOT NULL
),

avg_durations AS (
    SELECT
        film_id
       ,title
       ,category_name
       ,AVG(rental_days) AS avg_rental_days
    FROM rental_durations
    GROUP BY
        film_id
       ,title
       ,category_name
),

film_with_quartile AS (
    SELECT
        film_id
       ,title
       ,category_name
       ,avg_rental_days
       ,NTILE(4) OVER (ORDER BY avg_rental_days) AS quartile_num
    FROM avg_durations
),

family_movies AS (
    SELECT
        film_id
       ,title
       ,category_name
       ,avg_rental_days
       ,CASE quartile_num
            WHEN 1 THEN 'first_quarter'
            WHEN 2 THEN 'second_quarter'
            WHEN 3 THEN 'third_quarter'
            WHEN 4 THEN 'final_quarter'
        END AS rental_quartile
    FROM film_with_quartile
    WHERE category_name IN (
        'Animation', 'Children', 'Classics',
        'Comedy', 'Family', 'Music'
    )
)

SELECT
    film_id
   ,title
   ,category_name
   ,avg_rental_days
   ,rental_quartile
FROM family_movies
ORDER BY
    rental_quartile
   ,avg_rental_days
   ,title;


/* ============================================================
   Query 3 - Family Film Category Quartile Distribution
   Insight: How many films per family category fall into each
   rental duration quartile? Identifies which categories
   tend toward shorter vs longer rental periods.
   ============================================================ */

WITH film_avg AS (
    SELECT
        f.film_id
       ,f.title
       ,c.name                                                  AS category_name
       ,AVG(DATE_PART('day', r.return_date - r.rental_date))   AS avg_rental_days
    FROM film f
    JOIN film_category fc
        ON f.film_id = fc.film_id
    JOIN category c
        ON fc.category_id = c.category_id
    JOIN inventory i
        ON f.film_id = i.film_id
    JOIN rental r
        ON i.inventory_id = r.inventory_id
    WHERE r.return_date IS NOT NULL
    GROUP BY
        f.film_id
       ,f.title
       ,c.name
),

film_with_quartile AS (
    SELECT
        film_id
       ,title
       ,category_name
       ,avg_rental_days
       ,NTILE(4) OVER (ORDER BY avg_rental_days) AS quartile_num
    FROM film_avg
),

film_with_bucket AS (
    SELECT
        film_id
       ,title
       ,category_name
       ,avg_rental_days
       ,CASE quartile_num
            WHEN 1 THEN 'first_quarter'
            WHEN 2 THEN 'second_quarter'
            WHEN 3 THEN 'third_quarter'
            WHEN 4 THEN 'final_quarter'
        END AS rental_length_category
    FROM film_with_quartile
),

family_only AS (
    SELECT *
    FROM film_with_bucket
    WHERE category_name IN (
        'Animation', 'Children', 'Classics',
        'Comedy', 'Family', 'Music'
    )
),

family_with_counts AS (
    SELECT
        category_name          AS category
       ,rental_length_category
       ,COUNT(*) OVER (
            PARTITION BY category_name, rental_length_category
        )                      AS movie_count
    FROM family_only
)

SELECT DISTINCT
    category
   ,rental_length_category  AS "rental length category"
   ,movie_count             AS "count"
FROM family_with_counts
ORDER BY
    category
   ,rental_length_category;


/* ============================================================
   Query 4 - Monthly Rental Counts by Store
   Insight: How do rental volumes compare between stores month
   over month? Identifies seasonal trends and store performance.
   ============================================================ */

SELECT
    DATE_PART('month', r.rental_date)  AS rental_month
   ,DATE_PART('year', r.rental_date)   AS rental_year
   ,s.store_id
   ,COUNT(r.rental_id)                 AS count_rentals
FROM rental r
JOIN staff st
    ON r.staff_id = st.staff_id
JOIN store s
    ON st.store_id = s.store_id
GROUP BY
    DATE_PART('year', r.rental_date)
   ,DATE_PART('month', r.rental_date)
   ,s.store_id
ORDER BY
    rental_year
   ,rental_month
   ,s.store_id;
