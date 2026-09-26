library(readxl)
library(ggplot2)
library(tidyr)
library(gridExtra)
library(urca)
library(vars)
library(stargazer)
library(forecast)
library(tseries) #Ljung Box test
library(skedastic) # White test
library(FinTS) #Arch test
library(rugarch)
########################### Database ###########################

Mydata <- read_excel("B:/MemoireCetic/MEMOIRE/Rcode/Code_Source_R/Mydata.xlsx")

######################## Individual curve ##############################

tracer <- function(variable, titre) {
  ggplot(Mydata, aes(Date, .data[[variable]])) +
    geom_line(color = "royalblue") +
    theme_test(12) +
    labs(x = NULL, y = titre)}

ElecPrice<-tracer("ElecPrice","Ln(prix de l'électricité)") 
Demand<-tracer("Demand","Demande de l'électricité")
Wind<-tracer("Wind","Energie éolienne")

grid.arrange(ElecPrice, Demand, Wind, ncol = 2)


######### time series transformation #########
debut     <- c(2018, 1)
frequence <- 365
variables <- c("ElecPrice", "Demand", "Wind")
Mydata_ts <- ts(Mydata[, variables], start = debut, frequency = frequence)
Elecprice_ts <- Mydata_ts[, "ElecPrice"]

############ Train and Validation dataset ############################"

n_total <- length(Elecprice_ts)
n_train <- 699   
n_test  <- n_total - n_train

temps <- time(Elecprice_ts)
ElecPriceTrain <- window(Elecprice_ts, end   = temps[n_train])
ElecPriceTest  <- window(Elecprice_ts, start = temps[n_train + 1])

cat("Apprentissage :", n_train, "obs. du", format(Mydata$Date[1]),
    "au", format(Mydata$Date[n_train]), "\n")
cat("Test          :", n_test, "obs. du", format(Mydata$Date[n_train + 1]),
    "au", format(Mydata$Date[n_total]), "\n")
cat("Proportion apprentissage :", round(100 * n_train / n_total, 1), "%\n")

########### ACF and PACF of Electriciy price #################"

par(mfrow = c(1, 2))

acf(as.numeric(ElecPriceTrain),  lag.max = 40, lwd = 2, las = 1, col = "blue")
pacf(as.numeric(ElecPriceTrain), lag.max = 40, lwd = 2, las = 1, col = "darkred")

par(mfrow = c(1, 1))

################# estimation of the AR model parameters ###########
estimer_ar <- function(p) {
  arima(ElecPriceTrain, order = c(p, 0, 0), method = "ML")}

### Information criterion of hannan-Quinn
HQC <- function(modele) {
  vrais <- logLik(modele)
  k <- attr(vrais, "df") # number of estimated paramaters
  n <- nobs(modele)      # number of observation
  -2 * as.numeric(vrais) + 2 * k * log(log(n))}

ar4 <- estimer_ar(4); ar3 <- estimer_ar(3); ar1 <- estimer_ar(1)

### Model Comparaison
comparaison <- data.frame(
  Modele = c("AR(4)", "AR(3)", "AR(1)"),
  AIC    = round(c(AIC(ar4), AIC(ar3), AIC(ar1)), 2),
  BIC    = round(c(BIC(ar4), BIC(ar3), BIC(ar1)), 2),
  HQC    = round(c(HQC(ar4), HQC(ar3), HQC(ar1)), 2)
)

print(comparaison, row.names = FALSE)

cat("Meilleur modèle selon l'AIC :", comparaison$Modele[which.min(comparaison$AIC)], "\n")
cat("Meilleur modèle selon le BIC :", comparaison$Modele[which.min(comparaison$BIC)], "\n")
cat("Meilleur modèle selon le HQC :", comparaison$Modele[which.min(comparaison$HQC)], "\n")


######################### ARX model ############################

ExogVar=Mydata_ts[1:699,3:2]
ARX<-arima(ElecPriceTrain, order = c(3,0,0),
           method = "ML",xreg=ExogVar)
result<-coeftest(ARX)

checkresiduals(ARX)

################# residual test ###############################

##### Ljung–Box Test for Autocorrelation

Box.test(residuals(ARX), lag = 7, type = "Ljung-Box", fitdf = 3)

#### white test for homoscedasticity

y <- as.numeric(ElecPriceTrain)
donnees <- data.frame(
  prix    = y,
  retard1 = dplyr::lag(y, 1),
  retard2 = dplyr::lag(y, 2),
  retard3 = dplyr::lag(y, 3),
  ExogVar
)
ARX_mco <- lm(prix ~ ., data = donnees)

white(ARX_mco, interactions = TRUE)

##### Arch test and acf and order of nonlinear variance model
ArchTest(residuals(ARX)^2, lags=11, demean=TRUE)

acf(as.numeric(residuals(ARX)^2),lag.max = 40, lwd = 2, las = 1, col = "darkred")

### GARCH optimal order

AIC<-data.frame()
for (i in 1:14){
  for (j in 1:11){
    Aicgarch<-AIC(garch(residuals(ARX)^2, c(i,j)))
    AIC[i,j]<-Aicgarch}}

l<-min(AIC)
for(i in 1:14){
  for(j in 1:11){
    if(AIC[i,j]==l)ordre=c(i,j)}}
ordre

