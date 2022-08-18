#Data cleanup:
# Added new column opp_id that references team id in misc table so that it can be used as a foreign key.
ALTER TABLE 2021_giants_batting ADD opp_id int;

update 2021_giants_batting 
set 2021_giants_batting.opp_id = (SELECT id from 2021_misc_team_stats where 2021_giants_batting.Opp = 2021_misc_team_stats.Team)
where exists(select id from 2021_misc_team_stats where 2021_giants_batting.Opp = 2021_misc_team_stats.Team);



#Forgot to name a column in my CSV, renamed in schema
ALTER TABLE 2021_player_stats
RENAME COLUMN MyUnknownColumn TO Country;

#Deleting players who were traded midseason - stats not properly attributed to the teams they played for.
DELETE FROM 2021_player_stats
WHERE length(Team) > 3;

#Exploration:
# Win/Loss record and win percentage grouped by month, with overall at the bottom:
SELECT
	MONTHNAME(Date) AS Month,
    SUM(CASE WHEN Rslt LIKE 'W%' THEN 1 ELSE 0 END) AS Wins,
    SUM(CASE WHEN Rslt LIKE 'L%' THEN 1 ELSE 0 END) AS Losses,
    ROUND(SUM(CASE WHEN Rslt LIKE 'W%' THEN 1 ELSE 0 END) / CAST(COUNT(game) AS float), 3) AS Win_Pct
FROM 2021_giants_batting
GROUP BY 1
UNION
SELECT
	'Total',
    SUM(CASE WHEN Rslt LIKE 'W%' THEN 1 ELSE 0 END),
	SUM(CASE WHEN Rslt LIKE 'L%' THEN 1 ELSE 0 END),
    ROUND(SUM(CASE WHEN Rslt LIKE 'W%' THEN 1 ELSE 0 END) / CAST(COUNT(game) AS float), 3)
FROM 2021_giants_batting;

#Adding Pythagorean win / loss percentage. This is a commonly used baseball statistic that examines run differential to estimate expected win-loss record. 
#This table shows pythagorean (expected) win rate, actual win rate, and percent to which the team outperformed or underperformed their pythagorean win rate.
SELECT
	MONTHNAME(bat.date) AS Month,
    SUM(CASE WHEN bat.r > pitch.r THEN 1 ELSE 0 END) AS Wins,
    SUM(CASE WHEN bat.r < pitch.r THEN 1 ELSE 0 END) AS Losses,
    SUM(bat.r) AS Runs_Scored,
    SUM(pitch.r) AS Runs_Allowed,
    ROUND(POWER(SUM(bat.r),2) / (POWER(SUM(bat.r),2) + POWER(SUM(pitch.r),2)),3) AS Pythagorean,
    ROUND(SUM(CASE WHEN bat.r > pitch.r THEN 1 ELSE 0 END) / COUNT(*),3) AS Actual,
    ROUND((ROUND(SUM(CASE WHEN bat.r > pitch.r THEN 1 ELSE 0 END) / COUNT(*),3) / ROUND(POWER(SUM(bat.r),2) / 
    (POWER(SUM(bat.r),2) + POWER(SUM(pitch.r),2)),3) -1)*100,3) AS percent_difference
FROM 2021_giants_batting bat
JOIN 2021_giants_pitching pitch ON bat.game = pitch.game
GROUP BY 1
UNION
SELECT
	'Total',
	SUM(CASE WHEN bat.r > pitch.r THEN 1 ELSE 0 END),
    SUM(CASE WHEN bat.r < pitch.r THEN 1 ELSE 0 END),
    SUM(bat.r) AS Runs_Scored,
    SUM(pitch.r) AS Runs_Allowed,
    ROUND(POWER(SUM(bat.r),2) / (POWER(SUM(bat.r),2) + POWER(SUM(pitch.r),2)),3),
    ROUND(SUM(CASE WHEN bat.r > pitch.r THEN 1 ELSE 0 END) / COUNT(*),3),
    ROUND((ROUND(SUM(CASE WHEN bat.r > pitch.r THEN 1 ELSE 0 END) / COUNT(*),3) / ROUND(POWER(SUM(bat.r),2) / 
    (POWER(SUM(bat.r),2) + POWER(SUM(pitch.r),2)),3) -1)*100,3)
FROM 2021_giants_batting bat
JOIN 2021_giants_pitching pitch ON bat.game = pitch.game
;
# Giants Wins, Losses and Win Percentage grouped by opponent
SELECT
	opp AS Opponent,
	SUM(CASE WHEN Rslt LIKE 'W%' THEN 1 ELSE 0 END) AS Wins,
    SUM(CASE WHEN Rslt LIKE 'L%' THEN 1 ELSE 0 END) AS Losses,
    ROUND(SUM(CASE WHEN Rslt LIKE 'W%' THEN 1 ELSE 0 END) / CAST(COUNT(game) AS float), 3) AS Win_Pct
