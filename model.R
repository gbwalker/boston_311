### Predicting response time for Boston 311 calls.

library(tidyverse)
library(caret)
library(extrafont)

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

### Create a medium-sized data set to test models with.

df_med <- sample_n(df, round(nrow(df) * .2))

# Create training and test partitions with 90 and 10 percent of the medium data, respectively.

partition <- createDataPartition(df_med$completion_hours, p = 0.90, list = FALSE)

training <- df_med[partition, ]
testing <- df_med[-partition, ]

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

partition <- createDataPartition(df_med$completion_hours, p = 0.90, list = FALSE)

training <- df_med[partition, ]
testing <- df_med[-partition, ]

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

# Save all the models.

saveRDS(model_knn, "models/model_knn.rds")
saveRDS(model_lm, "models/model_lm.rds")
saveRDS(model_spline, "models/model_spline.rds")
saveRDS(model_ridge, "models/model_ridge.rds")
saveRDS(model_rf, "models/model_rf.rds")

# Save the medium-sized datasets for training and testing.

saveRDS(training, "models/training.rds")
saveRDS(testing, "models/testing.rds")

#################
### Ensemble
#################

# Combine the results of all the base-level models.

results_all <- tibble(knn = results_knn,
                      lm = results_lm,
                      spline = as.double(results_spline),
                      ridge = results_ridge,
                      rf = results_rf,
                      actual = testing$completion_hours) %>% 

# Add a column with the predicted means just to check.
  
  mutate(mean = (knn + lm + spline + ridge + rf) / 5) %>% 
  select(-mean)

# Save all of the predictions for the 7,896 predictions.

saveRDS(results_all, "models/results_all.rds")

# Create a test and training set of the total results.

partition <- createDataPartition(results_all$actual, p = 0.75, list = FALSE)

ensemble_training <- results_all[partition, ]
ensemble_testing <- results_all[-partition, ]

# Train another spline on the results of the base-level models.
# After trying to fit all the models above as the meta-model, a spline had
# the lowest RMSE (around 338 for the 1% data set).

ensemble_spline <- train(actual ~ .,
                  data = ensemble_training,
                  method = "earth",
                  trControl = tr)

results_ensemble <- predict(ensemble_spline, ensemble_testing[,-6])

RMSE(results_ensemble, ensemble_testing$actual)

#################
### Graphics
#################

# Make an array of all the models' RMSEs.

errors <- tibble(model = c("KNN", "Linear Regression", "Adaptive Spline", "Ridge Regression", "Random Forest", "Ensemble"),
                 RMSE = NA)

# Save all the RMSEs.

errors$RMSE[1] <- RMSE(results_all$knn, results_all$actual)
errors$RMSE[2] <- RMSE(results_all$lm, results_all$actual)
errors$RMSE[3] <- RMSE(results_all$spline, results_all$actual)
errors$RMSE[4] <- RMSE(results_all$ridge, results_all$actual)
errors$RMSE[5] <- RMSE(results_all$rf, results_all$actual)
errors$RMSE[6] <- RMSE(results_ensemble, ensemble_testing$actual)

# Change the order of the models for graphing.

errors <- errors %>%
  mutate(model = factor(model, levels = c("Adaptive Spline", "Linear Regression", "Ridge Regression", "KNN", "Random Forest", "Ensemble")))

# Save the graphics dataframe for future use.

saveRDS(errors, "models/errors.rds")

# Make a scatter plot of all of them.

ggplot(errors, aes(x = model, y = RMSE, fill = model, col = model)) +
  geom_point(stat = "identity", aes(size = 2)) +
  labs(x = "Model", title = "The ensemble model provided the optimal RMSE (409)", col = "Model") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        text = element_text(family = "LM Roman 10"),
        panel.background = element_blank(),
        panel.grid.major = element_line(color = "gray"),
        panel.grid.minor = element_line(color = "gray")) +
  guides(fill = FALSE, size = FALSE)

# Bar chart.

ggplot(errors, aes(x = model, y = RMSE, fill = model)) +
  geom_bar(stat = "identity") +
  labs(x = "Model", title = "The ensemble model provided the optimal RMSE (409)", fill = "Model") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        text=element_text(family = "LM Roman 10"),
        panel.background = element_blank()) +
  scale_y_continuous(expand = c(0,0))

  expand_limits(y = c(400, 430))
