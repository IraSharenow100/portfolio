# El Cerrito + fire department study for GitHub
# Start September 8, 2026


library(tidyverse)
library(readxl)

setwd("D:/Documents/Employment/2026 job search/GitHub/portfolio/Fire Department 2026 Git/Fire Data")

fire <- read_excel("Fire Incident Data.xlsx", sheet = "DATA")
dim(fire)
names(fire)