FROM 2021_giants_batting
GROUP BY 1
ORDER BY 4 DESC;

# Each team's top three players in terms of OPS (On base percentage + slugging percentage), sorted by the average among those top three.

WITH ops_rankings AS (SELECT
	Team,
	Player,
    OPS,
    Age,
    ROW_NUMBER() OVER(PARTITION BY Team ORDER BY OPS DESC) AS ops_rank
FROM 2021_player_stats
)
SELECT
	ops.Team,
    ops.Player AS first_name,
    ops.OPS AS first_ops,
	(SELECT Player FROM ops_rankings ops2 WHERE ops_rank = 2 AND ops.Team = ops2.Team) AS second_name,
    (SELECT OPS FROM ops_rankings ops2 WHERE ops_rank = 2 AND ops.Team = ops2.team) AS second_ops,
	(SELECT Player FROM ops_rankings ops3 WHERE ops_rank = 3 AND ops.Team = ops3.Team) AS third_name,
    (SELECT OPS FROM ops_rankings ops3 WHERE ops_rank = 3 AND ops.Team = ops3.team) AS third_ops,
    ROUND((ops.OPS +  (SELECT OPS FROM ops_rankings ops2 WHERE ops_rank = 2 AND ops.Team = ops2.team) +  
    (SELECT OPS FROM ops_rankings ops3 WHERE ops_rank = 3 AND ops.Team = ops3.team))/3,3) AS top_three_avg
FROM ops_rankings ops
GROUP BY 1
ORDER BY 8 DESC
;

#Create a view of each stadium with it's ranking of relative size (avg depth)
#DROP VIEW IF EXISTS dimension_rankings

DROP VIEW IF EXISTS dimension_rankings;

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

#Each ballpark, its depth and height rankings, and sum of homeruns hit by the hometeam in 2021

SELECT
	name AS ballpark,
    depth_rank,
    height_rank,
    SUM(splits.hr) AS hometeam_hrs
FROM dimension_rankings parks
JOIN 2021_batting_homeaway splits ON parks.team = splits.Team
WHERE splits.split = 'Home'
GROUP BY 1,2,3;


#Using dimension rankings view and home away batting splits, I looked at average home runs per season hit by the home team grouped by wall height and depth. Used a rollup function to examine the differences when accounting 
#for both wall size and depth, as well as each individually.
SELECT 
	IF(GROUPING(depth), 'All depths', depth) AS depth,
    IF(GROUPING(wall_height), 'All heights',wall_height) AS wall_height,
    AVG(splits.hr) AS avg_season_hr
FROM dimension_rankings parks
JOIN 2021_batting_homeaway splits ON parks.team = splits.Team
WHERE split = 'Home'
GROUP BY depth, wall_height WITH ROLLUP
ORDER BY 3 DESC;

#Cleaned up version with fewer groupings

SELECT 
	depth,
    'All heights' AS wall_height,
    AVG(splits.hr) AS avg_season_hr
FROM dimension_rankings parks
JOIN 2021_batting_homeaway splits ON parks.team = splits.Team
WHERE split = 'Home'
GROUP BY 1
UNION ALL
SELECT 
	'All depths',
    wall_height,
    AVG(splits.hr) AS avg_season_hr
FROM dimension_rankings parks
JOIN 2021_batting_homeaway splits ON parks.team = splits.Team
WHERE split = 'Home'
GROUP BY 2
UNION ALL
SELECT
	'All depths',
    'All heights',
    AVG(splits.hr)
FROM dimension_rankings parks
JOIN 2021_batting_homeaway splits ON parks.team = splits.Team
WHERE split = 'Home'
order by field(wall_height,'short','medium','high'),field(depth,'Small','Medium','Large')
;

#Giants with running total of homeruns
SELECT
	EXTRACT(month FROM date) AS month,
    date,
    SUM(hr) OVER(ORDER BY date ROWS UNBOUNDED PRECEDING) AS hr_running_total
FROM 2021_giants_batting
;
#Creating view of Giants batting by month

