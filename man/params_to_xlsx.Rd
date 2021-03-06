% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils_params_to_xlsx.R
\name{params_to_xlsx}
\alias{params_to_xlsx}
\title{Params To xlsx}
\usage{
params_to_xlsx(params, file)
}
\arguments{
\item{params}{the current `params` object used to model the data}

\item{file}{the filename where to save the xlsx file}
}
\value{
invisibly returns where the file was saved
}
\description{
Take the `params` and creates an Excel file which can be downloaded and reuploaded at a later date
}
