# Predicting response time for Boston 311 calls with machine learning tools.

Variables:
* `open_dt`: Date the issue was reported.
* `target_dt`: Date the city planned to handle the issue.
* `closed_dt`: Date the issue was closed.
* `reason`: General issue area.
* `type`: Specific issue. *N.B., this variable might need to be excluded from the analysis because it has too many levels.*
* `department`: Whose responsibility the issue is.
* `fire_district`: Fire district the issue was reported in.
* `pwd_district`: Public Works district.
* `city_council_district`: City Council district.
* `police_district`: Police district.
* `neighborhood`: Neighborhood.
* `ward`: Ward.
* `location_zipcode`: ZIP code.
* `source`: Who reported the issue.
* `latitude`: Latitude.
* `longitude`: Longitude.
* `month_open`: Month the issue was reported.
* `completion_time`: Time it took to handle the issue.
* `completion_hours`: Hours it took to handle the issue.
* `promised_time`: Time the city planned to take to handle the issue.
* `promised_hours`: Hours the city planned to take to handle the issue.
* `score`: Percentile score for the difference between how long the city thought it would take and how long it actually took (`promised` - `completion`). Higher is better, since it means it took shorter than expected.