##### Nonlinear variance model 

regres  <- as.matrix(ExogVar)

estimer_arx_garch <- function(modele, ordre, fixes = list()) {
  spec <- ugarchspec(
    variance.model     = list(model = modele, garchOrder = ordre),
    mean.model         = list(armaOrder = c(3, 0), external.regressors = regres),
    distribution.model = "std",
    fixed.pars         = fixes)
  ugarchfit(spec = spec, data = ElecPriceTrain, solver = "hybrid")
}

ArxGarch.fit    <- estimer_arx_garch("sGARCH",   c(1, 2))
ArxeGarch.fit   <- estimer_arx_garch("eGARCH",   c(1, 1))
ArxgjrGarch.fit <- estimer_arx_garch("gjrGARCH", c(1, 1))
Arxaparch.fit <- estimer_arx_garch("apARCH", c(1, 1), fixes = list(delta = 0.943))

ArxGarch.fit
ArxeGarch.fit
ArxgjrGarch.fit
Arxaparch.fit

###################### jarque bera, student and ARCH-LM ############

library(rugarch)
library(tseries)   # Jarque-Bera
library(FinTS)     # ARCH-LM

modeles <- list(
  "GARCH(2,1)"     = ArxGarch.fit,
  "EGARCH(1,1)"    = ArxeGarch.fit,
  "Gjr-GARCH(1,1)" = ArxgjrGarch.fit,
  "APARCH(1,1)"    = Arxaparch.fit
)

# Degrés de liberté de Student, Jarque-Bera et ARCH-LM pour un modèle
diagnostics <- function(fit, lags_arch = 11) {
  z    <- as.numeric(residuals(fit, standardize = TRUE))   
  jb   <- jarque.bera.test(z)
  arch <- ArchTest(z, lags = lags_arch)
  df   <- fit@fit$matcoef["shape", ]                       library(rugarch)
  library(tseries)   # Jarque-Bera
  library(FinTS)     # ARCH-LM
  
  modeles <- list(
    "GARCH(2,1)"     = ArxGarch.fit,
    "EGARCH(1,1)"    = ArxeGarch.fit,
    "Gjr-GARCH(1,1)" = ArxgjrGarch.fit,
    "APARCH(1,1)"    = Arxaparch.fit
  )
  
  # Degrés de liberté de Student, Jarque-Bera et ARCH-LM pour un modèle
  diagnostics <- function(fit, lags_arch = 11) {
    z    <- as.numeric(residuals(fit, standardize = TRUE))# résidus standardisés
    jb   <- jarque.bera.test(z)
    arch <- ArchTest(z, lags = lags_arch)
    df   <- fit@fit$matcoef["shape", ]# paramètre de la loi de Student
    
    c(round(df[1], 4),            df[4],
      round(jb$statistic, 3),     jb$p.value,
      round(arch$statistic, 4),   arch$p.value)
  }
  
  resultats <- t(sapply(modeles, diagnostics))
  colnames(resultats) <- c("Student_df", "p_value_df",
                           "Jarque_Bera", "p_value_JB",
                           "ARCH_LM", "p_value_ARCH")
  resultats
  
  c(round(df[1], 4),            df[4],
    round(jb$statistic, 3),     jb$p.value,
    round(arch$statistic, 4),   arch$p.value)
}

resultats <- t(sapply(modeles, diagnostics))
colnames(resultats) <- c("Student_df", "p_value_df",
                         "Jarque_Bera", "p_value_JB",
                         "ARCH_LM", "p_value_ARCH")
resultats


######################## Residual Analysis ######################

# Modèles et couleurs, dans l'ordre de la figure

couleurs <- c("black", "brown", "green3", "blue")

par(mfrow = c(2, 2))

for (i in 1:4) {
  residus <- as.numeric(residuals(modeles[[i]]))
  acf(residus, lag.max = 100, col = couleurs[i], lwd = 2,
      main = "", xlab = "", ylab = "")
}

par(mfrow = c(1, 1))   # 

###### Ljung biox test on Squared Residuals ####################

ljung_box <- function(fit, retards = 20, p_ar = 3) {
  z <- as.numeric(residuals(fit, standardize = TRUE))
  lb_z <- Box.test(z^2, lag = retards, type = "Ljung-Box")
  c(round(lb_z$statistic, 4), lb_z$p.value)
}
resultats_lb <- t(sapply(modeles, ljung_box))
colnames(resultats_lb) <- c("Statistique", "p_value")
resultats_lb

###################### Model Performance #############################

reel         <- as.numeric(ElecPriceTest)
regres_valid <- as.matrix(Mydata_ts[700:nrow(Mydata_ts), 3:2])

criteres <- function(fit) {
  prev <- as.numeric(fitted(ugarchforecast(fit, n.ahead = length(reel),
                  external.forecasts = list(mregfor = regres_valid))))
  erreur <- reel - prev
  
  c(RMSE = sqrt(mean(erreur^2)),
    MAE  = mean(abs(erreur)),
    MAPE = 100 * mean(abs(erreur / reel)),
    TIC  = sqrt(mean(erreur^2)) / (sqrt(mean(reel^2)) + sqrt(mean(prev^2))))
}

precision<-round(t(sapply(modeles, criteres)), 6)

apply(precision, 2, function(x) rownames(precision)[which.min(x)])