DROP VIEW IF EXISTS bbref.giants_batting_monthly;
CREATE VIEW bbref.giants_batting_monthly AS
SELECT
	MONTHNAME(bat.date) AS Month,
    EXTRACT(MONTH FROM bat.date) AS monthnum,
    SUM(bat.pa) as PA,
    SUM(bat.ab) as ab,
    SUM(bat.r) as r,
    SUM(bat.h) as h,
    ROUND(SUM(bat.h) / SUM(bat.ab),3) AS ba,
    SUM(bat.2b) as 2b,
    SUM(bat.3b) as 3b,
    SUM(bat.hr) as hr,
    SUM(bat.rbi) as rbi,
    SUM(bat.bb) AS bb,
    SUM(bat.ibb) as ibb,
    SUM(bat.so) as batting_so,
    SUM(bat.HBP) as hbp,
    SUM(bat.sh) as sh,
    SUM(bat.Attendance) as attendance,
    SUM(ip) as ip,
    SUM(pit.h) AS hits_allowed,
    SUM(pit.r) AS runs_allowed,
    SUM(pit.er) as er_allowed,
    SUM(pit.uer) AS uer_allowed,
    SUM(pit.pit) AS pitch_count,
    SUM(pit.str) AS strikes,
    SUM(pit.bb) AS bb_allowed,
    SUM(pit.so) AS pitching_so,
    ROUND(SUM(pit.so) / SUM(pit.bb),3) AS k_bb_ratio
FROM 2021_giants_batting bat
JOIN 2021_giants_pitching pit ON bat.game = pit.game
GROUP BY 1;

#Using above view, here is running total select stats by month in 2021
SELECT
	month,
    ROUND(SUM(h) OVER(ORDER BY monthnum ROWS UNBOUNDED PRECEDING) / SUM(ab) OVER(ORDER BY monthnum ROWS UNBOUNDED PRECEDING),3) AS ba_runningtotal,
	SUM(pa) OVER(ORDER BY monthnum ROWS UNBOUNDED PRECEDING) AS pa_runningtotal,
    SUM(r) OVER(ORDER BY monthnum ROWS UNBOUNDED PRECEDING) AS r_runningtotal,
    SUM(hr) OVER(ORDER BY monthnum ROWS UNBOUNDED PRECEDING) AS hr_runningtotal,
    ROUND(SUM(pitching_so) OVER(ORDER BY monthnum ROWS UNBOUNDED PRECEDING) / SUM(bb_allowed) OVER(ORDER BY monthnum ROWS UNBOUNDED PRECEDING),3) AS k_bb_runningtotal
FROM giants_batting_monthly
;


#Teams with above average attendance and bottom 3rd payroll. With attendance Z score


WITH salary_rank AS (SELECT
	Team,
    Attendance,
    salary,
    NTILE(3) OVER(ORDER BY salary DESC) AS third
FROM 2021_misc_team_stats

)
SELECT
	Team,
    Attendance,
    ROUND((attendance - (SELECT AVG(attendance) FROM 2021_misc_team_stats)) / 
    (SELECT STD(attendance) FROM 2021_misc_team_stats),3) AS attendance_zscore,
    ROUND((salary - (SELECT AVG(salary) FROM 2021_misc_team_stats)) / 
    (SELECT STD(salary) FROM 2021_misc_team_stats),3) AS salary_zscore,
    salary,
    stat.win_pct
FROM salary_rank sr
JOIN 2021_team_batting stat ON sr.team = stat.Tm
WHERE sr.third = 3
AND Attendance > (SELECT AVG(attendance) FROM 2021_misc_team_stats)
ORDER BY attendance DESC
;
    
#Over .500 Teams that overpreformed pythagorean record AND whose salary was bottom third of the league

WITH pyth AS (SELECT
	bat.tm,
    bat.win_pct,
    ROUND(POWER(bat.r,2) / (POWER(bat.r,2) + POWER(pit.r,2)),3) AS Pythagorean,
    round((bat.win_pct / ROUND(POWER(bat.r,2) / (POWER(bat.r,2) + POWER(pit.r,2)),3)-1)*100,3) AS dif,
    salary,
    NTILE(3) OVER(ORDER BY salary DESC) AS salary_tier,
    ROW_NUMBER() OVER(ORDER BY salary DESC) AS salary_rank
FROM 2021_team_batting bat
JOIN 2021_team_pitching pit ON bat.tm = pit.tm
JOIN 2021_misc_team_stats misc ON bat.tm = misc.team)

SELECT
	pyth.tm,
    pyth.win_pct,
    CONCAT("$",salary) AS salary,
    ROUND((salary - (SELECT AVG(salary) FROM 2021_misc_team_stats)) / (SELECT STD(salary) FROM 2021_misc_team_stats),3) AS salary_zscore,
    pyth.pythagorean,
    pyth.dif AS actual_vs_pyth,
    ROUND((pyth.win_pct / (SELECT AVG(win_pct) FROM 2021_team_batting)-1)*100,3) AS actual_vs_league_avg
FROM pyth
WHERE salary_tier = 3
AND win_pct >= .5
ORDER BY 3 DESC;



#Tableau: Map player home countries / states and stats

#Python ideas: matplotlib attendance & win pct
#Seaborn pairplot (sic?)
