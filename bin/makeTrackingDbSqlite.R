#!/usr/bin/env Rscript

library( getopt, quietly = TRUE )
library( sqldf, quietly = TRUE )

#' Converts a tab-delimited file with headers and quoted fields to an sqlite 
#' file.
#' 
#' @title Convert tab-delimited file with header row to sqlite
#' @author Shiv Venkatasubrahmanyam \email{shvenkat@@amgen.com}
#' @name makeTrackingDbSqlite
#' @usage makeTrackingDbSqlite -i foo.txt -o foo.sqlite
#' @param -i foo.txt  input file
#' @param -o foo.sqlite  output file
NA

#### parse command-line options ###############################################
opts.spec <- matrix( c( 
    "input",  "i", 1, "character", "input file, tab-delimited with header row and double quote-enclosed fields", 
    "output", "o", 1, "character", "output file, sqlite, can be used with gautools dbquery utility", 
    "help",   "h", 0, "logical",   "help" ), 
    ncol = 5, byrow = TRUE )
usage <- function() { 
    self.name <- basename( strsplit( commandArgs(FALSE)[4], "=" )[[1]][2] )
    write( getopt( opts.spec, command = self.name, usage = TRUE ), stderr() )
    quit( save = "no", status = 1, runLast = FALSE )
}
opts <- tryCatch( getopt( opts.spec, commandArgs(TRUE) ),
            error = function(e) usage() )
if( !is.null( opts$help ) ) usage()
if( is.null( opts$input ) || is.null( opts$output ) ) usage()
file.in <- opts$input
file.out <- opts$output

#' Generic condition handler to display messages, delete files and exit
conditionHandler <- function(c, rmFiles = NULL) {
    if( !is.null( rmFiles ) ) {
        system( sprintf( "rm -f %s", paste( as.character( rmFiles ), sep = "") ) )
    }
    if( inherits( c, "error" ) ) {
        cat( sprintf( "ERROR: %s\n", conditionMessage(c) ) )
        quit( save = "no", status = 1, runLast = FALSE )
    } else if( inherits( c, "warning" ) ) {
        cat( sprintf( "WARNING: %s\n", conditionMessage(c) ) )
        quit( save = "no", status = 1, runLast = FALSE )
    } else {
        cat( sprintf( "ALERT: %s\n", conditionMessage(c) ) )
        quit( save = "no", status = 1, runLast = FALSE)
    }
}
        
x <- tryCatch( 
    read.table( file.in, header = TRUE, sep = "\t", check.names = FALSE, 
    comment.char = "", stringsAsFactors = FALSE, quote = "\"" ), 
    error = function(e) conditionHandler(e), 
    warning = function(w) conditionHandler(w) )
tryCatch( cat( file = file.out ), 
    error = function(e) conditionHandler(e, file.out), 
    warning = function(w) conditionHandler(w, file.out ) )
y <- tryCatch( 
    sqldf( "create table main.SequenceRun as select * from x", 
        dbname = file.out ), 
    error = function(e) conditionHandler(e, file.out), 
    warning = function(w) conditionHandler(w, file.out ) )

quit( save = "no", status = 0, runLast = FALSE )
