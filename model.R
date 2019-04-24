### Predicting response time for Boston 311 calls.

library(tidyverse)
library(caret)

set.seed(12)

#################
### Preprocessing
#################

# Read in the data preprocessed with process_data.R.

df <- read_rds("311_cleaned.rds") %>% 

# Ignore some variables that are just for reference, not for modeling.
# Also drop ward, since that wasn't preprocessed.

  select(-open_dt, -target_dt, -closed_dt, -type, -ward, -promised_hours, -score)

# Identify the most important features.
# First get a subset of 1% of the data.

df_small <- sample_n(df, round(nrow(df) * .01))

# Define the controls for the random forest.

control <- rfeControl(functions = rfFuncs, method = "cv", number = 10)

# Run the random forest.
# Note that this takes a long time (~18 minutes).

features_rf <- rfe(df_small[, 1:11],
                   df_small$completion_hours,
                   sizes = c(1:8),
                   rfeControl = control)

# With 1% of the data, five predictors were most important:
# reason, department, month_open, source, fire_district

df <- df %>% select(reason, department, month_open, source, fire_district, completion_hours)
df_small <- df_small %>% select(reason, department, month_open, source, fire_district, completion_hours)

#################
### Model
#################

# Create a medium-sized data set to test models with.

df_med <- sample_n(df, round(nrow(df) * .2))

# Create training and test partitions with 90 and 10 percent of the medium data, respectively.

partition <- createDataPartition(df_small$completion_hours, p = 0.90, list = FALSE)

training <- df_small[partition, ]
testing <- df_small[-partition, ]

# Run a KNN regression with different values of k.

# Initialize a matrix to save the RMSE results.

knn_results <- tibble(k = c(1:10), RMSE = NA)

# Test different values of K.
# Takes ~6 minutes to run.

for (n in c(3:10)) {
  model_knn <- knnreg(completion_hours ~ .,
                      data = training,
                      k = n)
  results_knn <- predict(model_knn, testing[,-6])

  # Save the results.
  
  knn_results$RMSE[n] <- RMSE(results_knn, testing$completion_hours)
}

# Plot the results.

ggplot(knn_results[3:10,], aes(k, RMSE)) +
  geom_point() +
  geom_line() +
  labs(title = "k = 9 had the lowest RMSE on a subset of the data")

# Add a noise variable so that KNN works.

noise <- rnorm(nrow(df), 0, .001)

df <- cbind(df, noise)

# Create a 90-10 partition for the full data.

partition <- createDataPartition(df$completion_hours, p = 0.90, list = FALSE)

training <- df[partition, ]
testing <- df[-partition, ]

# Run KNN regression with k = 9.

model_knn <- knnreg(completion_hours ~ .,
                    data = training,
                    k = 9)

results_knn <- predict(model_knn, newdata = testing[,-6])

# Make all the caret models print their progress.

tr <- trainControl(verboseIter = TRUE)

# Other models to try: lm() and the following in train():
# "earth" (multivariate adaptive regression spline)
# "foba" (ridge regression)
# "ranger" (random forest)

# Run a linear regression.

model_lm <- lm(completion_hours ~ .,
               data = training)

results_lm <- predict(model_lm, testing[,-6])

# Run a multivariate adaptive regression spline.

model_spline <- train(completion_hours ~ .,
                      data = training,
                      method = "earth")

results_spline <- predict(model_spline, testing[,-6])

# Run a ridge regression.

model_ridge <- train(completion_hours ~ .,
                      data = training,
                      method = "foba", 
                     trControl = tr)

results_ridge <- predict(model_ridge, testing[,-6])

# Run a random forest.

model_rf <- train(completion_hours ~ .,
                  data = training,
                  method = "ranger",
                  trControl = tr)

results_rf <- predict(model_rf, testing[,-6])

# Compare the RMSE values for each model.

model_results <- tibble(model = c("knn", "lm", "spline", "ridge", "rf"), RMSE = NA)

for (n in c(1:5)) {
  name <- paste0("results_", model_results$model[n])
  model_results$RMSE[n] <- RMSE(get(name), testing$completion_hours)
}


#################
### Validation
#################

# 5-fold CV.
# Tune the models.

#################
### Ensemble
#################

# Bagging: random subsets of training data, then the models vote.

# Stacking: train a few models on different subsets of the data.
# Then have a separate model learn from their predictions, or average
# of the base-level models' predictions.
# http://dnc1994.com/2016/05/rank-10-percent-in-first-kaggle-competition-en/


# 311 app: https://itunes.apple.com/us/app/bos-311/id330894558?mt=8
# 311 lookup: http://mayors24.boston.gov/Ef3/General.jsp?form=SSP_TrackCase&page=EntrancePage

