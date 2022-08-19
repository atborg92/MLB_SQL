#Create a view of each stadium with it's ranking of relative size (avg depth)
#DROP VIEW IF EXISTS dimension_rankings

DROP VIEW IF EXISTS dimension_rankings

CREATE VIEW bbref.dimension_rankings AS 
WITH dimensions AS (SELECT
	*,
    ROUND((lf_dim + cf_dim + rf_dim) / 3,3) AS avg_depth,
	RANK() OVER(order by ROUND((lf_dim + cf_dim + rf_dim) / 3,3) DESC) AS depth_rank,
    ROUND((lf_w + cf_w + rf_w) / 3,3) AS avg_wall_height,
    RANK() OVER(ORDER BY ROUND((lf_w + cf_w + rf_w) / 3,3) DESC) AS height_rank
FROM park_dimensions
ORDER BY 12,14)

SELECT
	*,
    CASE WHEN depth_rank <= 10 THEN "Large" WHEN depth_rank BETWEEN 11 AND 20 THEN "Medium" ELSE "Small" END AS depth,
    CASE WHEN height_rank <= 10 THEN "High" WHEN height_rank BETWEEN 11 AND 20 THEN "Medium" ELSE "Short" END AS wall_height
FROM dimensions;

