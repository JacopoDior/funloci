#include <Rcpp.h>
using namespace Rcpp;
//' Hscore Matrix computation
//'
//' @param mat a numerical matrix
//' @export
// [[Rcpp::export]]
NumericMatrix HscoreC(NumericMatrix mat){
  unsigned int outrows = mat.nrow();
  double d;
  int p = mat.ncol();
  Rcpp::NumericMatrix res(outrows,outrows);

  for (int i = 0; i < res.nrow(); i++) {
    Rcpp::NumericVector x = mat.row(i);
    for (int j = 0; j < i; j++) {
      d = sum(pow(x - mean(x) - (x+mat.row(j))/2 + sum(x+mat.row(j))/(2*p), 2.0))/p;
      res(j,i)=d;
      res(i,j)=d;
    }
  }

  return res;
}
