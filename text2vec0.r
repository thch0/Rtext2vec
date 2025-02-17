library(text2vec)
library(data.table)
data("movie_review")

setDT(movie_review)
setkey(movie_review, id)
set.seed(2016L)
all_ids = movie_review$id
train_ids = sample(all_ids, 4000)
test_ids = setdiff(all_ids, train_ids)
train = movie_review[J(train_ids)]
test = movie_review[J(test_ids)]

# define preprocessing function and tokenization function
prep_fun = tolower
tok_fun = word_tokenizer

it_train = itoken(train$review,
             preprocessor = prep_fun,
             tokenizer = tok_fun,
             ids = train$id,
             progressbar = FALSE)
vocab = create_vocabulary(it_train)

train_tokens = tok_fun(prep_fun(train$review))
it_train = itoken(train_tokens,
                  ids = train$id,
                  # turn off progressbar because it won't look nice in rmd
                  progressbar = FALSE)

vocab = create_vocabulary(it_train)
vocab

vectorizer = vocab_vectorizer(vocab)
t1 = Sys.time()
dtm_train = create_dtm(it_train, vectorizer)
print(difftime(Sys.time(), t1, units = 'sec'))

dim(dtm_train)

identical(rownames(dtm_train), train$id)
install.packages("glmnet")
library(glmnet)
NFOLDS = 4
t1 = Sys.time()
glmnet_classifier = cv.glmnet(x = dtm_train, y = train[['sentiment']],
                              family = 'binomial',
                              # L1 penalty
                              alpha = 1,
                              # interested in the area under ROC curve
                              type.measure = "auc",
                              # 5-fold cross-validation
                              nfolds = NFOLDS,
                              # high value is less accurate, but has faster training
                              thresh = 1e-3,
                              # again lower number of iterations for faster training
                              maxit = 1e3)
print(difftime(Sys.time(), t1, units = 'sec'))

plot(glmnet_classifier)

print(paste("max AUC =", round(max(glmnet_classifier$cvm), 4)))

# Note that most text2vec functions are pipe friendly!
it_test = tok_fun(prep_fun(test$review))
it_test = itoken(it_test, ids = test$id,
                 # turn off progressbar because it won't look nice in rmd
                 progressbar = FALSE)

dtm_test = create_dtm(it_test, vectorizer)

preds = predict(glmnet_classifier, dtm_test, type = 'response')[,1]
glmnet:::auc(test$sentiment, preds)

stop_words = c("i", "me", "my", "myself", "we", "our", "ours", "ourselves", "you", "your", "yours")
t1 = Sys.time()
vocab = create_vocabulary(it_train, stopwords = stop_words)
print(difftime(Sys.time(), t1, units = 'sec'))

pruned_vocab = prune_vocabulary(vocab,
                                 term_count_min = 10,
                                 doc_proportion_max = 0.5,
                                 doc_proportion_min = 0.001)
vectorizer = vocab_vectorizer(pruned_vocab)
# create dtm_train with new pruned vocabulary vectorizer
t1 = Sys.time()
dtm_train  = create_dtm(it_train, vectorizer)
print(difftime(Sys.time(), t1, units = 'sec'))

dim(dtm_train)

dtm_test   = create_dtm(it_test, vectorizer)
dim(dtm_test)

t1 = Sys.time()
vocab = create_vocabulary(it_train, ngram = c(1L, 2L))
print(difftime(Sys.time(), t1, units = 'sec'))

vocab = prune_vocabulary(vocab, term_count_min = 10,
                         doc_proportion_max = 0.5)

bigram_vectorizer = vocab_vectorizer(vocab)

dtm_train = create_dtm(it_train, bigram_vectorizer)

t1 = Sys.time()
glmnet_classifier = cv.glmnet(x = dtm_train, y = train[['sentiment']],
                 family = 'binomial',
                 alpha = 1,
                 type.measure = "auc",
                 nfolds = NFOLDS,
                 thresh = 1e-3,
                 maxit = 1e3)
print(difftime(Sys.time(), t1, units = 'sec'))

plot(glmnet_classifier)

print(paste("max AUC =", round(max(glmnet_classifier$cvm), 4)))

# apply vectorizer
dtm_test = create_dtm(it_test, bigram_vectorizer)
preds = predict(glmnet_classifier, dtm_test, type = 'response')[,1]
glmnet:::auc(test$sentiment, preds)

h_vectorizer = hash_vectorizer(hash_size = 2 ^ 14, ngram = c(1L, 2L))

t1 = Sys.time()
dtm_train = create_dtm(it_train, h_vectorizer)
print(difftime(Sys.time(), t1, units = 'sec'))

t1 = Sys.time()
glmnet_classifier = cv.glmnet(x = dtm_train, y = train[['sentiment']],
                             family = 'binomial',
                             alpha = 1,
                             type.measure = "auc",
                             nfolds = 5,
                             thresh = 1e-3,
                             maxit = 1e3)
print(difftime(Sys.time(), t1, units = 'sec'))

plot(glmnet_classifier)

print(paste("max AUC =", round(max(glmnet_classifier$cvm), 4)))

dtm_test = create_dtm(it_test, h_vectorizer)

preds = predict(glmnet_classifier, dtm_test , type = 'response')[, 1]
glmnet:::auc(test$sentiment, preds)

dtm_train_l1_norm = normalize(dtm_train, "l1")

vocab = create_vocabulary(it_train)
vectorizer = vocab_vectorizer(vocab)
dtm_train = create_dtm(it_train, vectorizer)

# define tfidf model
tfidf = TfIdf$new()
# fit model to train data and transform train data with fitted model
dtm_train_tfidf = fit_transform(dtm_train, tfidf)
# tfidf modified by fit_transform() call!
# apply pre-trained tf-idf transformation to test data
dtm_test_tfidf = create_dtm(it_test, vectorizer)
dtm_test_tfidf = transform(dtm_test_tfidf, tfidf)

t1 = Sys.time()
glmnet_classifier = cv.glmnet(x = dtm_train_tfidf, y = train[['sentiment']],
                              family = 'binomial',
                              alpha = 1,
                              type.measure = "auc",
                              nfolds = NFOLDS,
                              thresh = 1e-3,
                              maxit = 1e3)
print(difftime(Sys.time(), t1, units = 'sec'))

## Time difference of 2.834669 secs

plot(glmnet_classifier)

print(paste("max AUC =", round(max(glmnet_classifier$cvm), 4)))

preds = predict(glmnet_classifier, dtm_test_tfidf, type = 'response')[,1]
glmnet:::auc(test$sentiment, preds)

